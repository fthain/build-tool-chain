#!/bin/bash

set -e -u

BTC_PREFIX=/Volumes/btc-0.11
cd ${BTC_PREFIX}

t=`mktemp -d /tmp/btc.XXXXXX`
mkdir ${t}/{ok,fail}

if [ -n "$*" ] ; then
  profiles=("$@")
else
  profiles=(profiles/*-*)
fi

for p in "${profiles[@]}" ; do 
    profile=$(basename "$p")
    scripts/build-tool-chain.bash -d
    echo "===" ${profile}
    if ( scripts/build-tool-chain.bash -p ${profile} ) ; then
        echo "..." OK
        mv logs ${t}/ok/${profile}
    else
        echo "!!!" FAIL
        mv logs ${t}/fail/${profile}
    fi
    echo
done
scripts/build-tool-chain.bash -d
