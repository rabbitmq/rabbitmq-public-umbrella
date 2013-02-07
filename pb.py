#!/usr/bin/env python

from __future__ import with_statement

import sys
import os
import errno
import subprocess
import re
import time
import glob
import hashlib
import email.utils
import optparse

class CycleError(Exception): pass
class IllegalConfigurationName(Exception): pass
class InvalidCommandLine(Exception): pass

###########################################################################
# Progress messages, with noddy filtering

all_log_levels = ["LOG_PREREQ_CHECK",
                  "LOG_CHDIR",
                  "LOG_CLEAN_CHECK",
                  "LOG_DIRTY_TEST_PATHS",
                  "LOG_CLONE",
                  "LOG_MKDIR",
                  "LOG_RMDIR",
                  "LOG_SHELL",
                  "LOG_SHELL_STDOUT",
                  "LOG_SHELL_STDERR",
                  "LOG_UPDATE",
                  "LOG_INSTALL",
                  "LOG_BUILD"]
for loglevel in all_log_levels:
    globals()[loglevel] = loglevel

COLOR_RED = '\033[91m'
COLOR_GREEN = '\033[92m'
COLOR_NORMAL = '\033[0m'

active_log_levels = set([LOG_PREREQ_CHECK,
                         LOG_CLEAN_CHECK,
                         LOG_CLONE,
                         LOG_UPDATE,
                         LOG_INSTALL,
                         LOG_BUILD,
                         LOG_SHELL_STDOUT,
                         LOG_SHELL_STDERR])

log_fd = None

def fdlog(fd, args):
    for a in args:
        fd.write(str(a))
        fd.write(' ')
    fd.write("\n")
    fd.flush()

def log(level, *args):
    if log_fd:
        fdlog(log_fd, args)
    if level in active_log_levels:
        fdlog(sys.stdout, args)

def log_color(level, color, *args):
    sys.stdout.write(color)
    log(level, *args)
    sys.stdout.write(COLOR_NORMAL)
    sys.stdout.flush()

###########################################################################
# Topological sort utility, based on http://www.radlogic.com/releases/topsort.py. LGPL.

def topsort(pairlist):
    num_parents = {}
    children = {}
    for parent, child in pairlist:
        if not num_parents.has_key(parent): num_parents[parent] = 0
        if not num_parents.has_key(child): num_parents[child] = 0
        num_parents[child] = num_parents[child] + 1
        children.setdefault(parent, []).append(child)

    answer = [x for x in num_parents.keys() if num_parents[x] == 0]
    for parent in answer:
        del num_parents[parent]
        if children.has_key(parent):
            for child in children[parent]:
                num_parents[child] = num_parents[child] - 1
                if num_parents[child] == 0: answer.append(child)
            del children[parent]

    if num_parents: 
        raise CycleError(answer, num_parents, children)
    return answer

###########################################################################
# Shelling out to the system flexibly.
#
# Generally, use qx if you want the output, and ssc or sc if you don't.
# Use ssc2 and sc2 if for some reason you want to capture stderr.
#
# qx: like backticks; returns stdout; uses the shell for command parsing
# ssc: like os.system; uses the shell for command parsing
# sc: like os.system; uses execvp directly
# ssc2: like backticks; returns (stdout, stderr); uses the shell
# sc2: like backticks; returns (stdout, stderr); uses execvp

def sc2internal(cmd, shell,
                input = None,
                stdout = subprocess.PIPE,
                stderr = subprocess.PIPE,
                ignoreResult = False,
                stripResult = True):
    log(LOG_SHELL, "Invoking", cmd)
    p = subprocess.Popen(cmd,
                         stdin = subprocess.PIPE,
                         stdout = stdout,
                         stderr = stderr,
                         shell = shell,
                         close_fds = True)
    (output, errors) = p.communicate(input)
    if not output: output = ''
    if not errors: errors = ''
    if p.returncode and not ignoreResult:
        log_color(LOG_SHELL_STDOUT, COLOR_GREEN, output.rstrip())
        log_color(LOG_SHELL_STDERR, COLOR_RED, errors.rstrip())
        raise subprocess.CalledProcessError(p.returncode, cmd)
    if stripResult:
        return (output.strip(), errors.strip())
    else:
        return (output, errors)

def sc2(cmd, **kwargs): return sc2internal(cmd, False, **kwargs)
def ssc2(cmd, **kwargs): return sc2internal(cmd, True, **kwargs)

def scinternal(cmd, shell, **kwargs):
    (output, errors) = sc2internal(cmd, shell, **kwargs)
    return output

def sc(cmd, **kwargs): scinternal(cmd, False, **kwargs)
def ssc(cmd, **kwargs): scinternal(cmd, True, **kwargs)
def qx(cmd, **kwargs): return scinternal(cmd, True, **kwargs)

class cwd_set_to:
    def __init__(self, new_wd):
        self.old_wd = None
        self.new_wd = new_wd
    def __enter__(self):
        self.old_wd = os.getcwd()
        log(LOG_CHDIR, "Entering", self.new_wd, "from", self.old_wd)
        os.chdir(self.new_wd)
        return os.getcwd()
    def __exit__(self, type, value, traceback):
        log(LOG_CHDIR, "Leaving", self.new_wd, "for", self.old_wd)
        os.chdir(self.old_wd)

class http_resources_needed_for_installation:
    def __init__(self):
        self.dirpath = None
    def __enter__(self):
        import tempfile
        self.dirpath = tempfile.mkdtemp()
        self.install_resources()
        return "file://" + self.dirpath + '/'
    def __exit__(self, type, value, traceback):
        rm_rf(self.dirpath)
    def install_resources(self):
        for filename in ['install.html', 'build-server.html', 'build-java-client.html']:
            with file(os.path.join(self.dirpath, filename), 'w') as f:
                f.write("This is an unofficial build - please see the URL above.")

def mkdir_p(path):
    try:
        log(LOG_MKDIR, "Creating", path)
        os.makedirs(path)
    except OSError, e:
        if e.errno != errno.EEXIST: raise

def rm_rf(path):
    try:
        import shutil
        log(LOG_RMDIR, "Recursively deleting", path)
        shutil.rmtree(path)
    except OSError, e:
        if e.errno != errno.ENOENT: raise

def cp_p(*args):
    sc(["cp", "-p"] + list(args))

def ensure_clean_dir(directory):
    rm_rf(directory)
    mkdir_p(directory)

###########################################################################
# (D)VCS support.

class Repo(object):
    def __init__(self, source, branch = None, tag = None):
        self.source = source
        self._branch = branch
        self._tag = tag
        self._revid = None
        self._timestamp = None

    def branch(self):
        return self._branch

    def tag(self):
        return self._tag

    def revid(self):
        if self._revid is None: self._read_version()
        return self._revid

    def timestamp(self):
        if self._timestamp is None: self._read_version()
        return self._timestamp

    def copy_with_source(self, source):
        return (self.__class__)(source,
                                branch = self._branch,
                                tag = self._tag)

    def vcsname(self): raise NotImplementedError("subclass responsibility")
    def update(self): raise NotImplementedError("subclass responsibility")
    def clone(self, target): raise NotImplementedError("subclass responsibility")
    def _read_version(self): raise NotImplementedError("subclass responsibility")

class HgRepo(Repo):
    def vcsname(self):
        return 'hg'

    def update(self):
        log(LOG_UPDATE, "Updating", self.source)
        with cwd_set_to(self.source):
            ssc("hg pull")
            ssc("hg up %s" % (self.tag() or self.branch() or 'default',))

    def clone(self, target):
        log(LOG_CLONE, "Cloning", self.source, "to", target)
        sc(["hg", "clone", self.source, target])
        with cwd_set_to(target):
            ssc("hg up %s" % (self.tag() or self.branch() or 'default',))
        return self.copy_with_source(target)

    def _read_version(self):
        with cwd_set_to(self.source):
            self._revid = qx("hg id -i")
            (utctime, offsetsec) = \
                      qx("hg log -r %s --template '{date|hgdate}'" % (self._revid,)).split()
            self._timestamp = int(float(utctime))

class GitRepo(Repo):
    def vcsname(self):
        return 'git'

    def update(self):
        log(LOG_UPDATE, "Updating", self.source)
        with cwd_set_to(self.source):
            ssc("git pull")

    def clone(self, target):
        log(LOG_CLONE, "Cloning", self.source, "to", target)
        sc(["git", "clone", self.source, target])
        with cwd_set_to(target):
            if self.tag():
                sc(["git", "checkout", self.tag()])
            elif self.branch():
                sc(["git", "checkout", "-t", "origin/" + self.branch()])
        return self.copy_with_source(target)

    def _read_version(self):
        with cwd_set_to(self.source):
            (stamp, commithash) = qx("git log -1 --pretty='format:%at %H' HEAD").split()
            self._revid = commithash
            self._timestamp = int(float(stamp))

###########################################################################
# The meat of the system: projects.

class Project(object):
    def __init__(self, store, directory, source_repo, build_deps, ezs = []):
        self.store = store
        self.directory = os.path.abspath(directory)
        self.shortname = os.path.basename(self.directory)
        self.source_repo = source_repo
        self._repo = None
        self._timestamp = None
        self._manifest_hash = None
        self.build_deps = build_deps
        self.ezs = ezs

        self.store.register_project(self)

    def update(self):
        self.repo().update()

    def repo(self):
        if not self._repo:
            if os.path.exists(self.directory):
                self._repo = self.source_repo.copy_with_source(self.directory)
            else:
                self._repo = self.source_repo.clone(self.directory)
        return self._repo

    def wipe(self, really = False):
        assert really
        rm_rf(self.directory)

    def clean(self):
        with cwd_set_to(self.directory):
            if os.path.exists("Makefile"): ssc("make distclean")

    def compute_deps(self):
        # No action by default: deps given in ctor
        pass

    def write_manifest(self, f):
        def iw(k, s):
            f.write(k)
            f.write(': ')
            f.write(s)
            f.write('\n')
        def wp(p):
            iw("Project", p.shortname)
            iw("Description", p.description())
            iw("Repository", p.source_repo.source)
            if p.source_repo.tag():
                iw("Tag", p.source_repo.tag())
            if p.source_repo.branch():
                iw("Branch", p.source_repo.branch())
            iw("Changed",
               str(p.repo().timestamp()) + " (" + \
               time.strftime("%Y%m%d%H%M%S", time.gmtime(p.repo().timestamp())) + ")")
            iw("Revision", p.repo().revid())
        deps = [self]
        for p in deps:
            for d in p.build_deps:
                if d not in deps: deps.append(d)
        wp(deps.pop(0))
        for p in deps:
            f.write("\n")
            wp(p)

    def description(self):
        # Default to project name.
        return self.shortname

    def timestamp(self):
        if not self._timestamp:
            deptimes = [p.timestamp() for p in self.build_deps] or [0]
            self._timestamp = max(self.repo().timestamp(), max(deptimes))
        return self._timestamp

    def manifest_hash(self):
        if not self._manifest_hash:
            with file(self.store.manifest_path_for(self), "r") as f:
                self._manifest_hash = hashlib.sha1(f.read()).hexdigest()
        return self._manifest_hash

    def version_str(self):
        """Return the version string to use in constructing build
        artifacts etc for this project. We have to be careful here
        about the string we choose: it has to start with a digit,
        because some of the Makefiles (e.g. that for RPMs) depends on
        that to distinguish the source-code tarball from other files
        in the same directory, and it may not contain an underscore,
        because debian package versions may not have underscores in
        them. There may be other arcane restrictions we haven't run
        across yet."""
        c = self.store.configuration_name()
        if '_' in c:
            raise IllegalConfigurationName(c)
        return time.strftime("%Y%m%d.%H%M%S.", time.gmtime(self.timestamp())) + \
               c + "." + self.manifest_hash()[:8]

    def dirty(self):
        log(LOG_CLEAN_CHECK, "Checking if", self.shortname, "is dirty")
        paths = self.dirty_test_paths()
        log(LOG_DIRTY_TEST_PATHS, "Dirty test paths for", self.shortname, "are", paths)
        is_dirty = not all(os.path.exists(path) for path in paths)
        return is_dirty

    def dirty_test_paths(self):
        return [self.store.ez_path_for(ezname, self.version_str()) \
                for (ezname, ezdesc, ezrundeps) in self.ezs]

    def install_ezs(self):
        for (ezname, ezdesc, ezrundeps) in self.ezs:
            if ezrundeps is None:
                ezrundeps = []
                registerForPackaging = False
            else:
                registerForPackaging = True
            self.store.install_ez(self,
                                  "dist/%s.ez" % (ezname,),
                                  ezdesc,
                                  self.version_str(),
                                  ezrundeps,
                                  registerForPackaging = registerForPackaging)

class DebianMixin(object):
    def __init__(self, package_name, extra_packages = []):
        self.package_name = package_name
        self.extra_packages = extra_packages

    def gen_change_log_entry(self):
        with file("debian/changelog", "w") as f:
            f.write("%s (%s-1) unstable; urgency=low\n\n" % (self.package_name, self.version_str()))
            f.write("  * Unofficial release\n\n")
            f.write(" -- Autobuild <autobuild@example.com>  %s\n\n" % \
                    (email.utils.formatdate(self.timestamp()),))

    def all_package_names(self):
        return [self.package_name] + self.extra_packages

    def dirty_test_paths(self):
        if not self.store.want_debian():
            return []
        v = self.version_str()
        return [self.store.binary_path_for("%s_%s-1.tar.gz" % (self.package_name, v))]

    def srcdir_for(self, build_dir):
        return os.path.join(build_dir, self.package_name + "-" + self.version_str())

    def buildpackage_in(self, srcdir, binaryOnly = False):
        if not self.store.want_debian():
            return
        with cwd_set_to(srcdir):
            self.gen_change_log_entry()
            if binaryOnly:
                ssc("dpkg-buildpackage -b -rfakeroot -us -uc")
            else:
                ssc("dpkg-buildpackage -rfakeroot -us -uc")

    def install_debian_artifacts(self, build_dir):
        if not self.store.want_debian():
            return
        with cwd_set_to(build_dir):
            for n in self.all_package_names():
                b = "%s_%s-1" % (n, self.version_str())
                for f in glob.glob(b+"_*.deb"): self.store.install_binary(f)
                for f in glob.glob(b+"_*.changes"): self.store.install_binary(f)
                for f in glob.glob(b+".dsc"): self.store.install_binary(f)
                for f in glob.glob(b+".tar.gz"): self.store.install_binary(f)

class GenericSimpleDebianProject(Project, DebianMixin):
    def __init__(self, store, directory, source_repo, build_deps, package_name = None,
                 ezs = [],
                 extra_packages = []):
        Project.__init__(self, store, directory, source_repo, build_deps, ezs = ezs)
        DebianMixin.__init__(self, package_name or self.shortname, extra_packages = extra_packages)

    def dirty_test_paths(self):
        return Project.dirty_test_paths(self) + \
            DebianMixin.dirty_test_paths(self)

    def build(self, build_dir):
        srcdir = self.srcdir_for(build_dir)
        self.repo().clone(srcdir)
        self.buildpackage_in(srcdir)
        self.install_debian_artifacts(build_dir)
        with cwd_set_to(srcdir):
            ssc("make")
            self.install_ezs()

class RabbitMQXmppProject(GenericSimpleDebianProject):
    def mod_rabbitmq_zip(self):
        return "mod_rabbitmq-%s.zip" % (self.version_str(),)

    def dirty(self):
        # Gross
        ejabberd_include = "/usr/lib/ejabberd/include"
        if not os.path.exists(ejabberd_include):
            log(LOG_CLEAN_CHECK,
                "Ignoring %s because ejabberd include dir %s not found" % \
                (self.shortname,
                 ejabberd_include))
            return False
        return GenericSimpleDebianProject.dirty(self)

    def dirty_test_paths(self):
        result = GenericSimpleDebianProject.dirty_test_paths(self)
        result.append(self.store.binary_path_for(self.mod_rabbitmq_zip()))
        return result

    def build(self, build_dir):
        GenericSimpleDebianProject.build(self, build_dir)
        with cwd_set_to(self.srcdir_for(build_dir)):
            ssc("zip %s mod_rabbitmq.beam" % (self.mod_rabbitmq_zip(),))
            self.store.install_binary(self.mod_rabbitmq_zip())

class BuildTimeProject(Project):
    """A project that generates no artifacts of its own, and exists
    solely for the use of other projects."""
    def dirty(self):
        return False

class RabbitMQServerProject(Project):
    def dirty_test_paths(self):
        return Project.dirty_test_paths(self) + \
               [self.source_tarball_path(),
                self.store.binary_path_for(self.generic_unix_tarball_filename()),
                self.store.binary_path_for(self.windows_zipball_filename())] + \
                map(self.store.binary_path_for, self.rpm_filenames())

    def source_tarball_path(self):
        return self.store.source_path_for("rabbitmq-server-%s.tar.gz" % (self.version_str(),))

    def generic_unix_tarball_filename(self):
        return "rabbitmq-server-generic-unix-%s.tar.gz" % (self.version_str(),)

    def windows_zipball_filename(self):
        return "rabbitmq-server-windows-%s.zip" % (self.version_str(),)

    def rpm_filenames(self):
        return ["rabbitmq-server-%s-1%s.%s.rpm" % (self.version_str(), osvariant, rpmvariant)
                for osvariant in ('', '.suse')
                for rpmvariant in ('src', 'noarch')]

    def clean(self):
        with cwd_set_to(self.directory):
            # workaround bug 22457
            ssc("touch include/rabbit_framing.hrl")
            ssc("touch src/rabbit_framing.erl")
            ssc("touch deps.mk")
        Project.clean(self)

    def build(self, build_dir):
        with cwd_set_to("rabbitmq-server"):
            with http_resources_needed_for_installation() as baseurl:
                # building generic unix packages produces srcdist as a side-effect
                with cwd_set_to("packaging/generic-unix"):
                    ssc("make VERSION=%s WEB_URL=%s clean dist" % (self.version_str(), baseurl))
                    self.store.install_binary(self.generic_unix_tarball_filename())
                for f in glob.glob("dist/rabbitmq-server-%s.*" % (self.version_str(),)):
                    self.store.install_source(f)
                with cwd_set_to("packaging/RPMS/Fedora"):
                    for osvariant in ('fedora', 'suse'):
                        ssc("make rpms VERSION=%s RPM_OS=%s" % (self.version_str(), osvariant))
                        for f in qx("find . -name '*.rpm'").split():
                            self.store.install_binary(f)
                with cwd_set_to("packaging/windows"):
                    ssc("make VERSION=%s WEB_URL=%s clean dist" % (self.version_str(), baseurl))
                    self.store.install_binary(self.windows_zipball_filename())
                if self.store.want_debian():
                    with cwd_set_to("packaging/debs/Debian"):
                        tarball="rabbitmq-server-%s.tar.gz" % (self.version_str(),)
                        ssc("make UNOFFICIAL_RELEASE=1 TARBALL=%s clean package" % (tarball,))
                        for f in glob.glob("rabbitmq-server_%s*" % (self.version_str(),)):
                            self.store.install_binary(f)

class RabbitMQErlangClientProject(Project):
    def __init__(self, store, directory, source_repo, build_deps):
        Project.__init__(self, store, directory, source_repo, build_deps,
                         ezs = [("amqp_client", "Erlang AMQP client library", []),
                                ("rabbit_common", "Core AMQP codec and support library", None)])

    def clean(self):
        with cwd_set_to(self.directory):
            ssc("make clean") # no distclean available at the moment

    def untar_server_source(self, build_dir):
        with cwd_set_to(build_dir):
            p = self.store.project_named('rabbitmq-server')
            ssc("tar -zxf "+p.source_tarball_path())
            ssc("mv rabbitmq-server-%s rabbitmq-server" % (p.version_str(),))

    def build(self, build_dir):
        self.untar_server_source(build_dir)
        srcdir = os.path.join(build_dir, self.shortname + "-" + self.version_str())
        self.repo().clone(srcdir)
        with cwd_set_to(srcdir):
            ssc("make VERSION=%s" % (self.version_str(),))
            self.install_ezs()

class AutoreconfProject(Project, DebianMixin):
    def __init__(self, store, directory, source_repo, build_deps, package_name,
                 ezs = [],
                 extra_packages = []):
        Project.__init__(self, store, directory, source_repo, build_deps, ezs = ezs)
        DebianMixin.__init__(self, package_name, extra_packages = extra_packages)

    def source_tarball(self):
        return self.store.source_path_for("%s-%s.tar.gz" % (self.package_name,
                                                            self.version_str()))

    def dirty_test_paths(self):
        return [self.source_tarball()] + \
            Project.dirty_test_paths(self) + \
            DebianMixin.dirty_test_paths(self)

    def build(self, build_dir):
        with cwd_set_to(self.directory):
            if os.path.exists("Makefile"): ssc("make squeakyclean")
            ssc("autoreconf -i")
        with cwd_set_to(build_dir):
            ssc("%s/configure --prefix=%s/_install" % (self.directory, build_dir))
            ssc("make VERSION=%s distcheck" % (self.version_str(),))
            self.store.install_source("%s-%s.tar.gz" % (self.package_name, self.version_str()))
        if self.store.want_debian():
            ensure_clean_dir(build_dir)
            with cwd_set_to(build_dir):
                ssc("tar -zxvf "+self.source_tarball())
                srcdir = self.srcdir_for(".")
                self.buildpackage_in(srcdir)
            self.install_debian_artifacts(build_dir)

class EzProject(Project):
    def __init__(self, store, directory, source_repo, ezdesc):
        super(EzProject, self).__init__(store, directory, source_repo, None, ezs = None)
        self.ezdesc = ezdesc

    def description(self):
        return self.ezdesc

    def parse_makefile(self):
        with cwd_set_to(self.directory):
            def g(k):
                o = qx("egrep '^%s *:?=' Makefile" % (k,), ignoreResult = True)
                if not o: return []
                return o.split("=", 1)[1].split()
            deps = g("DEPS") # these are project names (checkout directories)
            self.build_deps = [self.store.projects[d] for d in deps]
            rundeps = g("RUNTIME_DEPS") # these are .ez names
            self.ezs = [(qx("make echo-package-name").split('\n')[-1], self.ezdesc, rundeps)]

    def compute_deps(self):
        self.parse_makefile()
        # Because .ez are packaged for debian against specific
        # rabbitmq-server versions, we make the rabbitmq-server
        # project a build dependency of the .ez project, even if it
        # doesn't explicitly depend on it itself.
        s = self.store.project_named('rabbitmq-server')
        if s not in self.build_deps:
            self.build_deps.append(s)

    def copy_dependencies(self, build_dir):
        for p in self.build_deps:
            for (ezname, ezdesc, ezrundeps) in p.ezs:
                target = os.path.join(build_dir, os.path.basename(p.directory), "dist")
                mkdir_p(target)
                cp_p(self.store.ez_path_for(ezname, p.version_str()),
                     os.path.join(target, ezname + ".ez"))

    def build(self, build_dir):
        cp_p("include.mk", build_dir)
        srcdir = os.path.join(build_dir, "%s-%s" % (self.shortname, self.version_str()))
        self.repo().clone(srcdir)
        self.copy_dependencies(build_dir)
        with cwd_set_to(srcdir):
            ssc("make")
            self.install_ezs()

class RabbitMQJavaClientProject(Project):
    def dirty_test_paths(self):
        return Project.dirty_test_paths(self) + \
               [self.store.source_path_for("rabbitmq-java-client-%s.tar.gz" % \
                                           (self.version_str(),))]

    def build(self, build_dir):
        tarball = "rabbitmq-java-client-%s.tar.gz" % (self.version_str(),)
        with cwd_set_to("rabbitmq-java-client"):
            with http_resources_needed_for_installation() as baseurl:
                ssc("make VERSION=%s WEB_URL=%s srcdist" % (self.version_str(), baseurl))
                self.store.install_source(os.path.join("build", tarball))
        with cwd_set_to(build_dir):
            ssc("tar -zxf "+self.store.source_path_for(tarball))
            with cwd_set_to("rabbitmq-java-client-%s" % (self.version_str(),)):
                ssc("make VERSION=%s dist_all" % (self.version_str(),))
                for f in glob.glob("build/rabbitmq-java-client-*-%s.*" % (self.version_str(),)):
                    self.store.install_binary(f)

class RabbitMQMochiwebProject(EzProject):
    def mochiweb_dir(self):
        return os.path.join(self.directory, "deps/mochiweb")

    def svnrev(self):
        if not hasattr(self, "_svnrev"):
            with cwd_set_to(self.mochiweb_dir()):
                self._svnrev = "svnr" + qx("make echo-revision")
        return self._svnrev

    def parse_makefile(self):
        EzProject.parse_makefile(self)
        self.ezs.append(("mochiweb", "Embedded Mochiweb", []))

    def copy_dependencies(self, build_dir):
        targetdir = os.path.join(build_dir,
                              "%s-%s/deps/mochiweb" % (self.shortname, self.version_str()))
        sc(["cp", "-rp", os.path.join(self.mochiweb_dir(), "mochiweb-svn"), targetdir])
        EzProject.copy_dependencies(self, build_dir)

    def build(self, build_dir):
        with cwd_set_to(self.mochiweb_dir()):
            ssc("make mochiweb-svn")
        EzProject.build(self, build_dir)

###########################################################################
# Class for building debian packages of .ez files

class Ez(DebianMixin):
    control_boilerplate = \
"""Section: net
Priority: extra
Maintainer: Tony Garnock-Jones <tonyg@lshift.net>
Build-Depends: debhelper (>= 7)
Standards-Version: 3.8.1
Homepage: http://www.rabbitmq.com/
Vcs-Browser: http://hg.rabbitmq.com/rabbitmq-public-umbrella

"""

    def __init__(self, store, name, description, version, runtime_deps, timestamp):
        DebianMixin.__init__(self, self.fullname(name))
        self.store = store
        self.name = name
        self.description = description
        self.version = version
        self.runtime_deps = runtime_deps
        self._timestamp = timestamp

    def timestamp(self):
        return self._timestamp

    def fullname(self, ezname):
        return "rabbitmq-plugin-" + (ezname.replace("_", "-"))

    def version_str(self):
        return self.version

    def prepare_package(self, build_dir):
        tmpdir = os.path.join(build_dir, "tmp")
        ensure_clean_dir(tmpdir)
        cp_p("-r", "ez-debian", os.path.join(tmpdir, "debian"))
        cp_p(self.store.ez_path_for(self.name, self.version), tmpdir)

        rabbit_server_version = self.store.project_named('rabbitmq-server').version_str()
        rdeps = ['rabbitmq-server (= %s-1)' % (rabbit_server_version,)] + \
                [self.fullname(d) for d in self.runtime_deps]

        with cwd_set_to(tmpdir):
            with file("plugindir", "w") as f:
                # I hate that it only searches for plugins in a version-specific place
                f.write("usr/lib/rabbitmq/lib/rabbitmq_server-%s/plugins\n" % (rabbit_server_version,))

            with file("debian/control", "w") as f:
                f.write("Source: %s\n" % (self.package_name,))
                f.write(Ez.control_boilerplate)
                f.write("Package: %s\n" % (self.package_name,))
                f.write("Architecture: all\n")
                f.write("Depends: %s\n" % (', '.join(rdeps),))
                f.write("Description: RabbitMQ plugin: %s\n" % (self.description,))

            self.gen_change_log_entry()

    def build_package(self, build_dir):
        self.buildpackage_in(os.path.join(build_dir, "tmp"), binaryOnly = True)
        self.install_debian_artifacts(build_dir)

###########################################################################
# The umbrella itself, the Store. Knows about all the Projects and
# their interrelationships, schedules the system, and manages the
# repository of artifacts built by individual Projects.

class Store(object):
    def __init__(self):
        self.source_dir = os.path.abspath("_repo/sources")
        self.binary_dir = os.path.abspath("_repo/binaries")
        self.manifest_dir = os.path.abspath("_repo/manifests")
        self.debian_dir = os.path.abspath("_repo/debian")
        self.build_dir = os.path.abspath("_build")
        self.projects = {}
        self.built_ezs = None
        self._want_debian = None

        global log_fd
        logdir = os.path.abspath("_repo/logs")
        logfilename = time.strftime("buildlog-%Y%m%d%H%M%S.txt", time.gmtime(time.time()))
        mkdir_p(logdir)
        log_fd = file(os.path.join(logdir, logfilename), "w")

    def configuration_name(self): raise NotImplementedError("subclass responsibility")

    def want_debian(self):
        if self._want_debian is None:
            self._want_debian = bool(qx("which dpkg-buildpackage", ignoreResult = True))
        return self._want_debian

    def source_path_for(self, leaf):
        return os.path.join(self.source_dir, leaf)

    def binary_path_for(self, leaf):
        return os.path.join(self.binary_dir, leaf)

    def manifest_path_for(self, project):
        return os.path.join(self.manifest_dir, project.shortname + '.manifest')

    def ez_path_for(self, ezname, v):
        return os.path.join(self.binary_dir, ezname + "-" + v + ".ez")

    def install_source(self, fname):
        log(LOG_INSTALL, "Installing", fname, "to", self.source_dir)
        cp_p(fname, self.source_dir)
    def install_binary(self, fname):
        log(LOG_INSTALL, "Installing", fname, "to", self.binary_dir)
        cp_p(fname, self.binary_dir)

    def install_ez(self, project, ez_fname, desc, v, runtime_deps, registerForPackaging = True):
        ezname = os.path.splitext(os.path.basename(ez_fname))[0]
        log(LOG_INSTALL, "Installing", ez_fname, "at version", v)
        cp_p(ez_fname, self.ez_path_for(ezname, v))
        if registerForPackaging:
            self.built_ezs.append(Ez(self, ezname, desc, v, runtime_deps, project.timestamp()))

    def register_project(self, p):
        self.projects[p.shortname] = p

    def project_named(self, name):
        return self.projects[name]

    def projects_iter(self):
        return self.projects.itervalues()

    def build_order(self):
        edges = []
        for p in self.projects_iter():
            for d in p.build_deps:
                edges.append((p, d))
        order = topsort(edges)
        order.reverse() # most-depended-on first
        # Add orphans
        order.extend(list(set(self.projects.values()) - set(order)))
        return order

    def setup(self):
        mkdir_p(self.source_dir)
        mkdir_p(self.binary_dir)
        mkdir_p(self.manifest_dir)
        self.built_ezs = []

    def finish(self):
        if self.want_debian():
            ensure_clean_dir(self.debian_dir)
            self.package_ezs()
            log(LOG_BUILD, "Constructing apt repository")
            with cwd_set_to(self.debian_dir):
                mkdir_p("conf")
                with file("conf/distributions", "w") as f: f.write(self.distributions_string())
                for fname in glob.iglob(self.binary_dir + "/*.changes"):
                    ssc("reprepro --ignore=wrongdistribution -V include kitten " + fname)
                ssc("reprepro -V createsymlinks")
        rm_rf(self.build_dir)

    def package_ezs(self):
        log(LOG_BUILD, "Packaging ezs")
        for ez in self.built_ezs:
            ensure_clean_dir(self.build_dir)
            ez.prepare_package(self.build_dir)
            ez.build_package(self.build_dir)

    def run_build(self, should_update = True):
        self.setup()

        # Ensure repositories present, up-to-date, and clean, and
        # compute dependencies (where they're not already hardcoded)
        for p in self.projects_iter():
            p.repo()
            if should_update:
                p.update()
            p.compute_deps()
        for p in self.projects_iter():
            p.clean()

        # Compute the contents of each project's manifest file.
        for p in self.projects_iter():
            with file(self.manifest_path_for(p), "w") as f:
                p.write_manifest(f)

        # At this point, we can use the version numbers that will be
        # attached to each built artefact, because the manifest
        # uniquely determines the version number. This in turn means
        # we can figure out which projects need a build, based on the
        # presence or absence of their appropriately-versioned output
        # in the store.

        dirty_projects = [p for p in self.build_order() if p.dirty()]
        log(LOG_CLEAN_CHECK, "Projects needing build:", [p.shortname for p in dirty_projects])
        for p in dirty_projects:
            for path in p.dirty_test_paths():
                if not os.path.exists(path):
                    log(LOG_CLEAN_CHECK, " -", p.shortname, "needs", path)

        for p in dirty_projects:
            ensure_clean_dir(self.build_dir)
            log(LOG_BUILD, "Building", p.directory)
            p.build(self.build_dir)
            cp_p(self.manifest_path_for(p),
                 os.path.join(self.manifest_dir,
                              p.shortname + '-' + p.version_str() + '.manifest'))

        self.finish()

    def distributions_string(self):
        return '''Origin: RabbitMQ
Label: Autobuild RabbitMQ Repository for Debian / Ubuntu etc
Suite: testing
Codename: kitten
Architectures: arm hppa ia64 mips mipsel s390 sparc i386 amd64 powerpc source
Components: main
Description: Autobuild RabbitMQ Repository for Debian / Ubuntu etc
'''

###########################################################################

class DefaultConfiguration(Store):
    def __init__(self, configuration_name, project_pins):
        Store.__init__(self)
        self._configuration_name = configuration_name
        self._project_pins = project_pins

    def configuration_name(self):
        """Return the name of this configuration, for use in version
        strings etc. See important warning in
        Project.version_str()."""
        return self._configuration_name

    def project_pin(self, projectShortname):
        return self._project_pins.get(projectShortname, None)

    def register_project(self, p):
        if self.project_pin(p.shortname) is not False: # False means omit this project
            Store.register_project(self, p)

    def tagFor(self, projectShortname):
        p = self.project_pin(projectShortname)
        if p is None: # not specified at all
            return self.default_tag()
        if p[0] == 'tag': # given a tag
            return p[1]
        return None # given something else (a branch, presumably)

    def default_tag(self):
        return None

    def branchFor(self, projectShortname):
        p = self.project_pin(projectShortname)
        if p is None: # not specified at all
            return self.default_branch()
        if p[0] == 'branch': # given a branch
            return p[1]
        return None # given something else (a tag, presumably)

    def default_branch(self):
        return None

    def rabbitHg(self, p):
        return HgRepo("http://hg.rabbitmq.com/" + p,
                      tag = self.tagFor(p),
                      branch = self.branchFor(p))

    def lshiftHg(self, p):
        return HgRepo("http://hg.opensource.lshift.net/" + p,
                      tag = self.tagFor(p),
                      branch = self.branchFor(p))

    def tonygGithub(self, p):
        return GitRepo("git://github.com/tonyg/" + p,
                       tag = self.tagFor(p),
                       branch = self.branchFor(p))

    def create_projects(self):
        # Weird. This should depend on the server.
        xmpp = RabbitMQXmppProject(self, "rabbitmq-xmpp", self.rabbitHg("rabbitmq-xmpp"), [])

        codegen = BuildTimeProject(self, "rabbitmq-codegen", self.rabbitHg("rabbitmq-codegen"), [])
        server = RabbitMQServerProject(self, "rabbitmq-server", self.rabbitHg("rabbitmq-server"),
                                       [codegen])

        # Gross: shouldn't depend on server. Only does to get the ez deb
        # rebuilt when the server version changes. Need to split the
        # ez-building part, which should depend on the server, from the
        # non-ez part, which should be generic.
        rfc4627 = GenericSimpleDebianProject(
            self, "erlang-rfc4627", self.tonygGithub("erlang-rfc4627"), [server],
            "rfc4627-erlang",
            ezs = [("rfc4627_jsonrpc",
                    "JSON (RFC 4627) codec and generic JSON-RPC server implementation",
                    [])])

        # yuuck! shouldn't depend on server
        erlang_client = RabbitMQErlangClientProject(self, "rabbitmq-erlang-client",
                                                    self.rabbitHg("rabbitmq-erlang-client"),
                                                    [server])
        rabbit_common = erlang_client # yuuuuuck! it builds many ez files

        c_client = AutoreconfProject(self, "rabbitmq-c", self.rabbitHg("rabbitmq-c"), [codegen],
                                     "librabbitmq",
                                     extra_packages = ["librabbitmq-dev", "amqp-tools"])
        stomp = EzProject(self, "rabbitmq-stomp", self.rabbitHg("rabbitmq-stomp"),
                          "STOMP protocol support")
        java = RabbitMQJavaClientProject(self, "rabbitmq-java-client",
                                         self.rabbitHg("rabbitmq-java-client"), [codegen])

        rabbithub = EzProject(self, "rabbithub", self.tonygGithub("rabbithub"),
                              "RabbitHub PubSubHubBub plugin")

        x_script = EzProject(self, "script-exchange", self.tonygGithub("script-exchange"),
                             "x-script exchange type")
        x_presence = EzProject(self, "presence-exchange", self.tonygGithub("presence-exchange"),
                               "x-presence exchange type")
        mochi = RabbitMQMochiwebProject(self, "rabbitmq-mochiweb",
                                        self.rabbitHg("rabbitmq-mochiweb"),
                                        "RabbitMQ Mochiweb adapter")
        jsonrpc = EzProject(self, "rabbitmq-jsonrpc", self.rabbitHg("rabbitmq-jsonrpc"),
                            "JSON-RPC-over-HTTP")
        jsonrpc_ch = EzProject(self, "rabbitmq-jsonrpc-channel",
                               self.rabbitHg("rabbitmq-jsonrpc-channel"),
                               "AMQP-over-JSON-RPC, plus examples")

        shovel = EzProject(self, "rabbitmq-shovel", self.rabbitHg("rabbitmq-shovel"),
                           "Rabbit Shovel plugin")

        # Not quite enough. This just produces the .ez, and doesn't
        # install the scripts yet.
        bql = EzProject(self, "rabbitmq-bql", self.rabbitHg("rabbitmq-bql"),
                        "RabbitMQ Broker Query Language")

configurations = {
    "trunk": {},
    "v1dot8": {
        "rabbitmq-java-client": ("tag", "rabbitmq_v1_8_0"),
        "rabbitmq-codegen": ("tag", "rabbitmq_v1_8_0"),
        "rabbitmq-server": ("tag", "rabbitmq_v1_8_0"),
        },
    "amqp091": {
            "rabbitmq-java-client": ("branch", "amqp_0_9_1"),
            "rabbitmq-c": ("branch", "amqp_0_9_1"),
            "rabbitmq-codegen": ("branch", "amqp_0_9_1"),
            "rabbitmq-erlang-client": ("branch", "amqp_0_9_1"),
            "rabbitmq-server": ("branch", "amqp_0_9_1"),
            },
    }

###########################################################################

def check_build_dependencies():
    log(LOG_PREREQ_CHECK, "Checking for missing build-dependencies...")
    ## This list taken from the main umbrella makefile
    build_dependency_packages = [
        "cdbs",
        "elinks",
        "fakeroot",
        "findutils",
        "gnupg",
        "gzip",
        "perl",
        "python",
        "python-simplejson",
        "rpm",
        "rsync",
        "wget",
        "reprepro",
        "tar",
        "tofrodos",
        "zip",
        "python-pexpect",
        ## "s3cmd", ## not strictly required for pb.py to do its job. Yet.
        "openssl",
        "xmlto",
        "xsltproc",

        ## The following entries are unique to this program, not
        ## present in the main umbrella makefile.
        "mercurial",
        "git-core",
        "subversion",
        "erlang",
        "erlang-src",
        "sun-java6-jdk",
        "ant",
        "zip",
        "unzip",
        "ejabberd", ## because rabbitmq-xmpp needs a header file from it
        "autoconf",
        "automake",
        "libtool",
        "libpopt-dev",
        ]
    prereq_check_output = ssc2("dpkg -L %s > /dev/null" % (' '.join(build_dependency_packages),),
                               ignoreResult = True)[1]
    if prereq_check_output:
        log_color(LOG_PREREQ_CHECK, COLOR_RED, "WARNING: missing build-time dependency packages:")
        log_color(LOG_PREREQ_CHECK, COLOR_RED, prereq_check_output)

if __name__ == '__main__':
    import optparse
    parser = optparse.OptionParser()

    try:
        with file(".pb.preset", "r") as f:
            default_preset = f.read()
    except:
        default_preset = "trunk"

    parser.add_option("-u", "--update", dest="update", default=True, action="store_true",
                      help="perform updates on already-checked-out repos (DEFAULT)")
    parser.add_option("-U", "--no-update", dest="update", action="store_false",
                      help="do not perform updates on already-checked-out repos")
    parser.add_option("-p", "--preset", default=default_preset,
                      help=("select preset and update default (one of %s; "
                            "the default is currently %s)" % \
                                (', '.join(repr(k) for k in configurations.keys()),
                                 repr(default_preset))))

    (options, args) = parser.parse_args()
    if args:
        parser.error("Positional arguments are not permitted")

    check_build_dependencies()
    store = DefaultConfiguration(options.preset, configurations[options.preset])
    store.create_projects()

    # Update the preset so it doesn't have to be specified later.
    with file(".pb.preset", "w") as f:
        f.write(options.preset)

    store.run_build(options.update)
