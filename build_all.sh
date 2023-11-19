#!/usr/bin/env bash

set -e -x

rm -rf build bin

mkdir -p build/486quake
mkdir -p bin

oasm=yes
olto=yes

for cpu in 486 cx4 586; do
    for olevel in O3; do
        #for olto in yes no; do 
            #for oasm in yes no; do
                make -f Makefile.dos clean
                make -j8 -f Makefile.dos OCPU=$cpu OLEVEL=$olevel OLTO=$olto OASM=$oasm
                cp build/*.exe bin/
            #done
        #done
    done
done

make -f Makefile.qmark clean
make -j8 -f Makefile.qmark OCPU=486 OLEVEL=O3 OLTO=yes OASM=yes
cp build/qmark486.exe bin/qmark.exe
