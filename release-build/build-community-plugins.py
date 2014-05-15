#!/usr/bin/env python

from optparse import OptionParser
from subprocess import Popen, PIPE
import sys, os, copy

# There is no real dependency management here, if there are
# dependencies between community plugins list them in order.
#
# Let's keep the same order as the website.

PLUGINS = [
    # Routing
    ('rabbitmq_lvc',                      {'url': 'https://github.com/simonmacmullen/rabbitmq-lvc-plugin'}),
    ('rabbitmq_rtopic_exchange',          {'url': 'https://github.com/videlalvaro/rabbitmq-rtopic-exchange'}),
    ('rabbitmq_recent_history_exchange',  {'url': 'https://github.com/videlalvaro/rabbitmq-recent-history-exchange'}),

    # Auth
    ('rabbitmq_auth_backend_http',        {'url': 'https://github.com/simonmacmullen/rabbitmq-auth-backend-http'}),
    ('rabbitmq_auth_backend_amqp',        {'url': 'https://github.com/simonmacmullen/rabbitmq-auth-backend-amqp'}),

    # Management
    ('rabbitmq_top',                      {'url': 'https://github.com/simonmacmullen/rabbitmq-top'}),
    ('rabbitmq_management_exchange',      {'url': 'https://github.com/simonmacmullen/rabbitmq-management-exchange'}),
    ('rabbitmq_event_exchange',           {'url': 'https://github.com/simonmacmullen/rabbitmq-event-exchange'}),

    # Distribution
    ('rabbitmq_sharding',                 {'url': 'https://github.com/rabbitmq/rabbitmq-sharding'}),

    # Protocols
    ('rfc4627_jsonrpc',                   {'url': 'https://github.com/rabbitmq/erlang-rfc4627-wrapper',
                                           'version-add-hash': False}),
    ('rabbitmq_jsonrpc',                  {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc'}),
    ('rabbitmq_jsonrpc_channel',          {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc-channel'}),
    ('rabbitmq_jsonrpc_channel_examples', {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc-channel-examples'}),
    ('epgsql',                            {'url': 'https://github.com/gmr/epgsql-wrapper',
                                           'version-add-hash': False}),
    ('pgsql_listen_exchange',             {'url': 'https://github.com/aweber/pgsql-listen-exchange',
                                           'erlang': 'R16B'}),
]

DEFAULT_OTP_VERSION="R13B03"
BUILD_DIR = "/var/tmp/plugins-build/"
CURRENT_DIR = os.getcwd()
RABBITMQ_TAG = ""
HGREPOBASE="ssh://hg@rabbit-hg-private"

def main():
    parser = OptionParser(usage=sys.argv[0])
    parser.add_option("-p", "--plugin",
                      dest="plugins",
                      action="append",
                      help="build a specific plugin. Can be given multiple times.")
    parser.add_option("-t", "--server-tag",
                      dest="server_tag",
                      help="build against specific server tag")
    parser.add_option("-T", "--plugin-tag",
                      dest="plugin_tag",
                      help="build against specific plugin tag")
    parser.add_option("-R", "--repo-base",
                      dest="repo_base",
                      help="clone from alternative hg repository base URL")
    parser.add_option("-d", "--build-dir",
                      dest="build_dir",
                      help="build directory")
    (options, args) = parser.parse_args()
    if options.plugins is None:
        plugins = PLUGINS
    else:
        plugins = [(k, v) for (k, v) in PLUGINS if k in options.plugins]
        if len(plugins) == 0:
            print "Plugin {0} not found".format(options.plugin)
            sys.exit(1)
        print "Building    : {0}".format(", ".join(options.plugins))
    if options.repo_base is not None:
        global HGREPOBASE
        HGREPOBASE = options.repo_base
    if options.build_dir is not None:
        global BUILD_DIR
        BUILD_DIR = options.build_dir
    print "Destination : {0}".format(BUILD_DIR)
    if os.path.exists(BUILD_DIR):
        print "\nError: {0} exists. Not building.".format(BUILD_DIR)
        sys.exit(1)
    os.makedirs("{0}/plugins".format(BUILD_DIR))
    ensure_otp(DEFAULT_OTP_VERSION)
    checkout(options.server_tag)
    print "Version     : {0}\n".format(server_version())
    print "Building..."
    [build(p, options.plugin_tag) for p in plugins]

def ensure_dir(d):
    if not os.path.exists(d):
        os.makedirs(d)

def ensure_otp(version_wanted):
    erl_cmd = 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'
    erl_ver = do("erl", "-noshell", "-eval", erl_cmd, erlang=version_wanted, skip_ensure=True).rstrip()
    if erl_ver != version_wanted:
        print "Erlang {0} found, not {1}".format(erl_ver, version_wanted)
        print "Suggestion: ./install-otp.sh {0}".format(version_wanted)
        exit(1)

def otp_dir(version):
    return "{0}/otp-{1}".format(os.environ["HOME"], version)

def checkout(opt_tag):
    global RABBITMQ_TAG
    print "Checking out umbrella..."
    cd(BUILD_DIR)
    do("hg", "clone", HGREPOBASE + "/rabbitmq-public-umbrella")
    cd(CURRENT_DIR + "/rabbitmq-public-umbrella")
    if opt_tag is None:
        RABBITMQ_TAG = get_tag(do("hg", "tags").split('\n'))
        do("make", "checkout")
    else:
        RABBITMQ_TAG = opt_tag
        do("hg", "up", "-r", RABBITMQ_TAG)
        do("make", "checkout")
        do("./foreachrepo", "hg", "up", "-r", RABBITMQ_TAG)

def get_tag(lines):
    for line in lines:
        if line.startswith('rabbitmq'):
            return line.split(' ')[0]
    return None

def server_version():
    return RABBITMQ_TAG[10:].replace('_', '.')[:-1] + "x"

def build((plugin, details), tag):
    print " * {0}".format(plugin)
    cd(BUILD_DIR + "/rabbitmq-public-umbrella")
    url = details['url']
    if 'version-add-hash' in details:
        version_add_hash = details['version-add-hash']
    else:
        version_add_hash = True
    if 'erlang' in details:
        erlang_version = details['erlang']
    else:
        erlang_version = DEFAULT_OTP_VERSION
    do("git", "clone", url)
    checkout_dir = url.split("/")[-1].split(".")[0]
    cd(CURRENT_DIR + "/" + checkout_dir)
    if tag is None:
        do("git", "checkout", "master")
    else:
        do("git", "checkout", tag)
    hash = do("git", "--git-dir=./.git", "rev-parse", "HEAD")[0:8]
    if version_add_hash:
        plugin_version = "{0}-{1}".format(server_version(), hash)
    else:
        plugin_version = server_version()
    do("make", "-j", "VERSION={0}".format(plugin_version), "srcdist", erlang=erlang_version)
    do("make", "-j", "VERSION={0}".format(plugin_version), "dist", erlang=erlang_version)
    dest_dir = os.path.join(BUILD_DIR, "plugins", "v" + server_version())
    dest_src_dir = os.path.join(dest_dir, "src")
    ensure_dir(dest_dir)
    ensure_dir(dest_src_dir)
    do("cp", find_package("{0}/dist/".format(CURRENT_DIR), plugin, ".ez"),
       dest_dir)
    do("cp",
       find_package("{0}/srcdist/".format(CURRENT_DIR), plugin, ".tar.bz2"),
       dest_src_dir)

def find_package(dir, prefix, suffix):
    for f in os.listdir(dir):
        if f.startswith(prefix) and f.endswith(suffix):
            return os.path.join(dir, f)
    raise BuildError(['no_package', dir, prefix, suffix])

def do(*args, **kwargs):
    path = os.environ['PATH']
    env = copy.deepcopy(os.environ)
    erlang_version = DEFAULT_OTP_VERSION
    if 'erlang' in kwargs:
        erlang_version = kwargs['erlang']
        if not 'skip_ensure' in kwargs:
            ensure_otp(erlang_version)
    env['PATH'] = "{0}/bin:{1}".format(otp_dir(erlang_version), path)
    proc = Popen(args, cwd = CURRENT_DIR, env = env,
                 stdout = PIPE, stderr = PIPE)
    (stdout, stderr) = proc.communicate()
    ret = proc.poll()
    if ret == 0:
        return stdout
    else:
        raise BuildError(['proc_failed', {'return': ret, 'current_dir': CURRENT_DIR, 'args': args, 'output': [stdout, stderr]}])

def cd(d):
    global CURRENT_DIR
    CURRENT_DIR = d

class BuildError(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

if __name__ == "__main__":
    try:
        main()
    except BuildError as e:
        print "BUILD FAILED\n============"
        for elem in e.value:
            print elem
        exit(1)
