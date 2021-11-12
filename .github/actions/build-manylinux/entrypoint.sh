#!/bin/sh -l
set -e

# setup
cd /github/workspace
yum -y update
yum -y install python3 python3-devel

# env
export PYTHONPATH=$(pwd)/test/python
export CODON_PYTHON=$(python3 test/python/find-python-library.py)
python3 -m pip install numpy

# deps
if [ ! -d ./llvm ]; then
  /bin/bash scripts/deps.sh 2;
fi

# build
mkdir build
export LLVM_DIR=$(llvm/bin/llvm-config --cmakedir)
export LIBUNWIND_PREFIX="$(pwd)/llvm"
(cd build && cmake .. -DCMAKE_BUILD_TYPE=Release \
                      -DCMAKE_C_COMPILER="$(pwd)/llvm/bin/clang" \
                      -DCMAKE_CXX_COMPILER="$(pwd)/llvm/bin/clang++" \
                      -DLIBUNWIND_PREFIX="${LIBUNWIND_PREFIX}")
cmake --build build --config Release -- VERBOSE=1

# test
ln -s build/libcodonrt.so .
build/codon_test
build/codon run test/core/helloworld.codon
build/codon run test/core/exit.codon || if [[ $? -ne 42 ]]; then false; fi

# package
export CODON_BUILD_ARCHIVE=codon-$(uname -s | awk '{print tolower($0)}')-$(uname -m).tar.gz
mkdir -p codon-deploy/bin codon-deploy/lib/codon codon-deploy/plugins
cp build/codon codon-deploy/bin/
cp build/libcodon*.so codon-deploy/lib/codon/
cp build/libomp.so codon-deploy/lib/codon/
cp -r build/include codon-deploy/
cp -r stdlib codon-deploy/lib/codon/
tar -czf ${CODON_BUILD_ARCHIVE} codon-deploy
du -sh codon-deploy
