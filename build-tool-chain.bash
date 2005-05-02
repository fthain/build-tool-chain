#!/bin/bash

# Linux cross tool chain build script for Mac OS X Panther and Linux (gcc 3.3)
# Copyright (c) 2004, 2005 Finn Thain
# fthain@telegraphics.com.au

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

##############################################

# Exit on simple command failure
set -e -u

# This is to be set to the location of the unpacked btc tarball
DIST_ROOT=${HOME}/Desktop/btc-0.9
#DIST_ROOT=/Volumes/Linux/btc

# Where to find sources etc
SOURCES=${DIST_ROOT}/sources
PATCHES=${DIST_ROOT}/patches
CONFIGS=${DIST_ROOT}/configs

# Missing host tools needed for the build will be installed here
HOST_TOOLS_PREFIX=${DIST_ROOT}/hosttools

# This is where tool chains will finally be installed
BTC_PREFIX=/opt/btc-0.9
#BTC_PREFIX=${DIST_ROOT}/xcompiler

# The build/host tuple 
BUILD=${BUILD:-powerpc-apple-darwin}
#BUILD=${BUILD:-i686-pc-linux-gnu}

# The target tuple
#TARGET=${TARGET:-m68k-unknown-linux-gnu}
TARGET=${TARGET:-m68k-linux}
TARGET_CPU=${TARGET_CPU:-m68k}
#TARGET=alpha-unknown-linux-gnu
#TARGET_CPU=alpha
#TARGET=powerpc-unknown-linux-gnu
#TARGET_CPU=ppc
#TARGET=i686-pc-linux-gnu
#TARGET_CPU=i386

# $METHOD controls how kernel headers and binaries are made, also how gcc gets
# patched & built, since NPTL => shared gcc => early build of glibc crt objects.
# Current glibc seems to require gcc method 3, even for linuxthreads.
# Also, older tools don't have support for sysroot, so they need the old method.
METHOD=${METHOD:-3}

# Packages to be built
GDB_DIST=gdb-6.1.1

case ${METHOD} in
    ( 1 ) # This mode is suitable for gcc 3.1 and older
        BINUTILS_DIST=binutils-2.12.90.0.1
        KERNEL=linux-2.2.26
        GCC_DIST=gcc-2.95.3
        GCC_CORE_DIST=gcc-core-2.95.3
        GLIBC_DIST=glibc-2.2.5
        THREADING_LIB=glibc-linuxthreads-2.2.5
        ;;
    ( 2 ) # Suitable for gcc 3.2 and newer, glibc <= 2.3.3 and linuxthreads
        BINUTILS_DIST=binutils-2.15.94.0.2.2
#        KERNEL=linux-2.4.30
        KERNEL=linux-2.4.28
        GCC_DIST=gcc-3.3.5
        GCC_CORE_DIST=gcc-core-3.3.5
        GLIBC_DIST=glibc-2.3.3
        THREADING_LIB=
        ;;
    ( 3 ) # Allows glibc > 2.3.3, NPTL (given TLS support) or linuxthreads
        BINUTILS_DIST=binutils-2.15.94.0.2.2
#        KERNEL=linux-2.6.11
        KERNEL=linux-2.6.10
        GCC_DIST=gcc-3.4.3
        GCC_CORE_DIST=gcc-core-3.4.3
        GLIBC_DIST=glibc-2.3.5
        THREADING_LIB=glibc-linuxthreads-2.3.5
        ;;
esac

##############################################
#
# Below this line, angels fear to tread

# Tool chain prefix
TC_PREFIX=${BTC_PREFIX}/${GCC_DIST}-${BINUTILS_DIST}-${GLIBC_DIST}

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
            ( m68k )
                GLIBC_CONFIG_OPTS=--enable-add-ons=linuxthreads
                ;;
            ( * )
                GLIBC_CONFIG_OPTS="--enable-add-ons=nptl \
--with-tls \
--cache-file=config.cache"
                ;;
        esac
        GLIBC_PREFIX=/usr
        GLIBC_INSTALL_ROOT=${SYSROOT}
        GLIBC_HEADERS=${SYSROOT}/usr/include
        GCC_CONFIG_OPTS="--with-sysroot=${SYSROOT} --enable-altivec"
        GLIBC_NEEDS_SHARED_GCC=yes
        ;;
esac
GLIBC_CONFIG_OPTS=${GLIBC_CONFIG_OPTS}" --enable-kernel=${KERNEL#*-}"

mkdir -p ${HOST_TOOLS_PREFIX}/bin
mkdir -p ${GLIBC_HEADERS}
test -n "${SYSROOT}" && mkdir -p ${SYSROOT}

# Linux headers are installed here
KERNEL_HEADERS=${TC_PREFIX}/${TARGET}/kernel-headers
mkdir -p ${KERNEL_HEADERS}

# Necessary to trick configure into cross compiling
if [ $TARGET = $BUILD ] ; then
    BUILD=${BUILD}x
fi

if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
    # Turn off Apple's pre-compiled headers
    HOST_CFLAGS=-no-cpp-precomp 
else
    # This works for Linux hosts
    HOST_CFLAGS=''
fi

export CPP="gcc -E $HOST_CFLAGS"
export CC=gcc
export PATH=${TC_PREFIX}/bin:${HOST_TOOLS_PREFIX}/bin:/bin:/sbin:/usr/bin:/usr/sbin
export LANGUAGE=C LANG=C LC_ALL=C

# Where to unpack and build. Used as a mount point for a UFS on Mac OS X.
BUILD_DIR=${DIST_ROOT}/build

if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
    cd ${DIST_ROOT}
    if [ -e build.sparseimage ]; then
        if [ -d ${BUILD_DIR} ]; then
            echo build.sparseimage already exists, and seems to be mounted.
        else
            echo build.sparseimage already exists: attempting to mount it.
            hdiutil attach -mount required -mountroot ${DIST_ROOT} build.sparseimage
        fi
    else
        hdiutil create -ov -size 1500M -type SPARSE -fs HFSX \
                       -volname build -partitionType Apple_HFS build
        hdiutil attach -mount required -mountroot ${DIST_ROOT} build.sparseimage
    fi
else
    mkdir -p ${BUILD_DIR}
fi

if [ x"$@" == "x-s" ]; then
    export BTC_PREFIX BUILD_DIR SOURCES PATCHES CONFIGS KERNEL TARGET TARGET_CPU TC_PREFIX
    cd $BUILD_DIR
    exec bash # to get a shell with the environment set
fi

##############################################
#
# This function decompresses to stdout the file given by the first argument.

function decompress () {
    local f
    for f in $1*; do
        case $f in
            ( $1.bz2 | $1.tbz | $1.tar.bz2 )
                bzip2 -dc $f
                return ;;
            ( $1.gz | $1.tgz | $1.tar.gz )
                gzip -dc $f
                return ;;
            ( $1 | $1.tar )
                cat $f
                return ;;
        esac
    done
    echo "uncompress: can't find $1" 1>&2
    echo "uncompress: can't find $1"
}

##############################################
#
# Test for pre-requisites (and install them if need be)
#
# awk, sed, make, gettext (and autoconf-2.13 for glibc 2.3.2?)
# must appear in the search path before the host's versions.
# No need if build host is a linux system, though the old bison
# is required for gcc 2.95.

test -z ${HOST_TOOLS_PREFIX} && exit

if [ $BUILD = ${BUILD/%-linux-gnu} ] ; then
     pkgs="sed-4.1.1 make-3.80 gettext-0.14.1 gawk-3.1.3 bison-1.28"
else
     pkgs="bison-1.28"
fi

for pkg in $pkgs; do
    exe=${pkg/-*}
    if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
        echo Unpacking $pkg 
        cd $BUILD_DIR
        decompress ${SOURCES}/${pkg} | tar -xf -
        echo Building $pkg
        cd $pkg
        ./configure --prefix=${HOST_TOOLS_PREFIX}
        make
        echo Installing $pkg
        make install 
    fi
done

if [ $BUILD = ${BUILD/%-linux-gnu} ] ; then
    ln -fs make ${HOST_TOOLS_PREFIX}/bin/gnumake
    pkg=coreutils-5.2.1
    exe=expr
    if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
        echo Unpacking $pkg 
        cd $BUILD_DIR
        decompress ${SOURCES}/${pkg} | tar -xf -
        echo Building $pkg
        cd $pkg
        ./configure --prefix=${HOST_TOOLS_PREFIX}
        make
        echo Installing $pkg
        make install
# coreutils uname is broken on darwin
        rm ${HOST_TOOLS_PREFIX}/bin/uname
## same goes for coreutils-5.0 rm, give it some of its own medicine
#        rm ${HOST_TOOLS_PREFIX}/bin/rm
        hash -r
    fi
fi

if [ ! -x ${HOST_TOOLS_PREFIX}/bin/depmod.pl ]; then
    cd ${HOST_TOOLS_PREFIX}/bin
    decompress ${SOURCES}/depmod.pl > depmod.pl
    patch < ${PATCHES}/depmod-pl-btc-cross-compile.patch
    chmod 755 depmod.pl
else
    echo "depmod.pl already present"
fi

##############################################
#
# Untar and patch kernel sources
#

cd ${BUILD_DIR}
if [ ! -d ${KERNEL} ] ; then
    echo untar ${KERNEL}
    decompress ${SOURCES}/${KERNEL} | tar -xf -
    cd $KERNEL
    case $KERNEL in
        ( linux-2.2.26 )
            decompress ${PATCHES}/linux-2.2.25-btc-Makefile.patch | patch -p0
            case ${TARGET_CPU} in
                ( m68k )
                    # linux-mac68k CVS snapshot
                    decompress ${PATCHES}/linux-2.2.27-rc2-mac68k-20050408.diff | patch -p1 ;;
            esac ;;
        ( linux-2.4.* )
            decompress ${PATCHES}/linux-2.4-btc-Makefile.patch | patch -p1
            case ${TARGET_CPU} in
                ( m68k )
                    # linux-m68k CVS snapshot
                    decompress ${PATCHES}/linux-2.4.28-m68k-20050412.diff | patch -p1
                    # avoid traditional CPP for gcc-3.3
                    decompress ${PATCHES}/linux-2.4.28-m68k-use-standard-cpp.diff | patch -p1 ;;
                ( i386 )
                    patch -p1 < ${PATCHES}/linux-2.4-btc-darwin-bzImage-build.patch ;;
            esac ;;
        ( linux-2.6.* )
            if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
                case $KERNEL in
                    ( linux-2.6.[0-8] | linux-2.6.[0-8]-* | linux-2.6.8.1 | linux-2.6.8.1-* )
                        patch -p1 < ${PATCHES}/linux-2.6-btc-darwin-config.patch ;;
                    ( linux-2.6.* )
                        patch -p1 < ${PATCHES}/linux-2.6.9-btc-darwin-config.patch ;;
                esac
                case $KERNEL in
                    ( linux-2.6.[0-3] | linux-2.6.[0-3]-* )
                        # This patch hasn't been tested on these old versions
                        patch -p1 < ${PATCHES}/linux-2.6.4-btc-darwin-kbuild.patch ;;
                    ( linux-2.6.4 | linux-2.6.4-* )
                        patch -p1 < ${PATCHES}/linux-2.6.4-btc-darwin-kbuild.patch ;;
                    ( linux-2.6.[56] | linux-2.6.[56]-*  )
                        patch -p1 < ${PATCHES}/linux-2.6.5-btc-darwin-kbuild.patch ;;
                    ( linux-2.6.7 | linux-2.6.7-* )
                        patch -p1 < ${PATCHES}/linux-2.6.7-btc-darwin-kbuild.patch ;;
                    ( linux-2.6.* )
                        patch -p1 < ${PATCHES}/linux-2.6.8-btc-darwin-kbuild.patch ;;
                esac
                case $KERNEL in
                    ( linux-2.6.10 | linux-2.6.10-* )
                        patch -p1 < ${PATCHES}/linux-2.6.10-darwin-HOSTCFLAGS.diff ;;
                esac
            fi
            patch -p1 < ${PATCHES}/linux-2.6-btc-Makefile.patch
            if [ x${TARGET_CPU} = xm68k ] ; then
                # linux-m68k CVS snapshot
                decompress ${PATCHES}/linux-2.6.10-m68k-20050208.diff | patch -p1
                # temporary fix for mac_scsi link error
                decompress ${PATCHES}/linux-2.6.10-m68k-ncr5380-exit-link-fix.diff | patch -p1
            fi ;;
    esac
else
    echo "${KERNEL} already present"
fi

##############################################
#
# Untar and patch binutils sources
#

cd ${BUILD_DIR}
if [ ! -d ${BINUTILS_DIST} ] ; then
    echo untar ${BINUTILS_DIST}
    decompress ${SOURCES}/${BINUTILS_DIST} | tar -xf -
    cd ${BINUTILS_DIST}
    case ${BINUTILS_DIST} in
        ( binutils-2.12.90.0.1 )
            # Debian source package
            decompress ${PATCHES}/binutils-2.12.90.0.1-4-debian.diff | patch -p1 ;;
        ( binutils-2.15 | binutils-2.15.* )
            # Fix to support april '04 glibc asm (m68k/arm/cris)
            patch -p1 < ${PATCHES}/binutils-2.15-NO_APP-mode-line-comment.patch ;;
    esac
## Apply HJL patches according to patches/README, e.g.
#    patch -p1 < patches/libtool-dso.patch
else
    echo "${BINUTILS_DIST} already present"
fi

##############################################
#
# Untar and patch gcc-core sources
#

cd ${BUILD_DIR}
if [ ! -d ${GCC_CORE_DIST} ] ; then
    echo untar ${GCC_CORE_DIST}
    decompress ${SOURCES}/${GCC_CORE_DIST} | tar -xf -
    mv ${GCC_DIST} ${GCC_CORE_DIST}
    cd $GCC_CORE_DIST
    case ${GCC_CORE_DIST} in
        ( gcc-core-2.95.3 )
            # Debian sources
            decompress ${PATCHES}/gcc-2.95.4.ds15-22-debian.diff | patch -p1
            # Permit 2.95 compiler to be configured on Darwin
            decompress ${PATCHES}/gcc-2.95.2-host-darwin.diff | patch -p1
            # Darwin compilation fix
            decompress ${PATCHES}/gcc-2.95.3-sys_nerr-redefinition-fix.diff | patch -p1
            ;;
        ( gcc-core-3.[01].* )
            ;;
        ( * )
            if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
                patch -p0 < ${PATCHES}/gcc-3.2-btc-shlib-sans-libc.patch
            fi ;;
    esac
else
    echo "${GCC_CORE_DIST} already present"
fi

##############################################
#
# Untar and patch glibc sources
#

cd ${BUILD_DIR}
if [ ! -d ${GLIBC_DIST} ] ; then
    echo untar ${GLIBC_DIST}
    decompress ${SOURCES}/${GLIBC_DIST} | tar -xf -
    cd ${GLIBC_DIST}
    # Linuxthreads is a seperate package in 2.3.2 and earlier
    if [ x${THREADING_LIB} != x ] ; then
        echo untar ${THREADING_LIB}
        decompress ${SOURCES}/${THREADING_LIB} | tar -xf -
    fi
    case ${GLIBC_DIST} in
        ( glibc-2.2.5 )
            # Debian sources
            decompress ${PATCHES}/glibc-2.2.5-11.8-debian.diff | patch -p1
            # create the 2.2.5-11.8 symlink that patch can't
            ln -s . db/db1
            # Fix for glibc-2.2 with recent kernel headers (m68k)
            decompress ${PATCHES}/glibc-2.2.5-pread64_pwrite64.diff | patch -p1
            ;;
        ( glibc-2.3.2 )
            # Some patches for vanila 2.3.2
            patch -p0 < ${PATCHES}/glibc-2.3.2-debian-alpha-pic.patch
            patch -p1 < ${PATCHES}/glibc-2.3.2-gentoo-alpha-crti.patch
            patch -p1 < ${PATCHES}/glibc-2.3.2-lfs-sscanf-1.patch
            patch -p1 < ${PATCHES}/glibc-2.3.3-lfs-fix_pread_pwrite_syscalls_in_alpha.patch
            ;;
        ( glibc-2.3.3 )
            # CVS snapshot
            decompress ${PATCHES}/glibc-2.3.3-20040728.diff | patch -p1
            patch -p0 < ${PATCHES}/glibc-2.3.3-new-syscall-tests.patch
            patch -p1 < ${PATCHES}/glibc-2.3.3-lfs-5.1-m68k_fix_fcntl.patch
            ;;
    esac
else
    echo "${GLIBC_DIST} already present"
fi

##############################################
#
# Untar and patch gcc sources
#

cd ${BUILD_DIR}
if [ ! -d ${GCC_DIST} ] ; then
    echo untar ${GCC_DIST}
    decompress ${SOURCES}/${GCC_DIST} | tar -xf -
    cd ${GCC_DIST}
    case ${GCC_DIST} in
        ( gcc-2.95.3 )
            # Debian sources
            decompress ${PATCHES}/gcc-2.95.4.ds15-22-debian.diff | patch -p1
            # Permit 2.95 compiler to be configured on Darwin
            decompress ${PATCHES}/gcc-2.95.2-host-darwin.diff | patch -p1
            # Darwin compilation fix
            decompress ${PATCHES}/gcc-2.95.3-sys_nerr-redefinition-fix.diff | patch -p1
            ;;
        ( gcc-3.3.* )
            patch -p0 < ${PATCHES}/gcc-3.3-no-include-filio.patch
            ;;
        ( gcc-3.4.* )
            patch -p0 < ${PATCHES}/gcc-3.4-btc-no-include-filio.patch
            patch -p1 < ${PATCHES}/gcc-3.4.1-btc-use-target-cpp-for-lib-configure.patch
            ;;
    esac
else
    echo "${GCC_DIST} already present"
fi

##############################################
#
# Untar and patch gdb sources
#

cd ${BUILD_DIR}
if [ ! -d ${GDB_DIST} ] ; then
    echo untar ${GDB_DIST}
    decompress ${SOURCES}/${GDB_DIST} | tar -xf -
else
    echo "${GDB_DIST} already present"
fi

##############################################
#
# build and install binutils
#

cd ${BUILD_DIR}
if [ ! -d binutils-${TARGET} ]; then
    mkdir binutils-${TARGET}
    cd binutils-${TARGET}
    CFLAGS="-O2 $HOST_CFLAGS" ../${BINUTILS_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
${BINUTILS_CONFIG_OPTS} \
--enable-64-bit-bfd --disable-nls --enable-shared
    case ${BINUTILS_DIST} in
        ( binutils-2.?.* | binutils-2.10.* | binutils-2.11.* | binutils-2.12.* )
            ;;
        ( * )
            make configure-bfd ;;
    esac
    make headers -C bfd
    make all
else
    echo "binutils-${TARGET} already present"
fi

# When restarting a build, you needn't remove the binutils build directory
# if it built okay. Just remove all the other build directories and the
# $TC_PREFIX directory. Then binutils will just reinstall. (This works
# because binutils has no deps in $TC_PREFIX).

if [ ! -d ${TC_PREFIX}/bin ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/0)

    cd ${BUILD_DIR}/binutils-${TARGET}
    make install
    # no readelf on Darwin & glibc configure doesn't look for ${TARGET}-readelf
    cd ${TC_PREFIX}/bin
    ln -s ${TARGET}-readelf readelf
else
    echo "binutils already installed"
fi

##############################################
#
# install kernel headers
#

if [ ! -d ${KERNEL_HEADERS}/linux ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/1)

    cd ${BUILD_DIR}/${KERNEL}
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- mrproper
    case $KERNEL in
        ( linux-2.[24].* )
            yes "" | make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- config
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- symlinks include/linux/version.h ;;
        ( linux-2.6.* )
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- defconfig
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- include/asm include/linux/version.h ;;
    esac
    cp -r include/linux ${KERNEL_HEADERS}
    cp -r include/asm-generic ${KERNEL_HEADERS}
    cp -r include/asm-${TARGET_CPU} ${KERNEL_HEADERS}/asm
    ln -fs ${KERNEL_HEADERS}/* ${GLIBC_HEADERS}
    cd ..
else
    echo "linux kernel headers already present"
fi

##############################################
#
# glibc pass 1: install the headers
#

cd ${BUILD_DIR}
if [ ! -d glibc-${TARGET}-1 ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/2)

    mkdir glibc-${TARGET}-1
    cd glibc-${TARGET}-1
    # touch this to keep configure's compiler tests happy:
    touch ${GLIBC_HEADERS}/assert.h
    # glibc wants to test the compiler, but it hasn't been built yet
    case $GLIBC_DIST in
        ( glibc-2.2.* )
            echo 'ac_cv_prog_cc_cross=${ac_cv_prog_cc_works=no}' >config.cache
            echo 'ac_cv_prog_cc_cross=${ac_cv_prog_cc_cross=yes}' >>config.cache
            echo 'libc_cv_asm_global_directive=${libc_cv_asm_global_directive=.globl}' >>config.cache
            ;;
        ( glibc-2.3.* )
            if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
                cp ${CONFIGS}/glibc-2.3.2-nptl-__thread-config.cache config.cache
            else
                echo 'libc_cv_ppc_machine=${libc_cv_ppc_machine=yes}' >config.cache # XXX
            fi ;;
    esac
    if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
        # darwin 6 doesn't have one but we need to keep the #includes happy
        touch stddef.h
    fi
    CC=gcc CPP="gcc -E" CFLAGS="-O2 ${HOST_CFLAGS}" \
../${GLIBC_DIST}/configure --prefix=${GLIBC_PREFIX} \
--host=${TARGET} --build=${BUILD} \
--without-cvs --disable-sanity-checks \
$GLIBC_CONFIG_OPTS \
--cache-file=config.cache \
--with-headers=${KERNEL_HEADERS} \
--with-binutils=${TC_PREFIX}/${TARGET}/bin
    rm ${GLIBC_HEADERS}/assert.h
    make install_root=${GLIBC_INSTALL_ROOT} install-headers
    cp ../${GLIBC_DIST}/include/features.h ${GLIBC_HEADERS}
    mkdir -p ${GLIBC_HEADERS}/gnu
    touch ${GLIBC_HEADERS}/gnu/stubs.h
    cp bits/stdio_lim.h ${GLIBC_HEADERS}/bits || true
else
    echo "glibc-${TARGET}-1 already present"
fi

##############################################
#
# gcc-core pass 1: static compiler
#

cd ${BUILD_DIR}
if [ ! -d gcc-core-${TARGET}-1 ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/3)

    mkdir gcc-core-${TARGET}-1
    cd gcc-core-${TARGET}-1
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_CORE_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
${GCC_CONFIG_OPTS} \
--with-newlib \
--disable-multilib \
--disable-nls \
--enable-symvers=gnu \
--enable-threads=posix \
--enable-__cxa_atexit \
--enable-languages=c \
--disable-shared
    make all-gcc
    make install-gcc 
else
    echo "gcc-core-${TARGET}-1 already present"
fi

##############################################
#
# glibc pass 2: csu/subdir_lib for crt[in].o
# this pass is omitted unless using nptl in glibc pass 3
#

cd ${BUILD_DIR}
if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes -a ! -d glibc-${TARGET}-2 ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/4)

    mkdir glibc-${TARGET}-2
    cd glibc-${TARGET}-2
    cp ${CONFIGS}/glibc-2.3.2-nptl-config.cache config.cache
    BUILD_CC=gcc BUILD_CFLAGS=$HOST_CFLAGS \
CFLAGS=-O2 CC=${TARGET}-gcc AR=${TARGET}-ar RANLIB=${TARGET}-ranlib \
../${GLIBC_DIST}/configure --prefix=${GLIBC_PREFIX} \
--host=${TARGET} --build=${BUILD} \
$GLIBC_CONFIG_OPTS \
--without-cvs --disable-profile --disable-debug --without-gd \
--enable-clocale=gnu \
--with-headers=${KERNEL_HEADERS}
    make csu/subdir_lib
else
    echo "glibc-${TARGET}-2 already present"
fi

##############################################
#
# gcc-core pass 2: first non-static compiler
# build and install the required libgcc_s.so and libgcc_eh.a
# this pass is omitted unless using nptl in glibc pass 3
#

cd ${BUILD_DIR}
if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes -a ! -d gcc-core-${TARGET}-2 ]; then
    mkdir gcc-core-${TARGET}-2
    cd gcc-core-${TARGET}-2
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_CORE_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
${GCC_CONFIG_OPTS} \
--with-newlib \
--disable-multilib \
--disable-nls \
--enable-threads=posix \
--enable-symvers=gnu \
--enable-__cxa_atexit \
--enable-languages=c \
--enable-shared
    mkdir -p gcc
    cp ../glibc-${TARGET}-2/csu/crt[in].o gcc
    make all-gcc
    make install-gcc 
else
    echo "gcc-core-${TARGET}-2 already present"
fi

##############################################
#
# glibc pass 3: final build
#

cd ${BUILD_DIR}
if [ ! -d glibc-${TARGET}-3 ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/5)

    mkdir glibc-${TARGET}-3
    cd glibc-${TARGET}-3
    if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
        cp ${CONFIGS}/glibc-2.3.2-nptl-config.cache config.cache
    fi
    BUILD_CC=gcc BUILD_CFLAGS=$HOST_CFLAGS \
CFLAGS=-O2 CC=${TARGET}-gcc AR=${TARGET}-ar RANLIB=${TARGET}-ranlib \
../${GLIBC_DIST}/configure --prefix=${GLIBC_PREFIX} \
--host=${TARGET} --build=${BUILD} \
$GLIBC_CONFIG_OPTS \
--without-cvs --disable-profile --disable-debug --without-gd \
--enable-clocale=gnu \
--with-headers=${KERNEL_HEADERS}
    if [ x${GLIBC_NEEDS_SHARED_GCC} != xyes ]; then
        # we have no libgcc_eh, libgcc_s
        make static-gnulib=-lgcc gnulib=-lgcc
    else
        make
    fi
    make install_root=${GLIBC_INSTALL_ROOT} install
else
    echo "glibc-${TARGET}-3 already present"
fi

##############################################
#
# gcc: final build and install
#

cd ${BUILD_DIR}
if [ ! -d gcc-${TARGET} ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/6)

    mkdir gcc-${TARGET}
    cd gcc-${TARGET}
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
${GCC_CONFIG_OPTS} \
--enable-threads=posix \
--enable-__cxa_atexit \
--enable-languages=c,c++ \
--enable-shared \
--enable-c99 \
--enable-long-long
#--enable-languages=ada,c,c++,objc,java,f77
    make all
    make install
else
    echo "gcc-${TARGET} already present"
fi

##############################################
#
# gdb: build and install
#

cd ${BUILD_DIR}
if [ ! -d gdb-${TARGET} ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/7)

    mkdir gdb-${TARGET}
    cd gdb-${TARGET}
    # the following cache is needed for gdb-6.0
    cp ${CONFIGS}/gdb-6.0-config.cache config.cache
    CFLAGS="-O2 $HOST_CFLAGS" AR=ar RANLIB=ranlib \
    ../${GDB_DIST}/configure --prefix=${TC_PREFIX} --target=${TARGET} \
--build=${BUILD} --cache-file=config.cache
    # for gdb-6.1.1, the following cache is needed as well
    mkdir readline
    cp config.cache readline/config.cache
    make
    make install
else
    echo "gdb-${TARGET} already present"
fi


(cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/8)

##############################################
#
# kernel: build
#

cd ${BUILD_DIR}
if [ ! -e ${KERNEL}/.compiled ]; then
    cd ${KERNEL}
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- clean
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- mrproper
    cp ${CONFIGS}/${KERNEL}-${TARGET_CPU}-dot-config .config
    yes "" | make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- oldconfig
    case $KERNEL in
        ( linux-2.[24].* )
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- dep
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- vmlinux
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- modules
            ;;
        ( linux-2.6.* )
            # this hack is for non-ELF platforms, like Darwin
            case $KERNEL in
                ( linux-2.6.[0-7] | linux-2.6.[0-7]-* ) out=scripts/elf.h ;;
                ( * )                                   out=scripts/mod/elf.h ;;
            esac
            sed 's/^#include <features.h>$//' < ${GLIBC_HEADERS}/elf.h > $out
            make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}-
            ;;
    esac
    touch .compiled
else
    echo "kernel already compiled"
fi

##############################################
#
# kernel: tar up image and modules etc
#

if ( sudo -V >/dev/null 2>&1 ) && \
     [ ! -e ${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image.tar.gz ]; then
    ver=${KERNEL#*-}
    if [ x${ver} = x$KERNEL ] || [ x${ver} = x ]; then
        exit
    fi;
    KERNEL_IMAGE=${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image
    sudo rm -fr ${KERNEL_IMAGE}
    mkdir -p ${KERNEL_IMAGE}/boot
    cd ${BUILD_DIR}/${KERNEL}
    make INSTALL_MOD_PATH=$KERNEL_IMAGE ARCH=$TARGET_CPU \
CROSS_COMPILE=${TARGET}- modules_install
    if [ ${TARGET_CPU} = alpha ]; then
        if [ -e arch/${TARGET_CPU}/boot/vmlinux.gz ]; then
            cp arch/${TARGET_CPU}/boot/vmlinux.gz \
               ${KERNEL_IMAGE}/boot/vmlinux-${ver}.gz
        else
            gzip -c vmlinux > ${KERNEL_IMAGE}/boot/vmlinux-${ver}.gz
        fi
    elif [ ${TARGET_CPU} = ppc ]; then
        cp vmlinux ${KERNEL_IMAGE}/boot/vmlinux-${ver}
    else
        if [ -e arch/${TARGET_CPU}/boot/bzImage ]; then
            cp arch/${TARGET_CPU}/boot/bzImage ${KERNEL_IMAGE}/boot/bzImage-${ver}
        else
            cp vmlinux ${KERNEL_IMAGE}/boot/vmlinux-${ver}
        fi
    fi
    cp System.map ${KERNEL_IMAGE}/boot/System.map-${ver}
    cp .config ${KERNEL_IMAGE}/boot/config-${ver}
    cd ${KERNEL_IMAGE}/boot
    ln -s System.map-${ver} System.map
    cd ${KERNEL_IMAGE}
    rm -f lib/modules/${ver}/build
    chmod -R g-w,o-w ${KERNEL_IMAGE}
    sudo chown -R root ${KERNEL_IMAGE}
    tar -czf ${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image.tar.gz .
    sudo rm -fr ${KERNEL_IMAGE}
else
    echo "linux kernel tarball already present or sudo absent"
fi

##############################################

echo "$0: success!"
