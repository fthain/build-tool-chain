#!/bin/bash

# Linux cross tool chain build script for Mac OS X and Linux
# Copyright (c) 2004-2007 Finn Thain
# fthain@telegraphics.com.au

set -e -u

##############################################
#
# Definitions of what and where

# This is to be set to the location of the unpacked tarball / mountpoint
#DIST_ROOT=${HOME}/btc-0.11
DIST_ROOT=/Volumes/btc-0.11

# Where to find sources etc
CONFIGS=${DIST_ROOT}/configs
PATCHES=${DIST_ROOT}/patches
PROFILES=${DIST_ROOT}/profiles
SOURCES=${DIST_ROOT}/sources
SCRIPTS=${DIST_ROOT}/scripts

# Missing host tools needed for the build are to be installed here
HOST_TOOLS_PREFIX=${DIST_ROOT}/host_tools

# This is where tool chains will finally be installed
#BTC_PREFIX=/opt/btc-0.11
BTC_PREFIX=${DIST_ROOT}

##############################################
#
# Below this line, angels fear to tread

LOGS_DIR=${DIST_ROOT}/logs
BUILD_DIR=${DIST_ROOT}/build

# Set vars to determine what to build
if [ "${1:-}" == "-p" -a "${2:-}" != "" ]; then
    . ${PROFILES}/${2}
elif [ "${1:-}" == "-d" ]; then
    # Clean up and stop here?
    rm -rf ${BUILD_DIR} ${LOGS_DIR}
    exit
else
    echo usage: $0 '{-d | -p <profile> {-s | -S}}'
    exit 1
fi

mkdir -p ${BUILD_DIR} ${LOGS_DIR} ${HOST_TOOLS_PREFIX}/bin

# Profile must set these
echo TARGET: $TARGET
echo TARGET_CPU: $TARGET_CPU
echo METHOD: $METHOD
echo KERNEL: $KERNEL
echo BINUTILS_DIST: $BINUTILS_DIST
echo GCC_DIST: $GCC_DIST
echo GCC_CORE_DIST: $GCC_CORE_DIST
echo GLIBC_DIST: $GLIBC_DIST
echo THREADING_LIB: $THREADING_LIB
echo GDB_DIST: $GDB_DIST

# Tool chain prefix
TC_PREFIX=${BTC_PREFIX}/${GCC_DIST}
mkdir -p ${TC_PREFIX}

# The filesystem must be case-sensitive.
rm -f {${BUILD_DIR},${TC_PREFIX}}/{a,A}
touch {${BUILD_DIR},${TC_PREFIX}}/{a,A}
rm -f {${BUILD_DIR},${TC_PREFIX}}/A
if [ -e ${BUILD_DIR}/a -a -e ${TC_PREFIX}/a ]; then
    rm -f {${BUILD_DIR},${TC_PREFIX}}/a
else
    echo BUILD_DIR or TC_PREFIX is case-insensitive.
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
    GLIBC_CONFIG_OPTS=--enable-add-ons=linuxthreads
    GLIBC_PREFIX=${TC_PREFIX}/${TARGET}
    GLIBC_INSTALL_ROOT=/
    GLIBC_HEADERS=${GLIBC_PREFIX}/include
    GCC_CONFIG_OPTS="--with-local-prefix=${TC_PREFIX} \
--with-headers=${GLIBC_HEADERS}"
    GLIBC_NEEDS_SHARED_GCC=no
    ;;
( 2 )
    SYSROOT=${TC_PREFIX}/${TARGET}/sysroot
    BINUTILS_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    GLIBC_CONFIG_OPTS=--enable-add-ons=linuxthreads
    GLIBC_PREFIX=/usr
    GLIBC_INSTALL_ROOT=${SYSROOT}
    GLIBC_HEADERS=${SYSROOT}/usr/include
    GCC_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    GLIBC_NEEDS_SHARED_GCC=no
    ;;
( 3 )
    SYSROOT=${TC_PREFIX}/${TARGET}/sysroot
    BINUTILS_CONFIG_OPTS=--with-sysroot=${SYSROOT}
    case ${TARGET_CPU} in
    ( m68k | mips )
        GLIBC_CONFIG_OPTS=--enable-add-ons=linuxthreads
        ;;
    ( * )
        GLIBC_CONFIG_OPTS="--enable-add-ons=nptl \
--with-tls \
--enable-bind-now"
# --with-__thread
                ;;
    esac
    GLIBC_PREFIX=/usr
    GLIBC_INSTALL_ROOT=${SYSROOT}
    GLIBC_HEADERS=${SYSROOT}/usr/include
    GCC_CONFIG_OPTS="--with-sysroot=${SYSROOT} --enable-altivec"
    GLIBC_NEEDS_SHARED_GCC=yes
    ;;
esac
GLIBC_CONFIG_OPTS="${GLIBC_CONFIG_OPTS} --enable-kernel=${KERNEL#*-}"

mkdir -p ${GLIBC_HEADERS}
test -n "${SYSROOT}" && mkdir -p ${SYSROOT}

# Linux headers are installed here
KERNEL_HEADERS=${TC_PREFIX}/${TARGET}/kernel-headers
mkdir -p ${KERNEL_HEADERS}

# The build/host tuple 
BUILD=$(/usr/share/libtool/config.guess)

# Sometimes useful for tricking configure into cross compiling
if [ $(/usr/share/libtool/config.sub $TARGET) = ${BUILD} ] ; then
    BUILD=${BUILD}x
fi

if [ ${BUILD} != ${BUILD/%-apple-darwin*} ] ; then
    # Let the result be backward compatible only with Tiger
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

# Stop here and start an interactive shell?
if [ "${3:-}" == "-s" ]; then
    export BTC_PREFIX HOST_TOOLS_PREFIX BUILD_DIR SOURCES PATCHES CONFIGS
    export KERNEL BUILD TARGET TARGET_CPU TC_PREFIX
    cd $BUILD_DIR
    exec bash
fi

##############################################
#
# pull in function definitions

for f in ${SCRIPTS}/*.lib; do . $f; done

##############################################
#
# install host tools

if [ ${BUILD} != ${BUILD/%-apple-darwin*} ] ; then
    log install_sed       sed-4.1.5
    log install_make      make-3.81
    log install_host_tool gettext-0.16.1
    log install_host_tool gawk-3.1.5
    log install_host_tool bison-1.28
    log install_coreutils coreutils-6.9
    log install_loadkeys  kbd-1.12
else
    log install_host_tool gawk-3.1.5
    log install_host_tool bison-1.28
    log install_flex      flex-2.5.4a
fi
log install_depmod depmod.pl-19079

rm -rf ${HOST_TOOLS_PREFIX}/share/{emacs,doc,aclocal}

##############################################
#
# stop here?

if [ "${3:-}" == "-S" ]; then
    export BTC_PREFIX HOST_TOOLS_PREFIX BUILD_DIR SOURCES PATCHES CONFIGS
    export KERNEL BUILD TARGET TARGET_CPU TC_PREFIX
    export -f decompress untar prep_kernel build_kernel package_kernel
    cd $BUILD_DIR
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

log prep_gcc_core ${GCC_CORE_DIST}
log install_gcc_core_static gcc-core-${TARGET}-1

##############################################
#
# (omitted unless using NPTL in glibc pass 3)
# glibc pass 2: csu/subdir_lib for crt[in].o
# gcc-core pass 2: first non-static compiler;
# build and install the required libgcc_s.so and libgcc_eh.a

if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
    log make_glibc_runtime glibc-${TARGET}-2
    log install_gcc_core_shared gcc-core-${TARGET}-2
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
log install_gcc gcc-${TARGET}

##############################################
#
# gdb: build and install

log prep_gdb ${GDB_DIST}
log install_gdb gdb-${TARGET}

##############################################
#
# kernel: test out the compiler

log build_kernel ${KERNEL}

##############################################
