#!/bin/bash

set -e
set -x

rabbitHg="http://hg.rabbitmq.com/"
tonygGithub="git://github.com/tonyg/"

sourceArchivedir="`pwd`/_repo/sources"
binaryArchivedir="`pwd`/_repo/binaries"
debianRepodir="`pwd`/_repo/debian"

function fetchHg {
    module="$1"; shift
    set +e
    baseurl="$1"; shift
    directory="$1"; shift
    set -e
    if [ -z "$baseurl" ]; then baseurl="$rabbitHg"; fi
    if [ -z "$directory" ]; then directory="$module"; fi

    if [ -d "$directory" ]
    then (
	    cd $directory
	    hg pull && hg up -C default
    ) else (
	    hg clone "$baseurl$module" "$directory"
    ) fi
}

function fetchGit {
    module="$1"; shift
    set +e
    baseurl="$1"; shift
    directory="$1"; shift
    set -e
    if [ -z "$baseurl" ]; then baseurl="$tonygGithub"; fi
    if [ -z "$directory" ]; then directory="$module"; fi

    if [ -d "$directory" ]
    then (
	    cd $directory
	    git pull
    ) else (
	    git clone "$baseurl$module.git" "$directory"
    ) fi
}

function hgVersion {
    directory="$1"
    (
	cd $directory
	hgid="`hg id -i`"
	hg log -r "$hgid" --template '{date|isodate}+hgr'"$hgid" | \
	    tr -d '-' | tr ': ' '..' | sed -e 's:\.+[0-9]\+::'
    )
}

function gitVersion {
    directory="$1"
    (
	cd $directory
	git log -1 --pretty='format:%ai+gitr%h' HEAD | \
	    tr -d '-' | tr ': ' '..' | sed -e 's:\.[0-9][0-9]\.+[0-9]\+::'
    )
}

function genChangelogEntry {
    packagename="$1"; shift
    version="$1"; shift
    changelogfile="$1"; shift
    echo "${packagename} (${version}-1) unstable; urgency=low" > $changelogfile.tmp
    echo >> $changelogfile.tmp
    echo "  * Unofficial release"  >> $changelogfile.tmp
    echo >> $changelogfile.tmp
    echo " -- Autobuild <autobuild@example.com>  $(date -R)" >> $changelogfile.tmp
    echo >> $changelogfile.tmp
    cat $changelogfile >> $changelogfile.tmp
    mv -f $changelogfile.tmp $changelogfile
}

function clean {
    if [ -f "$1/Makefile" ]
    then
	make -C "$1" distclean
    fi
}

function pre_build {
    post_build
    mkdir -p _build
    builddir="`pwd`/_build"
}

function post_build {
    if [ -d _build ]
    then
	chmod -R +w _build
	rm -rf _build
    fi
}

function startDebianRepository {
    mkdir -p $sourceArchivedir
    mkdir -p $binaryArchivedir
}

function finishDebianRepository {
    rm -rf $debianRepodir
    mkdir -p $debianRepodir
    (
	cd $debianRepodir
	mkdir -p conf
	cat > conf/distributions <<EOF
Origin: RabbitMQ
Label: Autobuild RabbitMQ Repository for Debian / Ubuntu etc
Suite: testing
Codename: kitten
Architectures: arm hppa ia64 mips mipsel s390 sparc i386 amd64 powerpc source
Components: main
Description: Autobuild RabbitMQ Repository for Debian / Ubuntu etc
EOF
	for file in $binaryArchivedir/*.changes
	do
	    reprepro --ignore=wrongdistribution -V include kitten ${file}
	done
	reprepro -V createsymlinks
    )
}

function build_server {
    v="`hgVersion rabbitmq-server`"
    if [ ! -f $binaryArchivedir/rabbitmq-server_$v.orig.tar.gz ]
    then
	pre_build
	make -C rabbitmq-server VERSION=$v srcdist
	cp rabbitmq-server/dist/rabbitmq-server-$v.* $sourceArchivedir
	(
	    cd rabbitmq-server/packaging/debs/Debian
	    make UNOFFICIAL_RELEASE=1 TARBALL=rabbitmq-server-$v.tar.gz clean package
	    mv rabbitmq-server_$v* $binaryArchivedir
	)
    fi
}

function build_c {
    v="`hgVersion rabbitmq-c`"
    if [ ! -f $binaryArchivedir/librabbitmq_$v-1.tar.gz ]
    then
	pre_build
	if [ -f rabbitmq-c/Makefile ]
	then 
	    make -C rabbitmq-c squeakyclean
	fi
	if [ ! -f rabbitmq-c/configure ]
	then (
		cd rabbitmq-c
		autoreconf -i
	) fi
	srcdir="`pwd`/rabbitmq-c"
	(
	    cd $builddir
	    $srcdir/configure --prefix=$builddir/_install
	    make VERSION=$v distcheck
	    cp librabbitmq-$v.tar.gz $sourceArchivedir
	)

	pre_build
	(
	    cd $builddir
	    tar -zxvf $sourceArchivedir/librabbitmq-$v.tar.gz
	    cd librabbitmq-$v
	    genChangelogEntry librabbitmq $v debian/changelog
	    set +e
	    dpkg-buildpackage -rfakeroot
	    set -e
	    cd ..
	    rm -rf librabbitmq-$v
	    mv * $binaryArchivedir
	)
    fi
}

function build_xmpp {
    v="`hgVersion rabbitmq-xmpp`"
    if [ ! -f $binaryArchivedir/rabbitmq-xmpp_$v-1.tar.gz ]
    then
	pre_build
	hg clone rabbitmq-xmpp $builddir/rabbitmq-xmpp-$v
	(
	    cd $builddir/rabbitmq-xmpp-$v
	    make all
	    genChangelogEntry rabbitmq-xmpp $v debian/changelog
	    set +e
	    dpkg-buildpackage -rfakeroot
	    set -e
	    cd ..
	    rm -rf rabbitmq-xmpp-$v
	    mv * $binaryArchivedir
	)
    fi
}

function build_java {
    v="`hgVersion rabbitmq-java-client`"
    if [ ! -f $sourceArchivedir/rabbitmq-java-client-$v.tar.gz ]
    then
	pre_build
	make -C rabbitmq-java-client VERSION=$v srcdist
	cp rabbitmq-java-client/build/rabbitmq-java-client-$v.tar.gz $sourceArchivedir
	(
	    cd $builddir
	    tar -zxf $sourceArchivedir/rabbitmq-java-client-$v.tar.gz
	    cd rabbitmq-java-client-$v
	    make VERSION=$v dist_all
	    mv build/rabbitmq-java-client-*-$v.* $binaryArchivedir
	    cd ..
	    rm -rf rabbitmq-java-client-$v
	)
    fi
}

function build_rabbithub {
    v="`gitVersion rabbithub`"
    if [ ! -f $binaryArchivedir/rabbithub_$v-1.tar.gz ]
    then
	pre_build
	git clone rabbithub $builddir/rabbithub-$v
	(
	    cd $builddir/rabbithub-$v
	    make all
	    genChangelogEntry rabbithub $v debian/changelog
	    set +e
	    dpkg-buildpackage -rfakeroot
	    set -e
	    cd ..
	    rm -rf rabbithub-$v
	    mv * $binaryArchivedir
	)
    fi
}

function wipe_all {
    rm -rf rabbitmq-codegen
    rm -rf rabbitmq-server
    rm -rf rabbitmq-c
    rm -rf rabbitmq-xmpp
    rm -rf rabbitmq-java-client
    rm -rf rabbithub
}

function fetch_all {
    fetchHg rabbitmq-codegen
    fetchHg rabbitmq-server
    fetchHg rabbitmq-c
    fetchHg rabbitmq-xmpp
    fetchHg rabbitmq-java-client
    fetchGit rabbithub
}

function clean_all {
    clean rabbitmq-codegen
    clean rabbitmq-server
    clean rabbitmq-c
    clean rabbitmq-xmpp
    clean rabbitmq-java-client
    clean rabbithub
}

function build_all {
    startDebianRepository
    build_server
    build_c
    build_xmpp
    build_java
    build_rabbithub
    finishDebianRepository
    post_build
}
