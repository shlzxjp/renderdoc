#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <arm32|arm64>"
    exit 1
fi

ARCH=$1

# Check if NDK_PATH is set
if [ -z "$NDK_PATH" ]; then
    echo "NDK_PATH is not set. Please set it to the path of your NDK installation."
    exit 1
fi

# Check if NDK version is 16
NDK_VERSION=$(grep -oP "Pkg.Revision = \K[0-9]+" "$NDK_PATH/source.properties")
if [ "$NDK_VERSION" -ne 16 ]; then
    echo "NDK version is not 16. Please use NDK version 16."
    exit 1
fi

# Comment out Hello pass in lib/Transforms/CMakeLists.txt and test/CMakeLists.txt if not already commented
sed -i '' '/add_subdirectory(Hello)/ { /^#/! s/add_subdirectory(Hello)/# &/; }' lib/Transforms/CMakeLists.txt
sed -i '' '/LLVMHello/ { /^#/! s/LLVMHello/# &/; }' test/CMakeLists.txt

# Build the native llvm-tblgen
rm -rf build_native
mkdir build_native
cd build_native

cmake ..
make -j$(nproc) llvm-tblgen

TBLGEN_PATH=$(readlink -f bin/llvm-tblgen) # remember this path
echo “build llvm：TBLGEN_PATH is $TBLGEN_PATH”

cd ..
if [ "$ARCH" == "arm32" ]; then
    LLVM_ANDROID_ABI=armeabi-v7a
    LLVM_TRIPLE=armv7-none-linux-androideabi
    LLVM_ARCH=ARM
    BUILD_DIR=build_arm32
    TARGET_PATH=../../support/llvm_arm32
elif [ "$ARCH" == "arm64" ]; then
    LLVM_ANDROID_ABI=arm64-v8a
    LLVM_TRIPLE=aarch64-unknown-linux-android
    LLVM_ARCH=AArch64
    BUILD_DIR=build_arm64
    TARGET_PATH=../../support/llvm_arm64
else
    echo "Invalid architecture: $ARCH"
    exit 1
fi

rm -rf $BUILD_DIR
mkdir $BUILD_DIR
cd $BUILD_DIR

cmake -DLLVM_HOST_TRIPLE:STRING=$LLVM_TRIPLE -DLLVM_TARGET_ARCH:STRING=$LLVM_ARCH \
      -DLLVM_TARGETS_TO_BUILD:STRING=$LLVM_ARCH -DANDROID_ABI=$LLVM_ANDROID_ABI \
      -DANDROID_NATIVE_API_LEVEL=21 -DANDROID_TOOLCHAIN=clang -DANDROID_STL="c++_static" \
      -DCMAKE_TOOLCHAIN_FILE:PATH=$NDK_PATH/build/cmake/android.toolchain.cmake \
      -DCMAKE_INSTALL_PREFIX=$TARGET_PATH -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DLLVM_BUILD_RUNTIME=Off -DLLVM_INCLUDE_TESTS=Off -DLLVM_INCLUDE_EXAMPLES=Off \
      -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_TABLEGEN=$TBLGEN_PATH \
      -DLLVM_BUILD_TOOLS=Off -DLLVM_INCLUDE_TOOLS=Off -DLLVM_USE_HOST_TOOLS=Off ..
make -j8 install

# Copy MCTargetDesc files
mkdir -p $TARGET_PATH/include/MCTargetDesc
cp -R ../lib/Target/$LLVM_ARCH/MCTargetDesc/* $TARGET_PATH/include/MCTargetDesc/
cp ./lib/Target/$LLVM_ARCH/${LLVM_ARCH}*.inc $TARGET_PATH/include/MCTargetDesc/
