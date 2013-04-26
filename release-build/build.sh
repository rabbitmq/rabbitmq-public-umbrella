#!/bin/bash

# An automated rabbitmq build script
#
# Example Usage:
# release-build/build.sh BUILD_USERHOST=etch VERSION=1.7.$[`date +'%Y%m%d'` - 20090000] WIN_USERHOST="David Wragg@192.168.122.85" DEPLOY_USERHOST=mrbraver.lshift.net

# You should provide values for the following variables on the command line:

# The RabbitMQ version number, X.Y.Z
VERSION=

# The ssh user@host to use for the main build
BUILD_USERHOST=

# The windows ssh user@host to use for the windows bits.  If you omit
# it, the windows bits won't get built.
WIN_USERHOST=

# The Mac ssh user@host to use for the mac bits.  If you omit
# it, the mac bits won't get built.
MAC_USERHOST=

# Setting the following variables is optional.

# Options to pass to ssh commands.  '-i identity_file' is useful for
# using a special ssh key.
SSH_OPTS=

# Optional custom hg url base.  Useful if you're builiding remotely
# and tunneling into rabbit-hg.
HGREPOBASE=

# Where the keys live.  If not set, we will do an "unofficial release"
KEYSDIR=

# Other signing parameters to pass to the rabbitmq-public-umbrella Makefile.
# If KEYSDIR isn't pointing to the release keys, you will need to
# supply something here to set the Makefile's SIGNING_* vars.
SIGNING_PARAMS=

# The base URL of the rabbitmq website used to retrieve documentation.
# If empty, we start a local python web server.  Should include a
# trailing slash.
#
# Make sure your proxy configuration for elinks on BUILD_USERHOST
# correctly includes or excludes the hostname of this URL. Using
# $(hostname -f) instead of $(hostname) when running a local python
# webserver may help. The symptom of a misconfiguration is an
# INSTALL file containing a proxy error message instead of
# installation instructions.
WEB_URL=

# The directory in which the rabbitmq-website repo lives.  If empty,
# we will do a fresh clone of the 'next' branch
WEBSITE_REPO=

# The email address field to use in package changelog
# entries.  If you omit this, changelog entries won't be added.
CHANGELOG_EMAIL=packaging@rabbitmq.com

# The full name to use in package changelog # entries, if an entry is added.
CHANGELOG_FULLNAME="RabbitMQ Team"

# The comment for changelog entires
CHANGELOG_COMMENT="Test release"

# The directory on the local host to use for the build.  If not set,
# we will use a uniquely-named directory in /var/tmp.
TOPDIR=

# Which existing hg repos to copy into rabbitmq-public-umbrella, instead of
# letting it clone them.
REPOS=

# Where auxiliary scripts live
SCRIPTDIR=$(dirname $0)

# Where the rabbitmq-public-umbrella repo lives.  If not set, we assume it is
# the grandparent-directory of this script.
UMBRELLADIR=

# OTP version to build against
OTP_VERSION="R12B-5"

# OTP version for the standalone package
STANDALONE_OTP_VERSION=

# Imitate make-style variable settings as arguments
while [[ $# -gt 0 ]] ; do
  declare "$1"
  shift
done

mandatory_vars="VERSION BUILD_USERHOST"
optional_vars="SSH_OPTS KEYSDIR SIGNING_PARAMS WEB_URL WEBSITE_REPO CHANGELOG_EMAIL CHANGELOG_FULLNAME CHANGELOG_COMMENT TOPDIR topdir REPOS SCRIPTDIR UMBRELLADIR WIN_USERHOST MAC_USERHOST"

. $SCRIPTDIR/utils.sh
absolutify_scriptdir

[[ -n "$UMBRELLADIR" ]] || UMBRELLADIR=$SCRIPTDIR/..

[[ -n "$ROOT_USERHOST" ]] || ROOT_USERHOST=$(echo "$BUILD_USERHOST" | sed 's|^[^@]*@||;s|^|root@|')

[[ -z "$KEYSDIR" ]] && UNOFFICAL_RELEASE=1

# Lower-case topdir is the directory in /var/tmp where we do the build
# on the remote hosts.  TOPDIR may be different.
topdir=/var/tmp/rabbit-build.$$
[[ -z "$TOPDIR" ]] && TOPDIR="$topdir"

[[ -n "$HGREPOBASE" ]] || HGREPOBASE="ssh://hg@rabbit-hg"


check_vars

set -e -x

# Verify that we can ssh into the hosts, just in case
ssh $SSH_OPTS $BUILD_USERHOST 'true'
ssh $SSH_OPTS $ROOT_USERHOST 'true'
[ -n "$WIN_USERHOST" ] && ssh $SSH_OPTS "$WIN_USERHOST" 'true'
[ -n "$MAC_USERHOST" ] && ssh $SSH_OPTS "$MAC_USERHOST" 'true'

# Prepare the build host.  Debian etch needs some work to get it in shape
ssh $SSH_OPTS $ROOT_USERHOST '
    set -e -x
    case "$(cat /etc/debian_version)" in
    4.0*)
        echo "deb http://ftp.uk.debian.org/debian/ etch-proposed-updates main" >/etc/apt/sources.list.d/proposed-updates.list
        java_package=sun-java5-jdk
        ;;
    5.0*)
        java_package=openjdk-6-jdk
        uja_command="update-java-alternatives -s java-6-openjdk"
        echo "deb http://backports.debian.org/debian-backports lenny-backports main" > /etc/apt/sources.list.d/backports-for-mercurial-for-rabbit-build.list
        apt-get -y update
        apt-get -y -t lenny-backports install mercurial git
        ;;
    6.0*)
        java_package=openjdk-6-jdk
        uja_command="update-java-alternatives -s java-6-openjdk"
        echo "deb http://backports.debian.org/debian-backports squeeze-backports main" > /etc/apt/sources.list.d/backports-for-mercurial-for-rabbit-build.list
        apt-get -y update
        apt-get -y -t squeeze-backports install mercurial
        ;;
    *)
        echo "Not sure which JDK package to install"
        exit 1
    esac

    case `uname -m` in
    i686*)
        ARCH=i386
        ;;
    x86_64*)
        ARCH=amd64
        ;;
    *)
        echo Unrecognised architecture `uname -m`
        exit 1
    esac

    if [ "$(dpkg-query --showformat="\${Version} \${Status}\n" -W nsis)" != "2.46-2 install ok installed" ]; then
        # Pull NSIS 2.46 from squeeze
        wget http://ftp.uk.debian.org/debian/pool/main/n/nsis/nsis_2.46-2_${ARCH}.deb
        dpkg -i nsis_2.46-2_${ARCH}.deb
    fi

    DEBIAN_FRONTEND=noninteractive ; export DEBIAN_FRONTEND
    apt-get -y update
    apt-get -y dist-upgrade
    apt-get -y install ncurses-dev rsync cdbs elinks python-simplejson rpm reprepro tofrodos zip unzip ant $java_package htmldoc plotutils transfig graphviz docbook-utils texlive-fonts-recommended gs-gpl python2.5 erlang-dev erlang-nox erlang-src python-pexpect openssl s3cmd fakeroot git-core m4 xmlto mercurial xsltproc
    [ -n "$uja_command" ] && eval $uja_command
'


rm -rf $TOPDIR
mkdir -p $TOPDIR
cp -a $SCRIPTDIR/install-otp.sh $TOPDIR
cd $TOPDIR

# Copy rabbitmq-public-umbrella into place
cp -a $UMBRELLADIR/../rabbitmq-public-umbrella .

cd rabbitmq-public-umbrella
for repo in $REPOS ; do
    cp -a $repo .
done

make checkout HG_OPTS="-e 'ssh $SSH_OPTS'" HGREPOBASE="$HGREPOBASE"
make clean

if [[ -n "$CHANGELOG_EMAIL" ]] ; then
    # Tweak changelogs
    ( cd rabbitmq-server/packaging/debs/Debian/debian ; DEBFULLNAME="$CHANGELOG_FULLNAME" DEBEMAIL="$CHANGELOG_EMAIL" \
      dch -v ${VERSION}-1 --check-dirname-level 0 --distribution unstable --force-distribution "$CHANGELOG_COMMENT" )

    spec=rabbitmq-server/packaging/RPMS/Fedora/rabbitmq-server.spec
    mv $spec $spec~
    sed -ne '0,/^%changelog/p' <$spec~ >$spec
    cat >>$spec <<EOF
* $(date +'%a %b %-d %Y') ${CHANGELOG_EMAIL} ${VERSION}-1
- ${CHANGELOG_COMMENT}

EOF
    sed -ne '/^%changelog/,$p' <$spec~ | tail -n +2 >>$spec
fi

rsync -a $TOPDIR/ $BUILD_USERHOST:$topdir

# Do per-user install of the required erlang/OTP versions
ssh $SSH_OPTS $BUILD_USERHOST "$topdir/install-otp.sh $OTP_VERSION"

if [ -z "$WEB_URL" ] ; then
    # Run the website under a local python process
    if [[ -n "$WEBSITE_REPO" ]] ; then
        cd $WEBSITE_REPO
    else
        cd $TOPDIR
        hg clone -e "ssh $SSH_OPTS" -r next "$HGREPOBASE/rabbitmq-website"
        cd rabbitmq-website
    fi

    python driver.py &
    trap "kill $!" EXIT
    sleep 1
    cd $TOPDIR
    WEB_URL="http://$(hostname -f):8191/"
fi

# Do the windows build
if [ -n "$WIN_USERHOST" ] ; then
    winvars="RABBIT_VSN=$VERSION UNOFFICIAL_RELEASE=$UNOFFICIAL_RELEASE SKIP_MSIVAL2=1 WEB_URL=\"$WEB_URL\""

    dotnetdir=$topdir/rabbitmq-public-umbrella/rabbitmq-dotnet-client
    local_dotnetdir=$TOPDIR/rabbitmq-public-umbrella/rabbitmq-dotnet-client

    ssh $SSH_OPTS "$WIN_USERHOST" "mkdir -p $dotnetdir"
    rsync -a $local_dotnetdir/ "$WIN_USERHOST:$dotnetdir"

    if [ -n "$KEYSDIR" ] ; then
        rsync -a $KEYSDIR/dotnet/rabbit.snk "$WIN_USERHOST:$dotnetdir"
        winvars="$winvars KEYFILE=rabbit.snk"
    fi

    # Do the initial nant-based build
    ssh $SSH_OPTS "$WIN_USERHOST" '
        set -e -x
        cd '$dotnetdir'
        { '"$winvars"' ./dist.sh && touch dist.ok ; rm -f rabbit.snk ; } 2>&1 | tee dist.log ; test -e dist.ok
    '

    # Copy things across to the linux build host
    rsync -a "$WIN_USERHOST:$dotnetdir/" $local_dotnetdir
    rsync -a $local_dotnetdir/ $BUILD_USERHOST:$dotnetdir
    ssh $SSH_OPTS $BUILD_USERHOST '
        set -e -x
        cd '$dotnetdir'
        { make RABBIT_VSN='$VERSION' doc && touch doc.ok ; } 2>&1 | tee doc.log ; test -e doc.ok
    '

    # Now we go back to windows for the installer build
    rsync -a $BUILD_USERHOST:$dotnetdir/ $local_dotnetdir
    rsync -a $local_dotnetdir/ "$WIN_USERHOST:$dotnetdir"
    ssh $SSH_OPTS "$WIN_USERHOST" '
        set -e -x
        # The PATH when you ssh in to the cygwin sshd is missing things
        PATH="$PATH:$(cygpath -p "$SYSTEMROOT\microsoft.net\framework\v3.5;$PROGRAMFILES\msival2;$PROGRAMFILES\wix;$PROGRAMFILES\Microsoft SDKs\Windows\v6.1\Bin")"
        cd '$dotnetdir'
        { '"$winvars"' ./dist-msi.sh && touch dist-msi.ok ; } 2>&1 | tee dist-msi.log ; test -e dist-msi.ok
    '

    # The cygwin rsync sometimes hangs.  This rm works around it.
    # It's magic.
    rm -rf $local_dotnetdir/build
    rsync -a "$WIN_USERHOST:$dotnetdir/" $local_dotnetdir
    rsync -a $local_dotnetdir/ $BUILD_USERHOST:$dotnetdir
    ssh $SSH_OPTS "$WIN_USERHOST" "rm -rf $topdir"
else
    vars="SKIP_DOTNET_CLIENT=1"
fi

if [ -n "$MAC_USERHOST" ] ; then

    ## check if the mac host has the required programs for the build
    ssh $SSH_OPTS "$MAC_USERHOST" '
        for p in "rsync xmlto wget java git hg"
        do
            which $p ;
            if [ $? -ne 0 ]; then
                echo "missing build dependency $p"
                exit 1;
            fi
        done
    '

    ## copy the umbrella to the MAC_USERHOST
    ssh $SSH_OPTS "$MAC_USERHOST" "mkdir -p $topdir"
    rsync -a $TOPDIR/ $MAC_USERHOST:$topdir

    ## Do per-user install of the required erlang/OTP versions
    ssh $SSH_OPTS $MAC_USERHOST "$topdir/install-otp.sh $STANDALONE_OTP_VERSION"

    ## build the mac standalone package
    macvars="VERSION=$VERSION SKIP_EMULATOR_VERSION_CHECK=true"
    ssh $SSH_OPTS "$MAC_USERHOST" '
        set -e -x
        PATH=$HOME/otp-'"$STANDALONE_OTP_VERSION"'/bin:$PATH
        cd '$topdir'
        cd rabbitmq-public-umbrella
        { make -f release.mk rabbitmq-server-mac-standalone-packaging '"$macvars"' ; } 2>&1
    '

    # Copy everything back from the build host
    rsync -a $MAC_USERHOST:$topdir/ $TOPDIR
    ssh $SSH_OPTS $MAC_USERHOST "rm -rf $topdir"
fi

new_vars="$vars VERSION=$VERSION WEB_URL=\"$WEB_URL\" UNOFFICIAL_RELEASE=$UNOFFICIAL_RELEASE"

if [ -n "$KEYSDIR" ] ; then
    # Set things up for signing
    rsync -r $KEYSDIR/keyring/ $BUILD_USERHOST:$topdir/keyring/
    vars="$new_vars GNUPG_PATH=$topdir/keyring $SIGNING_PARAMS"
else
    vars="$new_vars"
fi

ssh $SSH_OPTS $BUILD_USERHOST '
    set -e -x
    PATH=$HOME/otp-'"$OTP_VERSION"'/bin:$PATH
    cd '$topdir'
    [ -d keyring ] && chmod -R a+rX,u+w keyring
    cd rabbitmq-public-umbrella
    { make -f release.mk dist '"$vars"' ERLANG_CLIENT_OTP_HOME=$HOME/otp-'"$OTP_VERSION"' && touch dist.ok ; rm -rf '$topdir'/keyring ; } 2>&1 | tee dist.log ; test -e dist.ok
'

# Copy everything back from the build host
rsync -a $BUILD_USERHOST:$topdir/ $TOPDIR
ssh $SSH_OPTS $BUILD_USERHOST "rm -rf $topdir"

# Sign everything
if [ -n "$KEYSDIR" ] ; then
    make -C $TOPDIR/rabbitmq-public-umbrella -f release.mk sign-artifacts GNUPG_PATH=$KEYSDIR/keyring $SIGNING_PARAMS '"$vars"'
fi

echo "Build completed successfully (don't worry about the following kill)"
