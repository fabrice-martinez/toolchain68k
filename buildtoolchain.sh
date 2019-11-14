#!/bin/bash
# Copyright (c) 2014-2017, A.Haarer, All rights reserved. LGPLv3

# build 68k cross toolchain based on gcc
# set the number of make jobs as appropriate for build machine
# set the path after installation : export PATH=/opt/crosschain/bin:$PATH

# tested on host platforms : msys2 64bit on windows 10, debian 8

# links:
#   http://www.mikrocontroller.net/articles/GCC_M68k
#   https://gcc.gnu.org/install/index.html
#   https://gcc.gnu.org/install/prerequisites.html
#   https://gcc.gnu.org/wiki/FAQ#configure
#   http://www.msys2.org/


# Tips:
# to speed up things:  chose a location without
# - indexing (dont use windows home dir )
# - virus scanner ( add exclusion, or stop scanner)
#
# chose a number of make jobs #number of cores + 1 to make use of all computer resources
#
# some sh versions dont like the () after functions - call the script using bash helps
#

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

LOGFILE="`pwd`/buildlog.txt"

#set the number of parallel makes
MAKEJOBS=4

#set this to the desired target architecture
#TARGETARCHITECTURE=arm-none-eabi
TARGETARCHITECTURE=m68k-elf
#TARGETARCHITECTURE=avr

#set this according to requirements: 
# "package" builds platformio compatible toolchain archives
# "install" deploys to /opt/crosschain. make sure, you are allowed to write !
DEPLOY=package
#DEPLOY=install

if [ "$DEPLOY" == "package" ]; then
    HOSTINSTALLPATH="`pwd`/toolchain-$TARGETARCHITECTURE-current"
else
    HOSTINSTALLPATH="/opt/crosschain"
fi

export CFLAGS='-O2 -fomit-frame-pointer -pipe'
export CXXFLAGS='-O2 -fomit-frame-pointer -pipe'
export LDFLAGS='-s'
export DEBUG_FLAGS=''

export CFLAGS_FOR_TARGET='-O2 -fomit-frame-pointer -ffunction-sections -fno-exceptions'
export CXXFLAGS_FOR_TARGET='-O2 -fomit-frame-pointer -ffunction-sections -fno-exceptions -fno-rtti -fno-threadsafe-statics'

if [ "$TARGETARCHITECTURE" == "m68k-elf" ]; then
    MACHINEFLAGS="--with-cpu=m68000"
    GCCFLAGS=$MACHINEFLAGS
    BINUTILSFLAGS=$MACHINEFLAGS
    LIBCFLAGS=$MACHINEFLAGS
    GDBFLAGS=$MACHINEFLAGS
fi

export PATH=$HOSTINSTALLPATH/bin:$PATH

function determine_os () {
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release 
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /usr/bin/lsb_release ]; then
        OS=`/usr/bin/lsb_release -is`
        VER=`/usr/bin/lsb_release -rs`
    elif [ -f /etc/debian_version ]; then
        OS=Debian  # XXX or Ubuntu??
        VER=$(cat /etc/debian_version)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

function log_msg () {
    local logline="`date` $1"
    echo $logline >> $LOGFILE
    echo $logline
}

# -------------------------------------------------------------------------------------------
log_msg " start of buildscript"

determine_os
log_msg " building on OS: $OS $VER for target architecture $TARGETARCHITECTURE"
if [[ $OS = MINGW* ]]; then
    EXECUTEABLESUFFIX=".exe"
    echo "ouch.. on windows"
else
    echo "not on windows"
    EXECUTEABLESUFFIX=""
fi

if [ ! -d cross-toolchain ]; then
    mkdir cross-toolchain
fi

cd cross-toolchain

M68KBUILD=`pwd`
echo "build path:" $M68KBUILD

function move_base_dir() {
    cd $M68KBUILD
}

function move_build_dir() {
    local SOURCENAME=$1
    cd $M68KBUILD/$SOURCENAME/cross-chain-$TARGETARCHITECTURE-obj
}

#todo, consider this
#fullfile="stuff.tar.gz"
#fileExt=${fullfile#*.}
#fileName=${fullfile%*.$fileExt}

function prepare_source () {
    local BASEURL=$1
    local SOURCENAME=$2
    local ARCHTYPE=$3
    
    move_base_dir

    if [ "$ARCHTYPE" = "git" ]; then
        if [ ! -f $SOURCENAME.$ARCHTYPE ]; then
            log_msg " cloning $BASEURL"
            git clone $BASEURL
        else
            log_msg " pulling update from $BASEURL"
            cd $SOURCENAME
            git pull
        fi
    else
        if [ ! -f $SOURCENAME.$ARCHTYPE ]; then
            log_msg " downloading $SOURCENAME"
            wget $BASEURL/$SOURCENAME.$ARCHTYPE
            log_msg " downloading $SOURCENAME finished"
        else
            log_msg " downloading $SOURCENAME skipped"
        fi
    fi

    if [ ! -d $SOURCENAME ]; then
        log_msg " unpacking $SOURCENAME"
        if [ "$ARCHTYPE" == "tar.bz2" ]; then
            tar -xjf $SOURCENAME.$ARCHTYPE
        elif [ "$ARCHTYPE" = "tar.gz" ]; then
            tar -xzf $SOURCENAME.$ARCHTYPE
        elif [ "$ARCHTYPE" = "tar.xz" ]; then
            tar -xJf $SOURCENAME.$ARCHTYPE
        elif [ "$ARCHTYPE" = "zip" ]; then
            unzip $SOURCENAME.$ARCHTYPE
        elif [ "$ARCHTYPE" = "git" ]; then
            echo "" #nothing to do for git
        else
            log_msg " !!!!! unknown archive format"
            exit 1
        fi
        log_msg " unpacking $SOURCENAME finished"
    else
        log_msg " unpacking $SOURCENAME skipped"
    fi
    cd $SOURCENAME

    if [ ! -d cross-chain-$TARGETARCHITECTURE-obj ]; then
        mkdir cross-chain-$TARGETARCHITECTURE-obj
    fi
    cd cross-chain-$TARGETARCHITECTURE-obj

}

#function to install package
function install_package () {
    make install
}

function conf_compile_source () {
    local SOURCEPACKAGE=$1
    local SOURCENAME=$2
    local DETECTFILE=$3
    local CONFIGURESTRING=$4

    move_build_dir $SOURCENAME

    log_msg "CCS sourcepackage= $SOURCEPACKAGE"
    log_msg "CCS detect file= $DETECTFILE"
    log_msg "CCS cfgstring $CONFIGURESTRING"

    if [ ! -f config.status ]; then
        log_msg "configuring $SOURCEPACKAGE"
        ../configure $CONFIGURESTRING || exit 1
        log_msg "configuring $SOURCEPACKAGE finished"
    else
        log_msg "configuring $SOURCEPACKAGE skipped"
    fi

    if [ ! -f $DETECTFILE ]; then

        log_msg "building $SOURCEPACKAGE"
        make -j $MAKEJOBS
        log_msg "building $SOURCEPACKAGE finished"

        log_msg "install $SOURCEPACKAGE"
        install_package
        log_msg "install $SOURCEPACKAGE finished"
    else
        log_msg "compiling and install $SOURCEPACKAGE skipped"
    fi

}

# STEP1 Fetch and uncompress all sources

#-------------------------------- BINUTILS --------------------------------------------------
# fetch binutils

log_msg ">>>> fetch binutils"
BINUTILS="binutils-2.33.1"

prepare_source http://ftp.gnu.org/gnu/binutils  $BINUTILS tar.bz2


#--------------------------------- GCC ------------------------------------------------
# fetch gcc

log_msg ">>>> fetch gcc"
GCCVER="gcc-9.2.0"

prepare_source ftp://ftp.gwdg.de/pub/misc/gcc/releases/$GCCVER $GCCVER tar.xz

if [ ! -d ../gmp ]; then
    log_msg "fetching gcc prerequisites"
    cd ..
    ./contrib/download_prerequisites
    cd cross-chain-$TARGETARCHITECTURE-obj
fi

 #--------------------------------LIBC NEWLIB -------------------------------------------------
#fetch libc for other platforms

log_msg ">>>> fetch newlib"
LIBCVER="newlib-3.1.0"

prepare_source ftp://sources.redhat.com/pub/newlib $LIBCVER tar.gz

log_msg "patching newlib to automatically determine _LDBL_EQ_DBL"
tmpdir=`pwd`
cd ..
echo `pwd`
patch  -p1 -i $SCRIPT_DIR/newlib.patch
cd $tmpdir

#---------------------------------GDB---------------------------------------------
#fetch gdb
#sudo apt-get install ncurses-dev
GDBVER="gdb-8.3.1"

log_msg ">>>> fetch gdb"
prepare_source http://ftp.gnu.org/gnu/gdb $GDBVER tar.xz

log_msg "patching gdb"
tmpdir=`pwd`
cd ..
patch  -p0 -i $SCRIPT_DIR/gdb_python.patch
patch  -p0 -i $SCRIPT_DIR/gdb_libssp.patch
cd $tmpdir

# STEP2 Build everything
    
NEWLIB_INCLUDES="$M68KBUILD/$LIBCVER/newlib/libc/include"

#-------------------------------- BINUTILS --------------------------------------------------
# build binutils
log_msg ">>>> build binutils"

BINUTILSFLAGS+=" --target=$TARGETARCHITECTURE --prefix=$HOSTINSTALLPATH/ --with-headers=$NEWLIB_INCLUDES" 
conf_compile_source binutils $BINUTILS "$HOSTINSTALLPATH/bin/$TARGETARCHITECTURE-objcopy$EXECUTEABLESUFFIX" "$BINUTILSFLAGS"

#--------------------------------- GCC ------------------------------------------------
# build gcc
log_msg ">>>> build gcc"

GCCFLAGS+=" --target=$TARGETARCHITECTURE --prefix=$HOSTINSTALLPATH/ --enable-languages=c,c++ --disable-bootstrap --with-newlib --disable-libmudflap --enable-lto --disable-libssp --disable-libgomp --disable-libstdcxx-pch --disable-threads --with-gnu-as --with-gnu-ld --disable-nls --with-headers=yes --disable-checking --without-headers --disable-libstdcxx-threads --disable-multilib --with-headers=$NEWLIB_INCLUDES"

conf_compile_source gcc $GCCVER "$HOSTINSTALLPATH/bin/$TARGETARCHITECTURE-gcov$EXECUTEABLESUFFIX" "$GCCFLAGS"

# Put the cross compiler in the path
export PATH=$PATH:$HOSTINSTALLPATH/bin/

#--------------------------------LIBC NEWLIB -------------------------------------------------
#build libc for other platforms
log_msg ">>>> build newlib"

LIBCFLAGS+=" --target=$TARGETARCHITECTURE --prefix=$HOSTINSTALLPATH/ --disable-multilib --enable-newlib-nano-formatted-io --enable-newlib-reent-small --disable-malloc-debugging --enable-newlib-multithread --disable-newlib-io-float --disable-newlib-supplied-syscalls --disable-newlib-io-c99-formats --disable-newlib-mb --disable-newlib-atexit-alloc --enable-target-optspace --disable-shared --enable-static --enable-fast-install --enable-languages=c,c++ --with-headers=$NEWLIB_INCLUDES"

conf_compile_source newlib $LIBCVER "$HOSTINSTALLPATH/$TARGETARCHITECTURE/lib/libc.a" "$LIBCFLAGS"


#---------------------------------GDB---------------------------------------------
#build gdb
log_msg ">>>> build gdb"

GDBFLAGS+=" --target=$TARGETARCHITECTURE --prefix=$HOSTINSTALLPATH/ --with-headers=$NEWLIB_INCLUDES"

conf_compile_source gdb $GDBVER "$HOSTINSTALLPATH/bin/$TARGETARCHITECTURE-gdb$EXECUTEABLESUFFIX" "$GDBFLAGS"

cd $M68KBUILD

#---------------------------------------------------------------------------------
#build pio package if required
if [ "$DEPLOY" == "package" ]; then

#works only in bash
PACKAGEVER=${GCCVER/#gcc-}

if [[ $OS = MINGW* ]]; then EXECUTEABLESUFFIX=".exe" echo "on windows, copy mingw dlls"
for DLLFILE in libgmp-10.dll libiconv-2.dll libintl-8.dll libwinpthread-1.dll libexpat-1.dll
do
    cp  /mingw64/bin/$DLLFILE $HOSTINSTALLPATH/bin
done
cat >$HOSTINSTALLPATH/package.json <<EOFWINDOWSVARIANT
{
    "description": "$GCCVER $BINUTILS $LIBCVER $GDBVER",
    "name": "toolchain-$TARGETARCHITECTURE-current",
    "system": [
        "windows",
        "windows_amd64",
        "windows_x86"
    ],
    "url": "https://github.com/haarer/toolchain68k",
    "version": "$PACKAGEVER"
}
EOFWINDOWSVARIANT

else
cat >$HOSTINSTALLPATH/package.json <<EOFLINUXVARIANT
{
    "description": "$GCCVER $BINUTILS $LIBCVER $GDBVER",
    "name": "toolchain-$TARGETARCHITECTURE-current",
    "system": [
        "linux_x86_64"
    ],
    "url": "https://github.com/haarer/toolchain68k",
    "version": "$PACKAGEVER"
}
EOFLINUXVARIANT

fi

cd $HOSTINSTALLPATH ;tar cvzf ../toolchain-$TARGETARCHITECTURE-$OS-$GCCVER.tar.gz * ; cd ..
sha1sum toolchain-$TARGETARCHITECTURE-$OS-$GCCVER.tar.gz

fi
#if deploy
