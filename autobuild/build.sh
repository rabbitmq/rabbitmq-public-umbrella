#!/bin/bash

# An automated rabbitmq build script
#
# Example Usage:
# autobuild/rabbitmq-build BUILD_USERHOST=etch VERSION=1.7.$[`date +'%Y%m%d'` - 20090000] WIN_USERHOST="David Wragg@192.168.122.85" DEPLOY_USERHOST=mrbraver.lshift.net

# You should provide values for the following variables on the command line:

# The RabbitMQ version number, X.Y.Z
VERSION=

# The ssh user@host to use for the main build
BUILD_USERHOST=

# The windows ssh user@host to use for the windows bits.  If you omit
# it, the windows bits won't get built.
WIN_USERHOST=

# Setting the following variables is optional.

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# Where the keys live.  If not set, we will do an "unofficial release"
KEYSDIR=

# Other signing parameters to pass to the rabbitmq-umbrella Makefile.
# If KEYSDIR isn't pointing to the release keys, you will need to
# supply something here to set the Makefile's SIGNING_* vars.
SIGNING_PARAMS=

# The base URL of the rabbitmq website used to retrieve documentation.
# If empty, we start a local python web server.  Should include a
# trailing slash.
WEB_URL=

# The directory in which the rabbitmq-website repo lives.  If empty,
# we will do a fresh clone of the 'next' branch
WEBSITE_REPO=

# The email address field to use in package changelog
# entries.  If you omit this, changelog entries won't be added.
CHANGELOG_EMAIL=

# The comment for changelog entires
CHANGELOG_COMMENT="Test release"

# RSync user/host to deploy to.  If empty, we don't deploy.
DEPLOY_USERHOST=

# The directory on the local host to use for the build.  If not set,
# we will use a uniquely-named directory in /var/tmp.
TOPDIR=

# Which existing hg repos to copy into rabbitmq-umbrella, instead of
# letting it clone them.
REPOS=

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Where the rabbitmq-umbrella repo lives.  If not set, we assume it is
# the grandparent-directory of this script.
UMBRELLADIR=

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

function die () {
  echo "$@" 2>&1
  exit 1
}

# Check mandatory settings
for v in BUILD_USERHOST WIN_USERHOST VERSION SCRIPTDIR ; do
  [[ -n "${!v}" ]] || die "$v not set"
done

# SCRIPTDIR should be absolute
case $SCRIPTDIR in
/*)
    ;;
*)
    SCRIPTDIR="$PWD/$SCRIPTDIR"
    ;;
esac

[[ -n "$UMBRELLADIR" ]] || UMBRELLADIR=$SCRIPTDIR/..

[[ -n "$ROOT_USERHOST" ]] || ROOT_USERHOST=$(echo "$BUILD_USERHOST" | sed 's|^[^@]*@||;s|^|root@|')

if [[ -z "$KEYSDIR" ]] ; then
  UNOFFICIAL_RELEASE=1
fi

# Lower-case topdir is the directory in /var/tmp where we do the build
# on the remote hosts.  TOPDIR may be different.
topdir=/var/tmp/rabbit-build.$$
[[ -z "$TOPDIR" ]] && TOPDIR="$topdir"

echo "Build settings:"
for v in VERSION SCRIPTDIR BUILD_USERHOST ROOT_USERHOST WIN_USERHOST SSH_OPTS KEYSDIR SIGNING_PARAMS WEB_URL CHANGELOG_EMAIL CHANGELOG_COMMENT TOPDIR topdir REPOS WEBSITE_REPO UNOFFICIAL_RELEASE ; do
  echo "${v}=${!v}"
done

set -e -x

# Verify that we can ssh into the hosts, just in case
ssh $SSH_OPTS $BUILD_USERHOST 'true'
ssh $SSH_OPTS $ROOT_USERHOST 'true'
[ -n "$WIN_USERHOST" ] && ssh $SSH_OPTS "$WIN_USERHOST" 'true'

# Prepare the build host.  Debian etch needs some work to get it in shape
ssh $SSH_OPTS $ROOT_USERHOST '
    set -e -x
    if [ "$(cat /etc/debian_version)" = "4.0" ] ; then
        echo "deb http://ftp.uk.debian.org/debian/ etch-proposed-updates main" >/etc/apt/sources.list.d/proposed-updates.list
    fi
    DEBIAN_FRONTEND=noninteractive ; export DEBIAN_FRONTEND
    apt-get -y update
    apt-get -y dist-upgrade
    apt-get -y install ncurses-dev rsync cdbs elinks python-simplejson rpm reprepro tofrodos zip unzip ant sun-java5-jdk htmldoc plotutils transfig graphviz docbook-utils texlive-fonts-recommended gs-gpl python2.5 erlang-dev python-pexpect'

mkdir -p $TOPDIR
cp -a $SCRIPTDIR/install-otp.sh $TOPDIR
cd $TOPDIR

# Copy rabbitmq-umbrella into place
cp -a $UMBRELLADIR/../rabbitmq-umbrella .

cd rabbitmq-umbrella
for repo in $REPOS ; do
    cp -a $repo .
done

make checkout HG_OPTS="-e 'ssh $SSH_OPTS'"

if [[ -n "$CHANGELOG_EMAIL" ]] ; then
    # Tweak changelogs
    ( cd rabbitmq-server/packaging/debs/Debian/debian ; DEBEMAIL="$CHANGELOG_EMAIL" dch -v ${VERSION}-1 --check-dirname-level 0 "$CHANGELOG_COMMENT" )
    
    spec=rabbitmq-server/packaging/RPMS/Fedora/rabbitmq-server.spec
    mv $spec $spec~
    sed -ne '0,/^%changelog/p' <$spec~ >$spec
    cat >>$spec <<EOF
* $(date +'%a %b %-d %Y') ${CHANGELOG_EMAIL} ${VERSION}-1
- ${CHANGELOG_COMMENT}

EOF
    sed -ne '/^%changelog/,$p' <$spec~ | tail -n +2 >>$spec
fi

# rsync should take account of SSH_OPTS
RSYNC_RSH="ssh $SSH_OPTS"
export RSYNC_RSH

rsync -a $TOPDIR/ $BUILD_USERHOST:$topdir

# Do per-user install of the required erlang/OTP versions
ssh $SSH_OPTS $BUILD_USERHOST $topdir/install-otp.sh

if [ -z "$WEB_URL" ] ; then
    # Run the website under a local python process
    if [[ -n "$WEBSITE_REPO" ]] ; then
        cd $WEBSITE_REPO
    else
        cd $TOPDIR
        hg clone -e "ssh $SSH_OPTS" -r next ssh://hg@hg.lshift.net/rabbitmq-website
        cd rabbitmq-website
    fi

    python driver.py &
    trap "kill $!" EXIT
    sleep 1
    cd $TOPDIR
    WEB_URL="http://$(hostname):8191/"
fi

# Do the windows build
if [ -n "$WIN_USERHOST" ] ; then
    vars="RABBIT_VSN=$VERSION UNOFFICIAL_RELEASE=$UNOFFICIAL_RELEASE SKIP_MSIVAL2=1 WEB_URL=\"$WEB_URL\""

    dotnetdir=$topdir/rabbitmq-umbrella/rabbitmq-dotnet-client
    local_dotnetdir=$TOPDIR/rabbitmq-umbrella/rabbitmq-dotnet-client
    
    ssh $SSH_OPTS "$WIN_USERHOST" "mkdir -p $dotnetdir"
    rsync -a $local_dotnetdir/ "$WIN_USERHOST:$dotnetdir"

    if [ -n "$KEYSDIR" ] ; then
        rsync -a $KEYSDIR/dotnet/rabbit.snk "$WIN_USERHOST:$dotnetdir"
        vars="$vars KEYFILE=rabbit.snk"
    fi

    # Do the initial nant-based build
    ssh $SSH_OPTS "$WIN_USERHOST" '
        set -e -x
        # The PATH when you ssh in to the cygwin sshd is missing things
        PATH="$PATH:$(cygpath -p "$SYSTEMROOT\microsoft.net\framework\v3.5;$PROGRAMFILES\msival2;$PROGRAMFILES\wix;$PROGRAMFILES\Microsoft SDKs\Windows\v6.1\Bin")"
        cd '$dotnetdir'
        { '"$vars"' ./dist.sh && touch dist.ok ; rm -f rabbit.snk ; } 2>&1 | tee dist.log ; test -e dist.ok
    '

    # Copy things across to the linux build host
    rsync -av "$WIN_USERHOST:$dotnetdir/" $local_dotnetdir
    rsync -av $local_dotnetdir/ $BUILD_USERHOST:$dotnetdir
    ssh $SSH_OPTS $BUILD_USERHOST '
        set -e -x
        cd '$dotnetdir'
        { make RABBIT_VSN='$VERSION' doc && touch doc.ok ; } 2>&1 | tee doc.log ; test -e doc.ok
    '

    # Now we go back to windows for the installer build
    rsync -av $BUILD_USERHOST:$dotnetdir/ $local_dotnetdir
    rsync -av $local_dotnetdir/ "$WIN_USERHOST:$dotnetdir"
    ssh $SSH_OPTS "$WIN_USERHOST" '
        set -e -x
        # The PATH when you ssh in to the cygwin sshd is missing things
        PATH="$PATH:$(cygpath -p "$SYSTEMROOT\microsoft.net\framework\v3.5;$PROGRAMFILES\msival2;$PROGRAMFILES\wix;$PROGRAMFILES\Microsoft SDKs\Windows\v6.1\Bin")"
        cd '$dotnetdir'
        { '"$vars"' ./dist-msi.sh && touch dist-msi.ok ; } 2>&1 | tee dist-msi.log ; test -e dist-msi.ok 
    '

    # The cygwin rsync sometimes hangs.  This rm works around it.
    # It's magic.
    rm -rf $local_dotnetdir/build
    rsync -av "$WIN_USERHOST:$dotnetdir/" $local_dotnetdir
    rsync -av $local_dotnetdir/ $BUILD_USERHOST:$dotnetdir
    ssh $SSH_OPTS "$WIN_USERHOST" "rm -rf $topdir"
fi

vars="VERSION=$VERSION WEB_URL=\"$WEB_URL\" UNOFFICIAL_RELEASE=$UNOFFICIAL_RELEASE"

if [ -n "$KEYSDIR" ] ; then
    # Need to sign
    rsync -rv $KEYSDIR/keyring/ $BUILD_USERHOST:$topdir/keyring/
    vars="$vars GNUPG_PATH=$topdir/keyring $SIGNING_PARAMS"
fi

ssh $SSH_OPTS $BUILD_USERHOST '
    set -e -x
    PATH=$HOME/otp-R11B-5/bin:$PATH
    JAVA_HOME=/usr/lib/jvm/java-1.5.0-sun
    export JAVA_HOME
    cd '$topdir'
    [ -d keyring ] && chmod -R a+rX,u+w keyring
    cd rabbitmq-umbrella
    { make dist '"$vars"' ERLANG_CLIENT_OTP_HOME=$HOME/otp-R12B-5 && touch dist.ok ; rm -rf '$topdir'/keyring ; } 2>&1 | tee dist.log ; test -e dist.ok
'

rsync -av $BUILD_USERHOST:$topdir/ $TOPDIR 
ssh $SSH_OPTS $BUILD_USERHOST "rm -rf $topdir"

# Nearly there!
if [[ -n "$DEPLOY_USERHOST" ]] ; then
    cd $TOPDIR/rabbitmq-umbrella
    make deploy-stage STAGE_DEPLOY_HOST="$DEPLOY_USERHOST" SSH_OPTS="$SSH_OPTS"
fi
