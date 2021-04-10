#!/usr/bin/env bash

set -e -x

rm -rf build bin

mkdir -p build/486quake
mkdir -p bin

for cpu in 386 486 586 686; do
    for olevel in Os O2 O3; do
        for olto in yes no; do 
            for oasm in yes no; do
                make -f Makefile.dos clean
                make -j8 -f Makefile.dos OCPU=$cpu OLEVEL=$olevel OLTO=$olto OASM=$oasm
                cp build/*.exe bin/
            done
        done
    done
done