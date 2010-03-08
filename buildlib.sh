#!/bin/bash

set -e
set -x

rabbitHg="http://hg.rabbitmq.com/"
lshiftOpenSourceHg="http://hg.opensource.lshift.net/"
tonygGithub="git://github.com/tonyg/"

sourceArchivedir="`pwd`/_repo/sources"
binaryArchivedir="`pwd`/_repo/binaries"
ezArchivedir="`pwd`/_repo/ez"
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

function packageVersion {
    directory="$1"
    if [ -d "$directory/.hg" ]
    then
	hgVersion $directory
    elif [ -d "$directory/.git" ]
    then
	gitVersion $directory
    else
	echo "Couldn't figure out how to determine package version for $directory."
	false
    fi
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

function packageDirClone {
    directory="$1"; shift
    target="$1"; shift
    if [ -d "$directory/.hg" ]
    then
	hg clone $directory $target
    elif [ -d "$directory/.git" ]
    then
	git clone $directory $target
    else
	echo "Couldn't figure out how to clone $directory."
	false
    fi
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

function buildDeb {
    dpkg-buildpackage -rfakeroot -us -uc
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

function build_erlang_rfc4627 {
    pre_build
    buildGenericSimpleHgDebian erlang-rfc4627 rfc4627-erlang
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

function untar_server_source {
    serverVersion="`hgVersion rabbitmq-server`"
    serverSourceTarball="$sourceArchivedir/rabbitmq-server-$serverVersion.tar.gz"
    [ -f "$serverSourceTarball" ]

    (
	cd $builddir
	tar -zxf $serverSourceTarball
	mv rabbitmq-server-$serverVersion rabbitmq-server
    )
}

function build_erlang_client {
    pre_build
    untar_server_source

    p="rabbitmq-erlang-client"
    v="`packageVersion ${p}`"
    if [ ! -f $ezArchivedir/${p}/amqp_client-${v}.ez ]
    then
        srcdir=$builddir/${p}-${v}
	hg clone ${p} ${srcdir}
	(
	    cd ${srcdir}
	    make
	    mkdir -p $ezArchivedir/${p}
	    cp dist/amqp_client.ez $ezArchivedir/${p}/amqp_client-${v}.ez
	    cp dist/rabbit_common.ez $ezArchivedir/${p}/rabbit_common-${v}.ez
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
	    buildDeb
	    cd ..
	    rm -rf librabbitmq-$v
	    mv * $binaryArchivedir
	)
    fi
}

function buildGenericSimpleHgDebian {
    p="$1"; shift
    set +e
    dp="$1"; shift
    set -e
    if [ -z "$dp" ]; then dp="$p"; fi
    v="`hgVersion ${p}`"
    if [ ! -f $binaryArchivedir/${dp}_${v}-1.tar.gz ]
    then
	hg clone ${p} $builddir/${dp}-${v}
	(
	    cd $builddir/${dp}-${v}
	    genChangelogEntry ${dp} ${v} debian/changelog
	    buildDeb
	    if [ -d dist ]; then (
		    cd dist
		    for ez in *.ez
		    do
			mkdir -p $ezArchivedir/${p}
			cp ${ez} $ezArchivedir/${p}/`basename ${ez} .ez`-${v}.ez
		    done
	    ) fi
	    cd ..
	    rm -rf ${dp}-${v}
	    mv ${dp}* $binaryArchivedir
	)
    fi
}

function buildEz {
    p="$1"; shift
    ezname=$(cd ${p}; make echo-package-name)
    deps=$(grep '^DEPS *=' ${p}/Makefile | sed -e 's:^[^=]*=::')
    v="`packageVersion ${p}`"
    if [ ! -f $ezArchivedir/${p}/${ezname}-${v}.ez ]
    then
	pre_build

	cp include.mk $builddir
        srcdir=$builddir/${p}-${v}
	packageDirClone ${p} ${srcdir}
	for dep in ${deps}
	do
	    mkdir -p $builddir/${dep}/dist
	    # Gross-o special casing of the .ez files produced
	    # by the erlang client: both a real client, and the common lib
	    if [ ${dep} = rabbitmq-server ]; then
		cpLatestEz $builddir/${dep}/dist rabbitmq-erlang-client rabbit_common
	    elif [ ${dep} = rabbitmq-erlang-client ]; then
		cpLatestEz $builddir/${dep}/dist rabbitmq-erlang-client amqp_client
	    else
		cpLatestEz $builddir/${dep}/dist ${dep}
	    fi
	done
	(
	    cd ${srcdir}
	    make
	    cd dist
	    mkdir -p $ezArchivedir/${p}
	    cp ${ezname}.ez $ezArchivedir/${p}/${ezname}-${v}.ez
	)
    fi
}

function cpLatestEz {(
    targetdir="$1"; shift
    p="$1"; shift
    set +e
    ezname="$1"; shift
    set -e
    if [ -z ${ezname} ]
    then
	ezname=$(cd ${p}; make echo-package-name)
    fi
    cp $(ls $ezArchivedir/${p}/${ezname}-*.ez | tail -1) ${targetdir}/${ezname}.ez
)}

function build_xmpp {
    pre_build
    buildGenericSimpleHgDebian rabbitmq-xmpp
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
	    buildDeb
	    cd ..
	    rm -rf rabbithub-$v
	    mv * $binaryArchivedir
	)
    fi
}

function build_rabbit_mochiweb {
    buildEz rabbitmq-mochiweb
    (
	# Uses variables p, v etc set by buildEz above. Icky shell scoping.
	cd $builddir/${p}-${v}
	svnrev=$(cd deps/mochiweb; make echo-revision)
	cp dist/mochiweb.ez $ezArchivedir/${p}/mochiweb-svnr${svnrev}.ez
    )
}

function wipe_all {
    rm -rf erlang-rfc4627
    rm -rf rabbitmq-codegen
    rm -rf rabbitmq-server
    rm -rf rabbitmq-erlang-client
    rm -rf rabbitmq-c
    rm -rf rabbitmq-xmpp
    rm -rf rabbitmq-stomp
    rm -rf rabbitmq-java-client
    rm -rf rabbithub
    rm -rf script-exchange
    rm -rf rabbitmq-mochiweb
    rm -rf rabbitmq-jsonrpc
    rm -rf rabbitmq-jsonrpc-channel
}

function fetch_all {
    fetchHg erlang-rfc4627 $lshiftOpenSourceHg
    fetchHg rabbitmq-codegen
    fetchHg rabbitmq-server
    fetchHg rabbitmq-erlang-client
    fetchHg rabbitmq-c
    fetchHg rabbitmq-xmpp
    fetchHg rabbitmq-stomp
    fetchHg rabbitmq-java-client
    fetchGit rabbithub
    fetchGit script-exchange
    fetchHg rabbitmq-mochiweb
    fetchHg rabbitmq-jsonrpc
    fetchHg rabbitmq-jsonrpc-channel
}

function clean_all {
    clean erlang-rfc4627
    clean rabbitmq-codegen
    clean rabbitmq-server
    make -C rabbitmq-erlang-client clean
    clean rabbitmq-c
    clean rabbitmq-xmpp
    clean rabbitmq-stomp
    clean rabbitmq-java-client
    clean rabbithub
    clean script-exchange
    clean rabbitmq-mochiweb
    clean rabbitmq-jsonrpc
    clean rabbitmq-jsonrpc-channel
}

function build_all {
    startDebianRepository
    build_erlang_rfc4627
    build_server
    build_erlang_client
    build_c
    build_xmpp
    buildEz rabbitmq-stomp
    build_java
    build_rabbithub
    buildEz script-exchange
    build_rabbit_mochiweb
    buildEz rabbitmq-jsonrpc
    buildEz rabbitmq-jsonrpc-channel
    finishDebianRepository
    rm -rf $ezTmpdir
    post_build
}
