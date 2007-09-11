#!/bin/bash

set -e -u

BTC_PREFIX=/Volumes/btc-0.11
PROFILES=${BTC_PREFIX}/profiles

t=`mktemp -d /tmp/tmp.XXXXXX`
mkdir ${t}/{ok,fail}
for p in $( cd ${PROFILES} && ls *-* ) ; do 
    cd ${BTC_PREFIX}
    scripts/build-tool-chain.bash -d
    echo "===" ${p}
    if ( scripts/build-tool-chain.bash -p ${p} ) ; then
        echo "..." OK
        mv logs ${t}/ok/${p}
    else
        echo "!!!" FAIL
        mv logs ${t}/fail/${p}
    fi
    echo
done
scripts/build-tool-chain.bash -d
