#!/usr/bin/env python

from optparse import OptionParser
from subprocess import Popen, PIPE
import sys, os, copy, pprint, re
from distutils.version import StrictVersion

# There is no real dependency management here, if there are
# dependencies between community plugins list them in order.
#
# Let's keep the same order as the website.

PLUGINS = {
    # Routing
    'rabbitmq_lvc':                      {'url': 'https://github.com/rabbitmq/rabbitmq-lvc-plugin',
                                          'erlang': 'R14B'},
    'rabbitmq_rtopic_exchange':          {'url': 'https://github.com/rabbitmq/rabbitmq-rtopic-exchange'},
    'rabbitmq_recent_history_exchange':  {'url': 'https://github.com/rabbitmq/rabbitmq-recent-history-exchange'},
    'rabbitmq_delayed_message_exchange': {'url': 'https://github.com/rabbitmq/rabbitmq-delayed-message-exchange'},
    'rabbitmq_routing_node_stamp':       {'url': 'https://github.com/rabbitmq/rabbitmq-routing-node-stamp'},
    'rabbitmq_message_timestamp':        {'url': 'https://github.com/rabbitmq/rabbitmq-message-timestamp'},

    # Auth
    'rabbitmq_auth_backend_http':        {'url': 'https://github.com/rabbitmq/rabbitmq-auth-backend-http',
                                          'erlang': 'R14B'},
    'rabbitmq_auth_backend_amqp':        {'url': 'https://github.com/rabbitmq/rabbitmq-auth-backend-amqp'},
    'rabbitmq_auth_backend_ip_range':    {'url': 'https://github.com/gotthardp/rabbitmq-auth-backend-ip-range',
                                          'erlang': '17'},
    'rabbitmq_trust_store':              {'url': 'https://github.com/rabbitmq/rabbitmq-trust-store'},

    # Management
    'rabbitmq_top':                      {'url': 'https://github.com/rabbitmq/rabbitmq-top'},
    'rabbitmq_management_exchange':      {'url': 'https://github.com/rabbitmq/rabbitmq-management-exchange',
                                          'erlang': 'R14B'},
    'rabbitmq_event_exchange':           {'url': 'https://github.com/rabbitmq/rabbitmq-event-exchange'},
    'rabbitmq_management_themes':        {'url': 'https://github.com/rabbitmq/rabbitmq-management-themes'},
    'rabbitmq_autocluster_consul':       {'url': 'https://github.com/aweber/rabbitmq-autocluster-consul',
                                          'erlang': 'R15B'},
    'rabbitmq_boot_steps_visualiser':    {'url': 'https://github.com/rabbitmq/rabbitmq-boot-steps-visualiser'},
    'rabbitmq_clusterer':                {'url': 'https://github.com/rabbitmq/rabbitmq-clusterer'},

    # Logging
    'rabbitmq_lager':                    {'url': 'https://github.com/hyperthunk/rabbitmq-lager',
                                          'erlang': 'R14B',
                                          'version-add-hash': False},

    # Queues
    'rabbitmq_sharding':                 {'url': 'https://github.com/rabbitmq/rabbitmq-sharding'},

    # Protocols
    'gen_smtp':                          {#'url': 'https://github.com/gotthardp/gen_smtp',
                                          'wrapper-url': 'https://github.com/gotthardp/rabbitmq-gen-smtp',
                                          'version-add-hash': False,
                                          'erlang': 'R16B'},
    'rabbitmq_email':                    {'url': 'https://github.com/gotthardp/rabbitmq-email',
                                          'erlang': 'R16B'},
    'rfc4627_jsonrpc':                   {'url': 'https://github.com/rabbitmq/erlang-rfc4627-wrapper',
                                          'version-add-hash': False},
    'rabbitmq_jsonrpc':                  {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc'},
    'rabbitmq_jsonrpc_channel':          {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc-channel'},
    'rabbitmq_jsonrpc_channel_examples': {'url': 'https://github.com/rabbitmq/rabbitmq-jsonrpc-channel-examples'},
    'epgsql':                            {'url': 'https://github.com/gmr/epgsql-wrapper',
                                          'version-add-hash': False},
    'pgsql_listen_exchange':             {'url': 'https://github.com/aweber/pgsql-listen-exchange',
                                          'erlang': 'R16B'},

    'gen_coap':                          {#'url': 'https://github.com/gotthardp/gen_coap',
                                          'wrapper-url': 'https://github.com/gotthardp/rabbitmq-gen-coap',
                                          'version-add-hash': False,
                                          'erlang': '17'},
    'rabbitmq_coap_pubsub':              {'url': 'https://github.com/gotthardp/rabbitmq-coap-pubsub',
                                          'erlang': '17'},
    'rabbitmq_web_mqtt':                 {'url': 'https://github.com/rabbitmq/rabbitmq-web-mqtt'},
}

DEFAULT_OTP_VERSIONS = {
        'a_long_time_ago': 'R13B03',
        '3.6.x': 'R16B03',
        '3.7.x': '18.3',
}

BUILD_DIR = "/var/tmp/plugins-build/"
CURRENT_DIR = os.getcwd()
RABBITMQ_TAG = ""
GITREPOBASE="https://github.com/rabbitmq"
USE_OLD_FASHION_BUILD = True
SERVER_PROVIDED_DEPS = []
RUN_TESTS = True

def main():
    parser = OptionParser(usage=sys.argv[0])
    parser.add_option("-p", "--plugin",
                      dest="plugins",
                      action="append",
                      help="build a specific plugin. Can be given multiple times.")
    parser.add_option("-t", "--server-tag",
                      dest="server_tag",
                      help="build against specific server tag")
    parser.add_option("-R", "--repo-base",
                      dest="repo_base",
                      help="clone from alternative git repository base URL")
    parser.add_option("-d", "--build-dir",
                      dest="build_dir",
                      help="build directory")
    parser.add_option("-T", "--no-tests",
                      action="store_false", dest="run_tests", default=True,
                      help="Do not run the testsuite")

    (options, args) = parser.parse_args()
    if options.plugins is None:
        plugins = PLUGINS
    else:
        plugins = []
        plugins_not_found = 0
        for p in options.plugins:
            tokens = p.split('@')
            name = tokens[0]
            if name in PLUGINS:
                details = PLUGINS[name]
                if len(tokens) == 2:
                    details['tag'] = tokens[1]
                plugins.append((name, details))
            else:
                print "Plugin {0} not found".format(name)
                plugins_not_found = 1
        if plugins_not_found:
            sys.exit(1)
        print "Building    : {0}".format(", ".join(options.plugins))
    if options.repo_base is not None:
        global GITREPOBASE
        GITREPOBASE = options.repo_base
    if options.build_dir is not None:
        global BUILD_DIR
        BUILD_DIR = options.build_dir
    global RUN_TESTS
    RUN_TESTS = options.run_tests
    print "Destination : {0}".format(BUILD_DIR)
    if os.path.exists(BUILD_DIR):
        print "\nError: {0} exists. Not building.".format(BUILD_DIR)
        sys.exit(1)
    os.makedirs("{0}/plugins".format(BUILD_DIR))
    checkout(options.server_tag)
    global USE_OLD_FASHION_BUILD
    USE_OLD_FASHION_BUILD = RABBITMQ_TAG and get_server_version() < '3.6.x'
    if not USE_OLD_FASHION_BUILD:
        global SERVER_PROVIDED_DEPS
        SERVER_PROVIDED_DEPS = server_provided_deps()
    print "Version     : {0}\n".format(get_server_version())
    print "Building..."
    [build(p) for p in plugins]

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
    do("git", "clone", GITREPOBASE + "/rabbitmq-public-umbrella.git")
    cd(CURRENT_DIR + "/rabbitmq-public-umbrella")
    if opt_tag is None:
        RABBITMQ_TAG = get_tag(do("git", "tag", "-l", "rabbitmq*").split('\n'))
        do("make", "co")
    else:
        RABBITMQ_TAG = opt_tag
        do("git", "checkout", RABBITMQ_TAG)
        do("make", "co")
        do("./foreachrepo", "git", "checkout", RABBITMQ_TAG)

def get_tag(lines):
    highest_tag = lines[0]
    highest_version = tag_to_version(highest_tag)
    for tag in lines:
        if not tag:
            continue
        version = tag_to_version(tag)
        if StrictVersion(version) >= StrictVersion(highest_version):
            highest_tag = tag
            highest_version = version
    return highest_tag

def tag_to_version(tag):
    return re.sub(r'_', '.', re.sub(r'^rabbitmq_v', '', tag))

def get_server_version():
    return RABBITMQ_TAG[10:].replace('_', '.')[:-1] + "x"

def server_provided_deps():
    if USE_OLD_FASHION_BUILD:
        return
    cd(CURRENT_DIR + '/deps/rabbit')
    do('touch', 'git-revisions.txt')
    do('make', 'list-deps')
    deps = []
    for line in open(os.path.join(CURRENT_DIR, '.erlang.mk', 'list-deps.log')):
        deps.append(os.path.basename(line.strip()))
    do('rm', 'git-revisions.txt')
    cd(BUILD_DIR + '/rabbitmq-public-umbrella')
    return deps

def build((plugin, details)):
    sys.stdout.write(" * {0}".format(plugin))
    sys.stdout.flush()
    try:
        do_build(plugin, details)
        print ''
    except BuildError as e:
        print " FAILED"
        with open(plugin + '.err', 'w') as f:
            for elem in e.value:
                f.write("{0}".format(elem))

def do_build(plugin, details):
    global USE_OLD_FASHION_BUILD
    if USE_OLD_FASHION_BUILD:
        cd(BUILD_DIR + "/rabbitmq-public-umbrella")
        targets = ["check-xref"]
        if RUN_TESTS:
            targets.append('test')
        targets.append('srcdist')
    else:
        cd(BUILD_DIR + "/rabbitmq-public-umbrella/deps")
        targets = ['update-rabbitmq-components-mk']
        if RUN_TESTS:
            targets.append('tests')
    targets.append('dist')

    if 'version-add-hash' in details:
        version_add_hash = details['version-add-hash']
    else:
        version_add_hash = True

    server_version = get_server_version()

    if 'erlang' in details:
        erlang_version = details['erlang']
    else:
        erlang_version = DEFAULT_OTP_VERSIONS['a_long_time_ago']
    if not USE_OLD_FASHION_BUILD:
        erlang_version = DEFAULT_OTP_VERSIONS[server_version]

    ensure_otp(erlang_version)

    if USE_OLD_FASHION_BUILD:
        if 'wrapper-url' in details:
            url = details['wrapper-url']
        else:
            url = details['url']
        checkout_dir = url.split("/")[-1].split(".")[0]
    else:
        if 'wrapper-url' in details:
            # Skip wrappers, they will be pulled as normal Erlang.mk
            # dependencies.
            return
        url = details['url']
        checkout_dir = plugin
    cloned = False
    if not os.path.exists(os.path.join(CURRENT_DIR, checkout_dir)):
        do("git", "clone", url, checkout_dir)
        cloned = True
    cd(CURRENT_DIR + "/" + checkout_dir)

    if 'tag' in details:
        do("git", "checkout", details['tag'])
    else:
        do("git", "checkout", "master")

    hash = do("git", "--git-dir=./.git", "rev-parse", "HEAD")[0:8]
    if version_add_hash:
        plugin_version = "{0}-{1}".format(server_version, hash)
    else:
        plugin_version = server_version

    if USE_OLD_FASHION_BUILD:
        [do("make", "-j2", "VERSION={0}".format(plugin_version), target, erlang=erlang_version) for target in targets]
    else:
        [do("make", "VERSION={0}".format(plugin_version), target, erlang=erlang_version) for target in targets]
    dest_dir = os.path.join(BUILD_DIR, "plugins", "v" + server_version)
    ensure_dir(dest_dir)
    if USE_OLD_FASHION_BUILD:
        cmd = ['cp'] + \
           find_package("{0}/dist/".format(CURRENT_DIR), plugin, ".ez") + \
           [dest_dir]
        do(*cmd)
        dest_src_dir = os.path.join(dest_dir, "src")
        ensure_dir(dest_src_dir)
        cmd = ['cp'] + \
           find_package("{0}/srcdist/".format(CURRENT_DIR), plugin, ".tar.bz2") + \
           [dest_src_dir]
        do(*cmd)
    else:
        cmd = ['cp'] + \
           find_package("{0}/plugins/".format(CURRENT_DIR), '*', '.ez') + \
           [dest_dir]
        do(*cmd)

def find_package(dir, wanted, suffix):
    global SERVER_PROVIDED_DEPS
    packages = []
    for f in os.listdir(dir):
        name = f.split('-')[0]
        if (wanted == '*' or name == wanted) and f.endswith(suffix) and \
        not name in SERVER_PROVIDED_DEPS:
            packages.append(os.path.join(dir, f))
    if len(packages) == 0:
        raise BuildError(['no_package', dir, wanted, suffix])
    return packages

def do(*args, **kwargs):
    path = os.environ['PATH']
    env = copy.deepcopy(os.environ)
    if 'erlang' in kwargs:
        erlang_version = kwargs['erlang']
        if not 'skip_ensure' in kwargs:
            ensure_otp(erlang_version)
        env['PATH'] = "{0}/bin:{1}".format(otp_dir(erlang_version), path)
    if not USE_OLD_FASHION_BUILD:
        env['PATH'] = "{0}/rabbitmq-public-umbrella/.erlang.mk/rebar:{1}".format(BUILD_DIR, env['PATH'])
    proc = Popen(args, cwd = CURRENT_DIR, env = env,
                 stdout = PIPE, stderr = PIPE)
    (stdout, stderr) = proc.communicate()
    ret = proc.poll()
    if ret == 0:
        return stdout
    else:
        raise BuildError(['proc_failed', pprint.pformat({'return': ret, 'current_dir': CURRENT_DIR, 'args': args}), stdout, stderr])

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
