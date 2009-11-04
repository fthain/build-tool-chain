#!/bin/bash

# Linux cross tool chain build script for Mac OS X and Linux
# Copyright (c) 2004-2008 Finn Thain
# fthain@telegraphics.com.au

set -e -u

##############################################
#
# Definitions of what and where

# This is to be set to the location of the unpacked tarball / mountpoint
#DIST_ROOT=${HOME}/btc-0.11
DIST_ROOT=/Volumes/btc-0.11

# Where to find sources etc
BTC_CONFIGS=${DIST_ROOT}/configs
BTC_PATCHES=${DIST_ROOT}/patches
BTC_SOURCES=${DIST_ROOT}/sources
PROFILES=${DIST_ROOT}/profiles
SCRIPTS=${DIST_ROOT}/scripts

# Missing host tools needed for the build are to be installed here
HOST_TOOLS_PREFIX=${DIST_ROOT}/host_tools

# This is where tool chains will finally be installed
#BTC_PREFIX=/opt/btc-0.11
BTC_PREFIX=${DIST_ROOT}

# options for make
MAKE_OPTS="-j6"

# optional local cache for source tars
BTC_MIRRORS=http://192.168.64.33/~fthain/btc-sources

##############################################
#
# Below this line, angels fear to tread

LOGS_DIR=${DIST_ROOT}/logs
BTC_BUILD=${DIST_ROOT}/build

# Set vars to determine what to build
if [ "${1:-}" == "-p" -a "${2:-}" != "" ]; then
    . ${PROFILES}/${2}
elif [ "${1:-}" == "-d" ]; then
    # Clean up and stop here?
    rm -rf ${BTC_BUILD} ${LOGS_DIR}
    exit
else
    echo usage: $0 '{-d | -p <profile> {-s | -S}}'
    exit 1
fi

mkdir -p ${BTC_BUILD} ${LOGS_DIR} ${HOST_TOOLS_PREFIX}/bin

# Profile must set these
echo TARGET: $TARGET
echo TARGET_CPU: $TARGET_CPU
echo METHOD: $METHOD
echo KERNEL: $KERNEL
echo BINUTILS_DIST: $BINUTILS_DIST
echo GCC_DIST: $GCC_DIST
echo GLIBC_DIST: $GLIBC_DIST
echo THREADING_LIB: $THREADING_LIB
echo GLIBC_PORTS: $GLIBC_PORTS
echo GDB_DIST: $GDB_DIST

# Tool chain prefix
TC_PREFIX=${BTC_PREFIX}/${GCC_DIST}
mkdir -p ${TC_PREFIX}

# The filesystem must be case-sensitive.
rm -f {${BTC_BUILD},${TC_PREFIX}}/{a,A}
touch {${BTC_BUILD},${TC_PREFIX}}/{a,A}
rm -f {${BTC_BUILD},${TC_PREFIX}}/A
if [ -e ${BTC_BUILD}/a -a -e ${TC_PREFIX}/a ]; then
    rm -f {${BTC_BUILD},${TC_PREFIX}}/a
else
    echo BTC_BUILD or TC_PREFIX is case-insensitive.
    exit 1
fi

##############################################
#
# set up build environment according to profile
#
# $METHOD controls how kernel headers and binaries are made, also how gcc gets
# patched & built, since NPTL => shared gcc => early build of glibc crt
# objects. Current glibc seems to require gcc method 3, even for linuxthreads.
# Also, older tools don't support sysroot, so they need the old method.

case $METHOD in
( 1 )
    SYSROOT=
    BINUTILS_CONFIG_OPTS=
    GLIBC_PREFIX=${TC_PREFIX}/${TARGET}
    GLIBC_INSTALL_ROOT=/
    GLIBC_HEADERS=${GLIBC_PREFIX}/include
    glibc_add_ons=linuxthreads
    GLIBC_CONFIG_OPTS=
    GCC_CONFIG_OPTS="--with-local-prefix=${TC_PREFIX} \
--with-headers=${GLIBC_HEADERS}"
    GLIBC_NEEDS_SHARED_GCC=no
    ;;
( 2 )
    SYSROOT=${TC_PREFIX}/${TARGET}/sysroot
    BINUTILS_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    GLIBC_PREFIX=/usr
    GLIBC_INSTALL_ROOT=${SYSROOT}
    GLIBC_HEADERS=${SYSROOT}/usr/include
    glibc_add_ons=linuxthreads
    GLIBC_CONFIG_OPTS=
    GCC_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    GLIBC_NEEDS_SHARED_GCC=no
    ;;
( 3 )
    SYSROOT=${TC_PREFIX}/${TARGET}/sysroot
    BINUTILS_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    GLIBC_PREFIX=/usr
    GLIBC_INSTALL_ROOT=${SYSROOT}
    GLIBC_HEADERS=${SYSROOT}/usr/include
    case ${TARGET_CPU} in
    ( m68k | mips )
        glibc_add_ons=linuxthreads
        GLIBC_CONFIG_OPTS=
        ;;
    ( * )
        glibc_add_ons=nptl
        GLIBC_CONFIG_OPTS="--with-tls --enable-bind-now" # --with-__thread
        ;;
    esac
    GCC_CONFIG_OPTS="--with-sysroot=${SYSROOT} --enable-altivec"
    GLIBC_NEEDS_SHARED_GCC=yes
    ;;
esac
if [ -n "${GLIBC_PORTS}" ] ; then
    glibc_add_ons="ports,${glibc_add_ons}"
fi
GLIBC_CONFIG_OPTS="${GLIBC_CONFIG_OPTS} \
--enable-add-ons=${glibc_add_ons} \
--enable-kernel=${KERNEL#*-}"

mkdir -p ${GLIBC_HEADERS}
test -n "${SYSROOT}" && mkdir -p ${SYSROOT}

# Linux headers are installed here
KERNEL_HEADERS=${TC_PREFIX}/${TARGET}/kernel-headers
mkdir -p ${KERNEL_HEADERS}

PATH_TO_AM=$(/bin/ls -d /usr/share/automake-*/ | tail -n 1)

# The build/host tuple 
BUILD=$(${PATH_TO_AM}/config.guess)

# Sometimes useful for tricking configure into cross compiling
if [ $(${PATH_TO_AM}/config.sub $TARGET) = ${BUILD} ] ; then
    BUILD=${BUILD}x
fi

if [ ${BUILD} != ${BUILD%-apple-darwin*} ] ; then
    # Build binaries backward compatible to tiger
    export MACOSX_DEPLOYMENT_TARGET=10.4
    # Turn off Apple's pre-compiled headers
    HOST_CFLAGS='-no-cpp-precomp'
else
    # This works for Linux hosts
    HOST_CFLAGS=''
fi

export LANGUAGE=C LANG=C LC_ALL=C
export CPP="gcc -E $HOST_CFLAGS"
export CC=gcc
export PATH=${TC_PREFIX}/bin:${HOST_TOOLS_PREFIX}/bin:/bin:/sbin:/usr/bin:/usr/sbin
export MANPATH=${MANPATH:-}${MANPATH:+:}${TC_PREFIX}/man

# Stop here and start an interactive shell?
if [ "${3:-}" == "-s" ]; then
    export BTC_PREFIX HOST_TOOLS_PREFIX BTC_BUILD BTC_SOURCES BTC_PATCHES BTC_CONFIGS
    export KERNEL BUILD TARGET TARGET_CPU
    cd $BTC_BUILD
    exec bash
fi

##############################################
#
# pull in function definitions

for f in ${SCRIPTS}/*.lib; do . $f; done

##############################################
#
# install host tools

if [ ${BUILD} != ${BUILD%-apple-darwin*} ] ; then
    log install_sed       sed-4.1.5
    log install_make      make-3.81
    log install_host_tool gettext-0.16.1 ftp://ftp.gnu.org/gnu/gettext
    log install_coreutils coreutils-7.6
    log install_loadkeys  kbd-1.12
    log install_find_pl
fi
log install_host_tool gawk-3.1.5 ftp://ftp.gnu.org/gnu/gawk
log install_host_tool bison-1.28 ftp://ftp.gnu.org/gnu/bison
log install_flex      flex-2.5.4a 
case ${GCC_DIST#*-} in
( 2.* | 3.* | 4.[012].* )
    ;;
( * )
    log install_gmp gmp-4.3.1
    log install_mpfr mpfr-2.4.1
    GCC_CONFIG_OPTS=${GCC_CONFIG_OPTS}" --with-gmp=${HOST_TOOLS_PREFIX} --with-mpfr=${HOST_TOOLS_PREFIX}"
    ;;
esac
case ${GCC_DIST#*-} in
( 2.* | 3.* | 4.[0123].* )
    ;;
( * )
    log install_host_tool m4-1.4.13 ftp://ftp.gnu.org/gnu/m4
    log install_ppl ppl-0.10.2
    log install_cloog_ppl cloog-ppl-0.15.7
    GCC_CONFIG_OPTS=${GCC_CONFIG_OPTS}" --with-ppl=${HOST_TOOLS_PREFIX} --with-cloog=${HOST_TOOLS_PREFIX}"
    ;;
esac
log install_depmod depmod.pl-1_15_stable

rm -rf ${HOST_TOOLS_PREFIX}/share/{emacs,doc,aclocal}

##############################################
#
# stop here?

if [ "${3:-}" == "-S" ]; then
    export BTC_PREFIX HOST_TOOLS_PREFIX BTC_BUILD BTC_SOURCES BTC_PATCHES BTC_CONFIGS BTC_MIRRORS
    export KERNEL BUILD TARGET TARGET_CPU
    export -f fetch untar decompress prep_kernel build_kernel package_kernel
    cd $BTC_BUILD
    exec bash
fi

##############################################
#
# build and install binutils

log prep_binutils ${BINUTILS_DIST}
log build_binutils binutils-${TARGET}

# When restarting a build, you needn't remove the binutils build directory
# if it built okay. Just remove all the other build directories and the
# $TC_PREFIX directory. Then binutils will just reinstall. (This works
# because binutils has no deps in $TC_PREFIX).

log install_binutils binutils-${TARGET}

##############################################
#
# install kernel headers

log prep_kernel ${KERNEL}
log install_kernel_headers ${KERNEL}

##############################################
#
# glibc pass 1: install the headers

log prep_glibc ${GLIBC_DIST}
log install_glibc_headers glibc-${TARGET}-1

##############################################
#
# gcc-core pass 1: static compiler

log prep_gcc_core ${GCC_DIST}
log install_gcc_core_static gcc-${TARGET}-1

##############################################
#
# (omitted unless using NPTL in glibc pass 3)
# glibc pass 2: csu/subdir_lib for crt[in].o
# gcc-core pass 2: first non-static compiler;
# build and install the required libgcc_s.so and libgcc_eh.a

if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
    log make_glibc_runtime glibc-${TARGET}-2
    log install_gcc_core_shared gcc-${TARGET}-2
fi

##############################################
#
# glibc pass 3: final build
#

log install_glibc glibc-${TARGET}-3

##############################################
#
# gcc: final build and install

log prep_gcc ${GCC_DIST}
log install_gcc gcc-${TARGET}-3

##############################################
#
# gdb: build and install

log prep_gdb ${GDB_DIST}
log install_gdb gdb-${TARGET}

##############################################
#
# kernel: try out the compiler

log build_kernel ${KERNEL}

##############################################
