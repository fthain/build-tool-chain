#!/bin/bash

# Linux cross tool chain build script for Mac OS X Panther and Linux (gcc 3.3)
# Copyright (c) 2004 Finn Thain
# fthain@telegraphics.com.au


# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
 
 
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

# Where everything lives
#BTC_ROOT=/Volumes/Linux/btc &&
BTC_ROOT=${HOME}/btc-0.8 &&

# Where to unpack and build
BUILD_DIR=${BTC_ROOT}/build &&
mkdir -p $BUILD_DIR &&

# The build/host tuple 
BUILD=powerpc-apple-darwin &&
#BUILD=i686-pc-linux-gnu &&

# The target tuple
TARGET=m68k-unknown-linux-gnu &&
TARGET_CPU=m68k &&
#TARGET=alpha-unknown-linux-gnu &&
#TARGET_CPU=alpha &&
#TARGET=powerpc-unknown-linux-gnu &&
#TARGET_CPU=ppc &&
#TARGET=i686-pc-linux-gnu &&
#TARGET_CPU=i386 &&

# Packages to be built
BINUTILS_DIST=binutils-2.15 &&
GCC_DIST=gcc-3.4.1 &&
GCC_CORE_DIST=gcc-core-3.4.1 &&
GLIBC_DIST=glibc-2.3.3 &&
GDB_DIST=gdb-6.1.1 &&
#THREADING_LIB=glibc-linuxthreads-2.3.2 &&

# This flag controls how kernel headers and binaries are made, and also the gcc
# build & patching, since nptl => shared gcc => early build of glibc crt objects.
KERNEL_2_4= &&
if [ x${KERNEL_2_4} = xyes ]; then
    KERNEL=linux-2.4.27 &&
    GLIBC_CONFIG_OPTS="--enable-kernel=2.4.27 --enable-add-ons=linuxthreads"
else
    KERNEL=linux-2.6.8.1 &&
    if [ x${TARGET/-*} = xm68k ]; then
        GLIBC_CONFIG_OPTS="--enable-kernel=2.6.8 --enable-add-ons=linuxthreads"
    else
        GLIBC_CONFIG_OPTS="--enable-kernel=2.6.8 --enable-add-ons=nptl \
--with-tls --cache-file=config.cache"
    fi
fi &&

##############################################

# Necessary to trick configure into cross compiling
if [ $TARGET = $BUILD ] ; then
    BUILD=${BUILD}x
fi

# Missing host tools will go here
HOST_TOOLS_PREFIX=${BTC_ROOT}/hosttools &&
mkdir -p ${HOST_TOOLS_PREFIX}/bin &&

# Where to find sources etc
SOURCES=${BTC_ROOT}/sources &&
PATCHES=${BTC_ROOT}/patches &&
CONFIGS=${BTC_ROOT}/configs &&

# Tool chain prefix
TC_PREFIX=${BTC_ROOT}/xcompiler/${TARGET} &&

# Linux headers are installed here
KERNEL_HEADERS=${TC_PREFIX}/kernel-headers &&
mkdir -p ${KERNEL_HEADERS} &&

# Target root directory
SYSROOT=${TC_PREFIX}/sysroot &&

# glibc prefix
HEADERS_PREFIX=${SYSROOT}/usr/include &&
mkdir -p ${HEADERS_PREFIX} &&

## gcc 3.2 hack (it doesn't understand --with-sysroot)
#ln -fs ${SYSROOT}/usr/include ${TC_PREFIX}/include &&

if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
    # Turn off Apple's pre-compiled headers
    HOST_CFLAGS=-no-cpp-precomp 
else
    # This works for Linux hosts
    HOST_CFLAGS=''
fi &&

export CPP="gcc -E $HOST_CFLAGS" &&
export CC=gcc &&
export PATH=${TC_PREFIX}/bin:${HOST_TOOLS_PREFIX}/bin:/bin:/sbin:/usr/bin:/usr/sbin &&
export LANGUAGE=C LANG=C LC_ALL=C &&

if [ x"$@" == "x-s" ]; then
    export BTC_ROOT BUILD_DIR SOURCES PATCHES CONFIGS KERNEL TARGET TARGET_CPU TC_PREFIX &&
    cd $BUILD_DIR &&
    exec bash # to get a shell with the environment set
fi &&

##############################################
#
# This function decompresses the file given by the first argument to stdout.

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
} &&

##############################################
#
# Test for pre-requisites (and install them if need be)
#
# awk, sed, make, gettext (and autoconf-2.13 for glibc 2.3.2?)
# must appear in the search path before the host's versions.
# No need if build host is a linux system

if [ $BUILD = ${BUILD/%-linux-gnu} ] ; then
    test -z ${HOST_TOOLS_PREFIX} && exit

    for pkg in sed-4.1.1 make-3.80 gettext-0.14.1 gawk-3.1.3; do
        exe=${pkg/-*}
        if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
            echo Unpacking $pkg 
            cd $BUILD_DIR &&
            decompress ${SOURCES}/${pkg} | tar -xf - &&
            echo Building $pkg &&
            cd $pkg &&
            ./configure --prefix=${HOST_TOOLS_PREFIX} &&
            make &&
            echo Installing $pkg &&
            make install 
        fi
    done &&

    pkg=coreutils-5.2.1 &&
    exe=expr &&
    if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
        echo Unpacking $pkg 
        cd $BUILD_DIR &&
        decompress ${SOURCES}/${pkg} | tar -xf - &&
        echo Building $pkg &&
        cd $pkg &&
        ./configure --prefix=${HOST_TOOLS_PREFIX} &&
        make &&
        echo Installing $pkg &&
        make install &&
# coreutils uname is broken on darwin
        rm ${HOST_TOOLS_PREFIX}/bin/uname &&
## same goes for coreutils-5.0 rm, give it some of its own medicine
#        rm ${HOST_TOOLS_PREFIX}/bin/rm &&
        hash -r
    fi
fi &&

if [ ! -x ${HOST_TOOLS_PREFIX}/bin/depmod.pl ]; then
    cd ${HOST_TOOLS_PREFIX}/bin &&
    decompress ${SOURCES}/depmod.pl > depmod.pl &&
    patch < ${PATCHES}/depmod-pl-btc-cross-compile.patch &&
    chmod 755 depmod.pl
else
    echo "depmod.pl already present"
fi &&

##############################################
#
# Untar and patch kernel sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${KERNEL} ] ; then
    echo untar ${KERNEL} &&
    if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
        if [ -e ${KERNEL}.sparseimage ]; then
            echo ${KERNEL}.sparseimage already exists.
            exit 1
        fi
        hdiutil create -ov -size 320M -type SPARSE -fs UFS -volname ${KERNEL} \
-partitionType Apple_UFS ${KERNEL} &&
        hdiutil attach -mount required -mountroot ${BUILD_DIR} \
${KERNEL}.sparseimage
    fi &&
    decompress ${SOURCES}/${KERNEL} | tar -xf - &&
    cd $KERNEL &&
    if [ x${KERNEL_2_4} = xyes ]; then
        patch -p1 < ${PATCHES}/linux-2.4-btc-Makefile.patch &&
        case ${GCC_DIST} in
            ( gcc-3.3.4 )
                # Patch for compilation with gcc 3.3.4
                patch -p1 < ${PATCHES}/linux-2.4.27-remove-inlines-for-gcc-3_3_4.patch ;;
            ( gcc-3.4.1 )
                # Patch for compilation with gcc 3.4.1
                patch -p1 < ${PATCHES}/linux-2.4.27-remove-inlines-for-gcc-3_4_1.patch ;;
        esac &&
        case ${TARGET_CPU} in
            ( m68k )
                # linux-m68k CVS snapshot
                patch -p1 < ${PATCHES}/linux-2.4.27-m68k-20040824.diff ;;
            ( i386 )
                # x86 patches
                patch -p1 < ${PATCHES}/linux-2.4-btc-darwin-bzImage-build.patch &&
                patch -p1 < ${PATCHES}/patch-gcc34-fastcall-fixes-2.4.27 ;;
        esac
    else
        if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
            patch -p1 < ${PATCHES}/linux-2.6-btc-darwin-config.patch &&
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
        fi &&
        patch -p1 < ${PATCHES}/linux-2.6-btc-Makefile.patch &&
        if [ x${TARGET_CPU} = xm68k ] ; then
            patch -p0 < ${PATCHES}/linux-2.6.8.1-m68k-zippel-elf-header-fix.diff
            # linux-m68k CVS snapshot
            patch -p1 < ${PATCHES}/linux-2.6.8.1-m68k-20040817.patch
        fi
    fi
else
    echo "${KERNEL} already present"
fi &&

##############################################
#
# Untar and patch binutils sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${BINUTILS_DIST} ] ; then
    echo untar ${BINUTILS_DIST} &&
    decompress ${SOURCES}/${BINUTILS_DIST} | tar -xf - &&
    cd ${BINUTILS_DIST} &&
# Fix to support april '04 glibc asm (m68k/arm/cris)
    patch -p1 < ${PATCHES}/binutils-2.15-NO_APP-mode-line-comment.patch
## Apply HJL patches according to patches/README, e.g.
#    patch -p1 < patches/libtool-dso.patch
else
    echo "${BINUTILS_DIST} already present"
fi &&

##############################################
#
# Untar and patch gcc-core sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${GCC_CORE_DIST} ] ; then
    echo untar ${GCC_CORE_DIST} &&
    decompress ${SOURCES}/${GCC_CORE_DIST} | tar -xf - &&
    mv ${GCC_DIST} ${GCC_CORE_DIST} &&
    cd $GCC_CORE_DIST &&
    case ${GCC_CORE_DIST} in
        ( gcc-core-3.3.4 )
            patch -p1 < ${PATCHES}/gcc-3.3.4-complex-float.patch ;;
    esac &&
    if [ x${KERNEL_2_4} != xyes ]; then
        patch -p0 < ${PATCHES}/gcc-3.2-btc-shlib-sans-libc.patch
    fi
else
    echo "${GCC_CORE_DIST} already present"
fi &&

##############################################
#
# Untar and patch glibc sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${GLIBC_DIST} ] ; then
    echo untar ${GLIBC_DIST} &&
    decompress ${SOURCES}/${GLIBC_DIST} | tar -xf - &&
    cd ${GLIBC_DIST} &&
## Linuxthreads is a seperate package in 2.3.2 and earlier
#    echo untar ${THREADING_LIB} &&
#    decompress ${SOURCES}/${THREADING_LIB} | tar -xf - &&
## Some patches for vanila 2.3.2
#    patch -p0 < ${PATCHES}/glibc-2.3.2-debian-alpha-pic.patch &&
#    patch -p1 < ${PATCHES}/glibc-2.3.2-gentoo-alpha-crti.patch &&
#    patch -p1 < ${PATCHES}/glibc-2.3.2-lfs-sscanf-1.patch &&
#    patch -p1 < ${PATCHES}/glibc-2.3.3-lfs-fix_pread_pwrite_syscalls_in_alpha.patch &&
# CVS Snapshot
    decompress ${PATCHES}/glibc-2.3.3-20040728.diff | patch -p1 &&
# M68K patches
    patch -p1 < ${PATCHES}/glibc-2.3.3-lfs-5.1-m68k_fix_fcntl.patch &&
    patch -p1 < ${PATCHES}/glibc-2.3.3-btc-m68k-no-precision-timers.patch
# Alpha patch for pre-2.6.4 kernel headers, mid 2004 and later glibc snapshots
    patch -p0 < ${PATCHES}/fix-alpha-compilation-failure
else
    echo "${GLIBC_DIST} already present"
fi &&

##############################################
#
# Untar and patch gcc sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${GCC_DIST} ] ; then
    echo untar ${GCC_DIST} &&
    decompress ${SOURCES}/${GCC_DIST} | tar -xf - &&
    cd ${GCC_DIST} &&
    case ${GCC_DIST} in
        ( gcc-3.3.4 )
            patch -p1 < ${PATCHES}/gcc-3.3.4-complex-float.patch &&
            patch -p0 < ${PATCHES}/gcc-3.3-no-include-filio.patch ;;
        ( gcc-3.3.* )
            patch -p0 < ${PATCHES}/gcc-3.3-no-include-filio.patch ;;
        ( gcc-3.4.* )
            patch -p0 < ${PATCHES}/gcc-3.4-btc-no-include-filio.patch &&
            patch -p1 < ${PATCHES}/gcc-3.4.1-btc-use-target-cpp-for-lib-configure.patch ;;
    esac
else
    echo "${GCC_DIST} already present"
fi &&

##############################################
#
# Untar and patch gdb sources
#

cd ${BUILD_DIR} &&
if [ ! -d ${GDB_DIST} ] ; then
    echo untar ${GDB_DIST} &&
    decompress ${SOURCES}/${GDB_DIST} | tar -xf -
else
    echo "${GDB_DIST} already present"
fi &&

##############################################
#
# build and install binutils
#

cd ${BUILD_DIR} &&
if [ ! -d binutils-${TARGET} ]; then
    mkdir binutils-${TARGET} &&
    cd binutils-${TARGET} &&
    CFLAGS="-O2 $HOST_CFLAGS" ../${BINUTILS_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
--with-sysroot=${SYSROOT} \
--enable-64-bit-bfd --disable-nls --enable-shared &&
    make configure-bfd &&
    make headers -C bfd &&
    make all
else
    echo "binutils-${TARGET} already present"
fi &&

# When restarting a build, you needn't remove the binutils build directory
# if it built okay. Just remove all the other build directories and the
# $TC_PREFIX directory. Then binutils will just reinstall. (This works
# because binutils has no deps in $TC_PREFIX).

if [ ! -d ${TC_PREFIX}/bin ]; then
    cd ${BUILD_DIR}/binutils-${TARGET} &&
    make install &&
    # gentoo does this...
    cp ${BUILD_DIR}/${BINUTILS_DIST}/include/libiberty.h ${HEADERS_PREFIX} &&
    # no readelf on Darwin & glibc configure doesn't look for ${TARGET}-readelf
    cd ${TC_PREFIX}/bin &&
    ln -s ${TARGET}-readelf readelf
else
    echo "binutils already installed"
fi &&

##############################################
#
# install kernel headers
#

if [ ! -d ${KERNEL_HEADERS}/linux ]; then
    cd ${BUILD_DIR}/${KERNEL} &&   
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- mrproper &&
    if [ x${KERNEL_2_4} = xyes ]; then
        yes "" | make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- config &&
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- symlinks include/linux/version.h
    else
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- defconfig &&
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- include/asm include/linux/version.h
    fi &&
    cp -r include/linux ${KERNEL_HEADERS} &&
    cp -r include/asm-generic ${KERNEL_HEADERS} &&
    cp -r include/asm-${TARGET_CPU} ${KERNEL_HEADERS}/asm &&
    ln -fs ${KERNEL_HEADERS}/* ${HEADERS_PREFIX} &&
    cd ..
else
    echo "linux kernel headers already present"
fi &&

##############################################
#
# glibc pass 1: install the headers
#

cd ${BUILD_DIR} &&
if [ ! -d glibc-${TARGET}-1 ]; then
    mkdir glibc-${TARGET}-1 &&
    cd glibc-${TARGET}-1 &&
    # touch this to keep configure's compiler tests happy:
    touch ${HEADERS_PREFIX}/assert.h &&
    # glibc wants to test the compiler, but it hasn't been built yet
    if [ x${KERNEL_2_4} = xyes ]; then
        echo 'libc_cv_ppc_machine=${libc_cv_ppc_machine=yes}' >config.cache
    else
        cp ${CONFIGS}/glibc-2.3.2-nptl-__thread-config.cache config.cache
    fi &&
    if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
        # darwin 6 doesn't have one but we need to keep the #includes happy
        touch stddef.h
    fi &&
    CC=gcc CPP="gcc -E" CFLAGS=${HOST_CFLAGS} \
../${GLIBC_DIST}/configure --prefix=/usr \
--host=$TARGET --build=${BUILD} \
--without-cvs --disable-sanity-checks \
$GLIBC_CONFIG_OPTS \
--cache-file=config.cache \
--with-headers=${KERNEL_HEADERS} \
--with-binutils=${TC_PREFIX}/${TARGET}/bin &&
    rm ${HEADERS_PREFIX}/assert.h &&
    make install_root=${SYSROOT} install-headers &&
    touch ${HEADERS_PREFIX}/gnu/stubs.h &&
    cp bits/stdio_lim.h ${HEADERS_PREFIX}/bits
else
    echo "glibc-${TARGET}-1 already present"
fi &&

##############################################
#
# gcc-core pass 1: static compiler
#

cd ${BUILD_DIR} &&
if [ ! -d gcc-core-${TARGET}-1 ]; then
    mkdir gcc-core-${TARGET}-1 &&
    cd gcc-core-${TARGET}-1 &&
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_CORE_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
--with-sysroot=${SYSROOT} \
--disable-multilib \
--with-newlib \
--disable-nls \
--enable-threads=posix \
--enable-symvers=gnu \
--enable-__cxa_atexit \
--enable-languages=c \
--disable-shared &&
    make all-gcc &&
    make install-gcc 
else
    echo "gcc-core-${TARGET}-1 already present"
fi &&

##############################################
#
# glibc pass 2: csu/subdir_lib for crt[in].o
# this pass is omitted unless using nptl in glibc pass 3
#

cd ${BUILD_DIR} &&
if [ x${KERNEL_2_4} != xyes -a ! -d glibc-${TARGET}-2 ]; then
    mkdir glibc-${TARGET}-2 &&
    cd glibc-${TARGET}-2 &&
    cp ${CONFIGS}/glibc-2.3.2-nptl-config.cache config.cache &&
    BUILD_CC=gcc BUILD_CFLAGS=$HOST_CFLAGS \
CFLAGS=-O2 CC=${TARGET}-gcc AR=${TARGET}-ar RANLIB=${TARGET}-ranlib \
../${GLIBC_DIST}/configure --prefix=/usr \
--host=$TARGET --build=${BUILD} \
$GLIBC_CONFIG_OPTS \
--without-cvs --disable-profile --disable-debug --without-gd \
--enable-clocale=gnu \
--with-headers=${KERNEL_HEADERS} &&
    make csu/subdir_lib
else
    echo "glibc-${TARGET}-2 already present"
fi &&

##############################################
#
# gcc-core pass 2: first non-static compiler
# build and install the required libgcc_s.so and libgcc_eh.a
# this pass is omitted unless using nptl in glibc pass 3
#

cd ${BUILD_DIR} &&
if [ x${KERNEL_2_4} != xyes -a ! -d gcc-core-${TARGET}-2 ]; then
    mkdir gcc-core-${TARGET}-2 &&
    cd gcc-core-${TARGET}-2 &&
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_CORE_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
--with-sysroot=${SYSROOT} \
--disable-multilib \
--with-newlib \
--disable-nls \
--enable-threads=posix \
--enable-symvers=gnu \
--enable-__cxa_atexit \
--enable-languages=c \
--enable-shared &&
    mkdir -p gcc &&
    cp ../glibc-${TARGET}-2/csu/crt[in].o gcc &&
    make all-gcc &&
    make install-gcc 
else
    echo "gcc-core-${TARGET}-2 already present"
fi &&

##############################################
#
# glibc pass 3: final build
#

cd ${BUILD_DIR} &&
if [ ! -d glibc-${TARGET}-3 ]; then
    if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
        if [ -e glibc-${TARGET}-3.sparseimage ]; then
            echo glibc-${TARGET}-3.sparseimage already exists.
            exit 1
        fi
        hdiutil create -ov -size 200M -type SPARSE -fs UFS \
-volname glibc-${TARGET}-3 -partitionType Apple_UFS glibc-${TARGET}-3 &&
        hdiutil attach -mount required -mountroot ${BUILD_DIR} \
glibc-${TARGET}-3.sparseimage
    else
        mkdir glibc-${TARGET}-3
    fi &&
    cd glibc-${TARGET}-3 &&
    if [ x${KERNEL_2_4} != xyes ]; then
        cp ${CONFIGS}/glibc-2.3.2-nptl-config.cache config.cache
    fi &&
    BUILD_CC=gcc BUILD_CFLAGS=$HOST_CFLAGS \
CFLAGS=-O2 CC=${TARGET}-gcc AR=${TARGET}-ar RANLIB=${TARGET}-ranlib \
../${GLIBC_DIST}/configure --prefix=/usr \
--host=$TARGET --build=${BUILD} \
$GLIBC_CONFIG_OPTS \
--without-cvs --disable-profile --disable-debug --without-gd \
--enable-clocale=gnu \
--with-headers=${KERNEL_HEADERS} &&
    if [ x${KERNEL_2_4} = xyes ]; then
        make static-gnulib=-lgcc gnulib=-lgcc
    else
        make
    fi &&
    make install_root=${SYSROOT} install
else
    echo "glibc-${TARGET}-3 already present"
fi &&

##############################################
#
# gcc: final build and install
#

## gcc 3.2 hack
#ln -fs ${SYSROOT}/usr/lib/crt[1in].o ${TC_PREFIX}/${TARGET}/lib &&

cd ${BUILD_DIR} &&
if [ ! -d gcc-${TARGET} ]; then
    mkdir gcc-${TARGET} &&
    cd gcc-${TARGET} &&
    CFLAGS="-O2 $HOST_CFLAGS" \
../${GCC_DIST}/configure \
--prefix=${TC_PREFIX} --target=${TARGET} \
--with-sysroot=${SYSROOT} \
--enable-threads=posix \
--enable-__cxa_atexit \
--enable-languages=c,c++ \
--enable-shared \
--enable-c99 \
--enable-long-long \
--enable-altivec &&
#--enable-languages=ada,c,c++,objc,java,f77
    make all &&
    make install
else
    echo "gcc-${TARGET} already present"
fi &&

##############################################
#
# gdb: build and install
#

cd ${BUILD_DIR} &&
if [ ! -d gdb-${TARGET} ]; then
    mkdir gdb-${TARGET} &&
    cd gdb-${TARGET} &&
    # the following cache is needed for gdb-6.0
    cp ${CONFIGS}/gdb-6.0-config.cache config.cache &&
    CFLAGS="-O2 $HOST_CFLAGS" AR=ar RANLIB=ranlib \
    ../${GDB_DIST}/configure --prefix=${TC_PREFIX} --target=${TARGET} \
--build=${BUILD} --cache-file=config.cache &&
    # for gdb-6.1.1, the following cache is needed as well
    mkdir readline &&
    cp config.cache readline/config.cache &&
    make &&
    make install
else
    echo "gdb-${TARGET} already present"
fi &&

##############################################
#
# kernel: build
#

cd ${BUILD_DIR} &&
if [ ! -e ${KERNEL}/.compiled ]; then
    cd ${KERNEL} &&
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- clean &&
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- mrproper &&
    cp ${CONFIGS}/${KERNEL}-${TARGET_CPU}-dot-config .config &&
    yes "" | make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- oldconfig &&
    if [ x${KERNEL_2_4} = xyes ]; then
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- dep &&
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- vmlinux &&
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- modules
     else
        case $KERNEL in
            ( linux-2.6.[0-7] | linux-2.6.[0-7]-* )
                sed 's/^#include <features.h>$//' \
 < ${SYSROOT}/usr/include/elf.h > scripts/elf.h ;;
            ( linux-2.6.* )
                sed 's/^#include <features.h>$//' \
 < ${SYSROOT}/usr/include/elf.h > scripts/mod/elf.h ;;
        esac
        make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}-
    fi &&
    touch .compiled
else
    echo "kernel already compiled"
fi &&

##############################################
#
# kernel: tar up image and modules etc
#

if ( sudo -V >/dev/null 2>&1 ) && \
     [ ! -e ${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image.tar.gz ]; then
    mnp=${KERNEL#*-} &&
    [ x$mnp != x$KERNEL ] && [ x$mnp != x ] && 
    KERNEL_IMAGE=${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image &&
    sudo rm -fr ${KERNEL_IMAGE} &&
    mkdir -p ${KERNEL_IMAGE}/boot &&
    cd ${BUILD_DIR}/${KERNEL} &&
    make INSTALL_MOD_PATH=$KERNEL_IMAGE ARCH=$TARGET_CPU CROSS_COMPILE=${TARGET}- modules_install &&
    if [ ${TARGET_CPU} = alpha ] ; then
        if [ -e arch/${TARGET_CPU}/boot/vmlinux.gz ]; then
            cp arch/${TARGET_CPU}/boot/vmlinux.gz \
               ${KERNEL_IMAGE}/boot/vmlinux-${mnp}.gz
        else
            gzip -c vmlinux > ${KERNEL_IMAGE}/boot/vmlinux-${mnp}.gz
        fi
    elif [ ${TARGET_CPU} = ppc ] ; then
        cp vmlinux ${KERNEL_IMAGE}/boot/vmlinux-${mnp}
    else
        if [ -e arch/${TARGET_CPU}/boot/bzImage ]; then
            cp arch/${TARGET_CPU}/boot/bzImage ${KERNEL_IMAGE}/boot/bzImage-$mnp
        else
            cp vmlinux ${KERNEL_IMAGE}/boot/vmlinux-${mnp}
        fi
    fi &&
    cp System.map ${KERNEL_IMAGE}/boot/System.map-$mnp &&
    cp .config ${KERNEL_IMAGE}/boot/config-$mnp &&
    cd ${KERNEL_IMAGE}/boot &&
    ln -s System.map-$mnp System.map &&
    cd ${KERNEL_IMAGE} &&
    rm -f lib/modules/${mnp}/build &&
    chmod -R g-w,o-w ${KERNEL_IMAGE} &&
    sudo chown -R root ${KERNEL_IMAGE} &&
    tar -czf ${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image.tar.gz . &&
    sudo rm -fr ${KERNEL_IMAGE}
else
    echo "linux kernel tarball already present or sudo absent"
fi &&

##############################################

echo "$0: success!"
