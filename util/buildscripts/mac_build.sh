#!/bin/bash
NDK_PATH=/Users/fanjie/Library/Android/sdk/ndk/16.1.4479499 # 必须要16的NDK，否则会报错
# ANDROID_HOME=/Users/fanjie/Library/Android/sdk
# ANDROID_SDK=/Users/fanjie/Library/Android/sdk

# 判断llvm_arm32和llvm_arm64文件夹是否都存在
if [ ! -d "support/llvm_arm32" ] || [ ! -d "support/llvm_arm64" ]; then
  echo "llvm_arm32 or llvm_arm64 does not exist. build them first."
  # Check if llvm directory exists
  if [ ! -d "llvm" ]; then
    # Clone the repository
    git clone -b release_40 --depth=10 https://github.com/llvm-mirror/llvm
  fi

  cd llvm
  ../llvm_build.sh arm32
  ../llvm_build.sh arm64
  cd ..
fi

./build.sh --snapshot libpag