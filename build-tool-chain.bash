#!/bin/bash

# Linux cross tool chain build script for Mac OS X and Linux (gcc 3.3)
# Copyright (c) 2004, 2005, 2006 Finn Thain
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
#DIST_ROOT=${HOME}/btc-0.10
DIST_ROOT=/Volumes/btc-0.10

# Where to find sources etc
CONFIGS=${DIST_ROOT}/configs
PATCHES=${DIST_ROOT}/patches
PROFILES=${DIST_ROOT}/profiles
SOURCES=${DIST_ROOT}/sources

# Missing host tools needed for the build to be installed here
HOST_TOOLS_PREFIX=${DIST_ROOT}/hosttools

# This is where tool chains will finally be installed
#BTC_PREFIX=/opt/btc-0.10
BTC_PREFIX=${DIST_ROOT}

# Set vars to determine what to build
. ${PROFILES}/3-m68k

##############################################
#
# Below this line, angels fear to tread

# The build/host tuple 
BUILD=`/usr/share/libtool/config.guess`
echo BUILD: $BUILD

# Profile must set these
echo TARGET: $TARGET
echo TARGET_CPU: $TARGET_CPU
echo METHOD: $METHOD
echo KERNEL: $KERNEL
echo GCC_DIST: $GCC_DIST
echo GCC_CORE_DIST: $GCC_CORE_DIST
echo GLIBC_DIST: $GLIBC_DIST
echo THREADING_LIB: $THREADING_LIB
echo GDB_DIST: $GDB_DIST

# These must be set. set -u makes sure
echo BTC_PREFIX: ${BTC_PREFIX}
echo HOST_TOOLS_PREFIX: ${HOST_TOOLS_PREFIX}

# Tool chain prefix
TC_PREFIX=${BTC_PREFIX}/${GCC_DIST}-${BINUTILS_DIST}-${GLIBC_DIST}

# $METHOD controls how kernel headers and binaries are made, also how gcc gets
# patched & built, since NPTL => shared gcc => early build of glibc crt objects.
# Current glibc seems to require gcc method 3, even for linuxthreads.
# Also, older tools don't have support for sysroot, so they need the old method.

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
--enable-bind-now \
--cache-file=config.cache"
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
    # Need at least gcc 3.3
    gcc_select 3.3 || sudo gcc_select 3.3
    # Let the result be backward compatible with Panther
    export MACOSX_DEPLOYMENT_TARGET=10.3
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
echo PATH: $PATH

# Where to unpack and build. Used as a case-sensitive mount point on Mac OS X.
BUILD_DIR=${DIST_ROOT}/build
echo BUILD_DIR: ${BUILD_DIR}

if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
    cd ${DIST_ROOT}
    if [ -e build.sparseimage ]; then
        echo build.sparseimage already exists...
        if [ -d ${BUILD_DIR} ]; then
            echo and seems to be mounted.
            if [ x"$@" == "x-d" ]; then
                hdiutil detach $BUILD_DIR
                [ ! -d ${BUILD_DIR} ] || exit 1
                rm build.sparseimage
                exit
            fi
        else
            echo but is probably not mounted.
            if [ x"$@" == "x-d" ]; then
                rm build.sparseimage
                exit
            fi
            hdiutil attach -mount required -mountroot ${DIST_ROOT} build.sparseimage
        fi
    else
        if [ x"$@" == "x-d" ]; then
            exit
        fi
        hdiutil create -ov -size 1500M -type SPARSE -fs HFSX \
                       -volname build -partitionType Apple_HFS build
        hdiutil attach -mount required -mountroot ${DIST_ROOT} build.sparseimage
        sudo mount -u -o perm,nodev,nosuid ${DIST_ROOT}/build
    fi
else
    if [ x"$@" == "x-d" ]; then
        sudo rm -rf ${BUILD_DIR}
        exit
    fi
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
                bzip2 -dc $f | dd bs=4194304
                return ;;
            ( $1.gz | $1.tgz | $1.tar.gz )
                gzip -dc $f | dd bs=4194304
                return ;;
            ( $1 | $1.tar )
                dd bs=4194304 if=$f
                return ;;
        esac
    done
    echo "uncompress: can't find $1" 1>&2
    echo "uncompress: can't find $1"
}

##############################################
#
# This function installs a source package given by the first argument.

function install_host_tool () {
    cd $BUILD_DIR
    echo Unpacking $1 
    case $1 in
        ( flex-2.5.4 )
            decompress ${SOURCES}/${1}a | tar -xf -
            echo Building $1
	    cd $1
	    patch -p1 < ${PATCHES}/flex-2.5.4a-r6.diff ;;
	( * )
            decompress ${SOURCES}/${1} | tar -xf -
            echo Building $1
	    cd $1 ;;
    esac
    CFLAGS="-O2" ./configure --prefix=${HOST_TOOLS_PREFIX}
    make
    echo Installing $1
    # one or more of coreutils' uname, rm and others are _broken_ on darwin (tested from 5.0 to 5.94).
    case $1 in
        ( coreutils-* )
            dst=/tmp/junk$$
            make DESTDIR=$dst install
            cp -p $dst/${HOST_TOOLS_PREFIX}/bin/{expr,install} ${HOST_TOOLS_PREFIX}/bin
            rm -fr $dst
            ;;
        ( * )
            make install
            ;;
    esac
}

##############################################
#
# Test for pre-requisites (and install them if need be)
#
# awk, sed, make, gettext (and autoconf-2.13 for glibc 2.3.2?)
# must appear in the search path before the host's versions.
# No need if build host is a linux system, though the old bison
# is required for gcc 2.95.

if [ $BUILD = ${BUILD/%-gnu} ] ; then
    pkgs="sed-4.1.5 make-3.80 gettext-0.14.5 gawk-3.1.5 bison-1.28"
else
    pkgs="bison-1.28 flex-2.5.4"
fi

for pkg in $pkgs; do
    exe=${pkg/-*}
    if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
        # gnu sed-4.1.5 won't build without gnu sed... duh
        if [ $pkg = sed-4.1.5 ] ; then
            install_host_tool sed-4.1.4
        fi
        install_host_tool $pkg
    else
        echo $exe already installed
    fi
done

if [ $BUILD = ${BUILD/%-gnu} ] ; then
    ln -fs make ${HOST_TOOLS_PREFIX}/bin/gnumake
    exe=install
    if [ `which $exe | grep -c ${HOST_TOOLS_PREFIX}/bin/$exe` != 1 ]; then
        install_host_tool coreutils-5.94
    else
        echo $exe already installed
    fi
fi

if [ ! -x ${HOST_TOOLS_PREFIX}/bin/depmod.pl ]; then
    cd ${HOST_TOOLS_PREFIX}/bin
    decompress ${SOURCES}/depmod.pl-14592 > depmod.pl
    patch < ${PATCHES}/depmod-pl-14592-btc-cross-compile.diff
    chmod 755 depmod.pl
else
    echo "depmod.pl already installed"
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
                    decompress ${PATCHES}/linux-2.4.32-m68k.diff | patch -p1
                    # avoid traditional CPP for gcc-3.3
                    decompress ${PATCHES}/linux-2.4.28-m68k-use-standard-cpp.diff | patch -p1 ;;
                ( i386 )
                    patch -p1 < ${PATCHES}/linux-2.4-btc-darwin-bzImage-build.patch ;;
            esac ;;
        ( linux-2.6.* )
            if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
                case $KERNEL in
                    ( linux-2.6.[0-8] | linux-2.6.[0-8][.-]* )
                        patch -p1 < ${PATCHES}/linux-2.6-btc-darwin-config.patch ;;
                    ( linux-2.6.9 | linux-2.6.9[.-]* )
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
                    ( linux-2.6.[89] | linux-2.6.[89][.-]* )
                        patch -p1 < ${PATCHES}/linux-2.6.8-btc-darwin-kbuild.patch ;;
                esac
                case $KERNEL in
                    ( linux-2.6.10 | linux-2.6.10[.-]* )
                        patch -p1 < ${PATCHES}/linux-2.6.10-btc-darwin.diff ;;
                    ( linux-2.6.1[1-5] | linux-2.6.1[1-5][.-]* )
                        echo need to fix patch file
                        exit 1 ;;
                    ( linux-2.6.16 | linux-2.6.16[.-]* )
                        patch -p1 < ${PATCHES}/linux-2.6.16-btc-darwin.diff ;;
                esac
                case $KERNEL in
                    ( linux-2.6.[0-9] | linux-2.6.[0-9][.-]* | linux-2.6.1[01] | linux-2.6.1[01][.-]* )
                        ;;
                    ( * )
                        sed -i -e 's,^#define LOCALEDIR .*,#define LOCALEDIR "'${HOST_TOOLS_PREFIX}'/share/locale",' scripts/kconfig/lkc.h
                        ;;
                esac
            fi
            case $KERNEL in
                ( linux-2.6.[0-9] | linux-2.6.[0-9][.-]* | linux-2.6.10 | linux-2.6.10[.-]* )
                    patch -p1 < ${PATCHES}/linux-2.6-btc-Makefile.patch ;;
                ( linux-2.6.1[1-5] | linux-2.6.1[1-5][.-]* )
                    echo need to split up combined patch file
                    exit 1 ;;
                ( linux-2.6.16 | linux-2.6.16[.-]* )
                    patch -p1 < ${PATCHES}/linux-2.6.16-btc-Makefile.diff ;;
            esac
            if [ x${TARGET_CPU} = xm68k ] ; then
                # linux-m68k CVS snapshot
                decompress ${PATCHES}/linux-2.6.16-m68k-20060606.diff | patch -p1
                decompress ${PATCHES}/linux-2.6.16-m68k-reversals.diff | patch -p1 -R
                for p in \
patch-2.6.16.18 \
linux-2.6.15-m68k-ncr5380-exit-link-fix.diff \
remove_unused_adb_header.diff \
patch_d-via-alt-mapping.diff \
linux-2.6.15-viro-m68k-math-emu-macro-names.diff \
linux-2.6.15-viro-m68k-math-emu-macro-args.diff \
; do
                  decompress ${PATCHES}/$p | patch -p1
                done
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
        ( binutils-2.15 | binutils-2.15.* | binutils-2.16 | binutils-2.16.* )
            # Fix to support april '04 glibc asm (m68k/arm/cris)
            patch -p1 < ${PATCHES}/binutils-2.15-NO_APP-mode-line-comment.patch
            patch -p1 < ${PATCHES}/702-binutils-skip-comments.patch
            ;;
        ( binutils-2.17 | binutils-2.17.* )
            # Avoid fatal compiler warnings
            patch -p1 < ${PATCHES}/binutils-2.17.50.0.2-Werror.diff
            patch -p1 < ${PATCHES}/binutils-2.17.50.0.2-README-script-portability.diff
            patch -p1 < ${PATCHES}/702-binutils-skip-comments.patch
            ;;
    esac
## Apply HJL patches according to patches/README, e.g.
##    patch -p1 < patches/libtool-dso.patch
#    sh patches/README
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
            decompress ${PATCHES}/gcc-2.95.4.ds15-24-debian.diff | patch -p1
            # Crosstool patches
            decompress ${PATCHES}/gcc-pr3106.patch | patch -p1
            decompress ${PATCHES}/backport-config.gcc-1.4.patch | patch -p1
            # More autotools fixes
            decompress ${PATCHES}/gcc-2.95.2-host-darwin.diff | patch -p1
            ;;
        ( gcc-core-3.[01].* )
            ;;
        ( gcc-core-3.* )
            if [ x${GLIBC_NEEDS_SHARED_GCC} = xyes ]; then
                patch -p0 < ${PATCHES}/gcc-3.2-btc-shlib-sans-libc.patch
            fi
            ;;
        ( * )
            echo gcc patch for gcc 4?
            exit 1
            ;;
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
            ;;
        ( glibc-2.3.6 )
            patch -p0 < ${PATCHES}/glibc-2.3.6-symbol-hacks.patch
            ;;
    esac
    case ${GLIBC_DIST} in
        ( glibc-2.3.[2-6] )
            patch -p1 < ${PATCHES}/glibc-2.3.2-btc-m68k_fix_fcntl.diff
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
            decompress ${PATCHES}/gcc-2.95.4.ds15-24-debian.diff | patch -p1
            # Crosstool patches
            decompress ${PATCHES}/gcc-pr3106.patch | patch -p1
            decompress ${PATCHES}/backport-config.gcc-1.4.patch | patch -p1
            # More autotools fixes
            decompress ${PATCHES}/gcc-2.95.2-host-darwin.diff | patch -p1
            ;;
        ( gcc-3.3.* )
            patch -p0 < ${PATCHES}/gcc-3.3-no-include-filio.patch
            ;;
        ( gcc-3.4.* )
            patch -p0 < ${PATCHES}/gcc-3.4-btc-no-include-filio.patch
            patch -p1 < ${PATCHES}/gcc-3.4.1-btc-use-target-cpp-for-lib-configure.patch
            ;;
        ( gcc-4.* )
	        echo gcc patch for gcc 4?
	        exit 1
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

if [ ! -x ${TC_PREFIX}/bin/${TARGET}-as ]; then

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/0.list)

    cd ${BUILD_DIR}/binutils-${TARGET}
    make install
    # no readelf on Darwin & glibc configure doesn't look for ${TARGET}-readelf
    cd ${TC_PREFIX}/bin
    ln -fs ${TARGET}-readelf readelf
else
    echo "binutils already installed"
fi

##############################################
#
# install kernel headers
#

if [ ! -d ${KERNEL_HEADERS}/linux ]; then
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

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/2.list)

else
    echo "linux kernel headers already present"
fi

##############################################
#
# glibc pass 1: install the headers
#

cd ${BUILD_DIR}
if [ ! -d glibc-${TARGET}-1 ]; then
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
        ( glibc-2.4.* )
            echo glibc config cache for glibc 2.4?
	    exit 1
	    ;;
    esac
    if [ `expr ${BUILD##*-} : darwin` = 6 ]; then
        # keep the the compiler happy to prevent missing stddef.h warnings
        touch stddef.h
    fi

    case ${TARGET_CPU} in
        ( mips )
            # o32
            arch_defines="-D_MIPS_FPSET=16 -D_MIPS_ISA=2 -D_ABIO32=1 -D_MIPS_SIM=_ABIO32 -D_MIPS_SZINT=32 -D_MIPS_SZLONG=32 -D_MIPS_SZPTR=32 -D__WORDSIZE=32"
            ## n64
            #arch_defines="-D_MIPS_FPSET=32 -D_MIPS_ISA=4 -D_ABI64=3 -D_MIPS_SIM=_ABI64 -D_MIPS_SZINT=32 -D_MIPS_SZLONG=64 -D_MIPS_SZPTR=64 -D__WORDSIZE=64"
            ## n32
            #arch_defines="-D_MIPS_FPSET=32 -D_MIPS_ISA=4 -D_ABI64=3 -D_MIPS_SIM=_NABI32 -D_MIPS_SZINT=32 -D_MIPS_SZLONG=32 -D_MIPS_SZPTR=32 -D__WORDSIZE=32"
            ;;
       ( arm )
            arch_defines="-D__ARM_EABI__"
            ;;
       ( * )
            arch_defines=""
            ;;
    esac

    CC="gcc $arch_defines" CPP="gcc -E $arch_defines" CFLAGS="-O2 ${HOST_CFLAGS}" \
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

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/3.list)

else
    echo "glibc-${TARGET}-1 already present"
fi

##############################################
#
# gcc-core pass 1: static compiler
#

cd ${BUILD_DIR}
if [ ! -d gcc-core-${TARGET}-1 ]; then
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
--disable-shared \
--disable-libmudflap --disable-libssp --disable-libunwind-exceptions
    make all-gcc
    make install-gcc 

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/4.list)

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

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/5.list)

else
    echo "gcc-core-${TARGET}-2 already present"
fi

##############################################
#
# glibc pass 3: final build
#

cd ${BUILD_DIR}
if [ ! -d glibc-${TARGET}-3 ]; then
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

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/6.list)

else
    echo "glibc-${TARGET}-3 already present"
fi

##############################################
#
# gcc: final build and install
#

cd ${BUILD_DIR}
if [ ! -d gcc-${TARGET} ]; then
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

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/7.list)

else
    echo "gcc-${TARGET} already present"
fi

##############################################
#
# gdb: build and install
#

cd ${BUILD_DIR}
if [ ! -d gdb-${TARGET} ]; then
    mkdir gdb-${TARGET}
    cd gdb-${TARGET}
    CFLAGS="$HOST_CFLAGS -O2" AR=ar RANLIB=ranlib \
    ../${GDB_DIST}/configure --prefix=${TC_PREFIX} --target=${TARGET} \
--build=${BUILD}
    make
    make install

    (cd ${TC_PREFIX} && find . | sort > ${BUILD_DIR}/8.list)

else
    echo "gdb-${TARGET} already present"
fi

##############################################
#
# kernel: build
#

cd ${BUILD_DIR}
if [ ! -e ${KERNEL}/.compiled ]; then
    cd ${KERNEL}
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- clean
    make ARCH=${TARGET_CPU} CROSS_COMPILE=${TARGET}- mrproper
    cp ${CONFIGS}/${DOTCONFIG:-${KERNEL}-${TARGET_CPU}-dot-config} .config
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
    KERNEL_IMAGE=${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image
    sudo rm -fr ${KERNEL_IMAGE}
    mkdir -p ${KERNEL_IMAGE}/boot
    cd ${BUILD_DIR}/${KERNEL}
    make INSTALL_MOD_PATH=$KERNEL_IMAGE ARCH=$TARGET_CPU \
CROSS_COMPILE=${TARGET}- modules_install
    cd ${KERNEL_IMAGE}/lib/modules
    ver=`ls -d [0-9]*`
    if [ x${ver} = x ]; then
        exit
    fi
    cd ${BUILD_DIR}/${KERNEL}
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
    rm -f lib/modules/${ver}/{build,source}
    chmod -R g-w,o-w ${KERNEL_IMAGE}
    sudo chown -R 0 ${KERNEL_IMAGE}
    tar -czf ${BUILD_DIR}/${KERNEL}-${TARGET_CPU}-image.tar.gz .
else
    echo "linux kernel tarball already present or sudo absent"
fi

##############################################

echo "$0: success!"
