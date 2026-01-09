#!/bin/bash

mkdir -p "${REPO_ROOT}/dist"

# pushd into the git checkout
pushd "${REPO_ROOT}"

# Build 32-bit Release
MSYS2_ARG_CONV_EXCL="*" msbuild.exe /nologo /m /fl4 /flp4':Verbosity=minimal;Encoding=ASCII;logfile=dist/build32.log' renderdoc.sln /t:Rebuild /p:'Configuration=Release;Platform=x86'

if [ ! -f ./Win32/Release/renderdoc.dll ] || [ ! -f ./Win32/Release/qrenderdoc.exe ] || [ ! -f ./Win32/Release/renderdoccmd.exe ] ; then
	echo "Failed to build 32-bit release mode.";
	exit 1;
fi

# Build 64-bit Release
MSYS2_ARG_CONV_EXCL="*" msbuild.exe /nologo /m /fl4 /flp4':Verbosity=minimal;Encoding=ASCII;logfile=dist/build64.log' renderdoc.sln /t:Rebuild /p:'Configuration=Release;Platform=x64'

if [ ! -f ./x64/Release/renderdoc.dll ] || [ ! -f ./x64/Release/qrenderdoc.exe ] || [ ! -f ./x64/Release/renderdoccmd.exe ] ; then
	echo "Failed to build 64-bit release mode.";
	exit 1;
fi

# Step into the docs folder and build
pushd docs
./make.sh clean
./make.sh htmlhelp

popd; # docs

# if we didn't produce a chm file, bail out even if sphinx didn't return an error code above
if [ ! -f ./Documentation/htmlhelp/renderdoc.chm ]; then
	echo "Didn't auto-build chm file. Missing HTML Help Workshop?"

	if [[ "$STRICT" == "yes" ]]; then
		echo "Strict mode: Fail to build CHM help file.";
		exit 1;
	fi
fi

# Transform ANDROID_SDK / ANDROID_NDK to native paths if needed
# 检查是否是 Windows 路径格式 (C:\path 或 /c/path)
if echo "${ANDROID_SDK}" | grep -q "^/c/"; then
	# 已经是 MSYS2 格式，保持不变
	echo "ANDROID_SDK already in MSYS2 format: ${ANDROID_SDK}"
elif echo "${ANDROID_SDK}" | grep -q "^[A-Za-z]:"; then
	# Windows 格式，转换为 MSYS2 格式
	ANDROID_SDK=$(echo "${ANDROID_SDK}" | sed -e 's#^\([A-Za-z]\):#/\L\1#' | tr '\\' '/')
	echo "Converted ANDROID_SDK to MSYS2 format: ${ANDROID_SDK}"
	export ANDROID_SDK
fi

if echo "${ANDROID_NDK}" | grep -q "^/c/"; then
	# 已经是 MSYS2 格式，保持不变
	echo "ANDROID_NDK already in MSYS2 format: ${ANDROID_NDK}"
elif echo "${ANDROID_NDK}" | grep -q "^[A-Za-z]:"; then
	# Windows 格式，转换为 MSYS2 格式
	ANDROID_NDK=$(echo "${ANDROID_NDK}" | sed -e 's#^\([A-Za-z]\):#/\L\1#' | tr '\\' '/')
	echo "Converted ANDROID_NDK to MSYS2 format: ${ANDROID_NDK}"
	export ANDROID_NDK
fi

export PATH=$PATH:"${ANDROID_SDK}/platform-tools":"${ANDROID_SDK}/tools":"${ANDROID_SDK}/tools/bin"

# Check that we're set up to build for android
# 检查 platform-tools 或 tools 目录是否存在
if [ ! -d "${ANDROID_SDK}/platform-tools" ] && [ ! -d "${ANDROID_SDK}/tools" ] ; then
	echo "\$ANDROID_SDK is not correctly configured: '$ANDROID_SDK'"
	echo "Expected to find platform-tools or tools directory"

	if [[ "$STRICT" == "yes" ]]; then
		echo "Strict mode: Fail to build Android.";
		exit 1;
	fi

	# Don't return an error code, consider android errors non-fatal
	exit 0;
fi

if ! which cmake > /dev/null 2>&1; then
	echo "Don't have cmake, can't build android";

	if [[ "$STRICT" == "yes" ]]; then
		echo "Strict mode: Fail to build Android.";
		exit 1;
	fi

	exit 0;
fi

if ! which make > /dev/null 2>&1; then
	echo "Don't have make, can't build android";

	if [[ "$STRICT" == "yes" ]]; then
		echo "Strict mode: Fail to build Android.";
		exit 1;
	fi

	exit 0;
fi

if [ ! -d $LLVM_ARM32 ] || [ ! -d $LLVM_ARM64 ] ; then
	echo "llvm is not available, expected $LLVM_ARM32 and $LLVM_ARM64 respectively."
	echo "Building Android APK without interceptor-lib (using PLT-interception method)"
	USE_INTERCEPTOR_LIB=Off
	LLVM_CMAKE_ARGS=""

	if [[ "$STRICT" == "yes" ]]; then
		echo "Strict mode: Fail to build Android without LLVM.";
		exit 1;
	fi
else
	echo "LLVM found, building with interceptor-lib support"
	USE_INTERCEPTOR_LIB=On
	LLVM_CMAKE_ARGS_ARM32="-DLLVM_DIR=$LLVM_ARM32/lib/cmake/llvm"
	LLVM_CMAKE_ARGS_ARM64="-DLLVM_DIR=$LLVM_ARM64/lib/cmake/llvm"
fi

GENERATOR="Unix Makefiles"

if uname -a | grep -iq msys; then
	GENERATOR="MSYS Makefiles"
fi

AAPT=$(ls $ANDROID_SDK/build-tools/*/aapt{,.exe} 2>/dev/null | tail -n 1)

# Check to see if we already have this built, and don't rebuild
VERSION32=$($AAPT dump badging build-android-arm32/bin/*apk 2>/dev/null | grep -Eo "versionName='[0-9a-f]*'" | grep -Eo "'.*'" | tr -d "'")
VERSION64=$($AAPT dump badging build-android-arm64/bin/*apk 2>/dev/null | grep -Eo "versionName='[0-9a-f]*'" | grep -Eo "'.*'" | tr -d "'")

if [ "$VERSION32" == "$GITHASH" ]; then

	echo "Found existing compatible arm32 build at $GITHASH, not rebuilding";

else

	echo "Rebuilding as existing build is $VERSION32";

	# Build the arm32 variant
	rm -rf build-android-arm32
	mkdir -p build-android-arm32
	pushd build-android-arm32

	if [ "$USE_INTERCEPTOR_LIB" == "On" ]; then
		cmake -G "${GENERATOR}" -DBUILD_ANDROID=1 -DANDROID_ABI=armeabi-v7a -DANDROID_NATIVE_API_LEVEL=26 -DCMAKE_BUILD_TYPE=Release -DSTRIP_ANDROID_LIBRARY=On $LLVM_CMAKE_ARGS_ARM32 -DUSE_INTERCEPTOR_LIB=On ..
	else
		cmake -G "${GENERATOR}" -DBUILD_ANDROID=1 -DANDROID_ABI=armeabi-v7a -DANDROID_NATIVE_API_LEVEL=26 -DCMAKE_BUILD_TYPE=Release -DSTRIP_ANDROID_LIBRARY=On -DUSE_INTERCEPTOR_LIB=Off ..
	fi
	make -j$(nproc)

	if ! ls bin/*.apk; then
		echo "Android build failed"

		if [[ "$STRICT" == "yes" ]]; then
			echo "Strict mode: Fail to build Android.";
			exit 1;
		fi
	fi

	popd # build-android-arm32

fi

if [ "$VERSION64" == "$GITHASH" ]; then

	echo "Found existing compatible arm64 build at $GITHASH, not rebuilding";

else

	echo "Rebuilding as existing build is $VERSION64";

	rm -rf build-android-arm64
	mkdir -p build-android-arm64
	pushd build-android-arm64

	if [ "$USE_INTERCEPTOR_LIB" == "On" ]; then
		cmake -G "${GENERATOR}" -DBUILD_ANDROID=1 -DANDROID_ABI=arm64-v8a -DANDROID_NATIVE_API_LEVEL=26 -DCMAKE_BUILD_TYPE=Release -DSTRIP_ANDROID_LIBRARY=On $LLVM_CMAKE_ARGS_ARM64 -DUSE_INTERCEPTOR_LIB=On ..
	else
		cmake -G "${GENERATOR}" -DBUILD_ANDROID=1 -DANDROID_ABI=arm64-v8a -DANDROID_NATIVE_API_LEVEL=26 -DCMAKE_BUILD_TYPE=Release -DSTRIP_ANDROID_LIBRARY=On -DUSE_INTERCEPTOR_LIB=Off ..
	fi
	make -j$(nproc)

	if ! ls bin/*.apk; then
		echo "Android build failed"

		if [[ "$STRICT" == "yes" ]]; then
			echo "Strict mode: Fail to build Android.";
			exit 1;
		fi
	fi

	popd # build-android-arm64

fi

popd # $REPO_ROOT

