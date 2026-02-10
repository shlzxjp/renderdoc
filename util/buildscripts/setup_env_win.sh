#!/bin/bash
# ============================================================
# RenderDoc Windows 构建环境配置脚本
# 使用方法: source setup_env_win.sh
# ============================================================

echo "=========================================="
echo "RenderDoc Windows 构建环境配置"
echo "=========================================="

# ============================================================
# 1. WiX Toolset 配置
# ============================================================
# 根据实际安装路径修改
if [ -d "/c/Program Files (x86)/WiX Toolset v3.14" ]; then
    export WIX="/c/Program Files (x86)/WiX Toolset v3.14"
elif [ -d "/c/Program Files (x86)/WiX Toolset v3.11" ]; then
    export WIX="/c/Program Files (x86)/WiX Toolset v3.11"
else
    echo "警告: 未找到 WiX Toolset，请手动设置 WIX 环境变量"
fi

# ============================================================
# 2. Visual Studio / MSBuild 配置
# ============================================================
# 按优先级查找 MSBuild
MSBUILD_PATHS=(
    "/c/Program Files/Microsoft Visual Studio/2022/Professional/MSBuild/Current/Bin"
    "/c/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin"
    "/c/Program Files/Microsoft Visual Studio/2022/Enterprise/MSBuild/Current/Bin"
    "/c/Program Files (x86)/Microsoft Visual Studio/2019/Professional/MSBuild/Current/Bin"
    "/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/Bin"
    "/c/Program Files (x86)/Microsoft Visual Studio/2019/Enterprise/MSBuild/Current/Bin"
)

MSBUILD_FOUND=false
for mspath in "${MSBUILD_PATHS[@]}"; do
    if [ -f "$mspath/MSBuild.exe" ]; then
        export PATH="$mspath:$PATH"
        MSBUILD_FOUND=true
        echo "MSBuild 路径: $mspath"
        break
    fi
done

if [ "$MSBUILD_FOUND" = false ]; then
    echo "警告: 未找到 MSBuild，请确保已安装 Visual Studio"
fi

# ============================================================
# 3. HTML Help Workshop 配置（可选，用于生成 CHM 文档）
# ============================================================
if [ -d "/c/Program Files (x86)/HTML Help Workshop" ]; then
    export PATH="/c/Program Files (x86)/HTML Help Workshop:$PATH"
    echo "HTML Help Workshop: 已配置"
else
    echo "提示: 未找到 HTML Help Workshop，将跳过 CHM 文档生成"
fi

# ============================================================
# 4. Qt 配置（如果需要手动指定）
# ============================================================
# 取消注释并修改以下行以手动配置 Qt
# export QTDIR="/c/Qt/5.15.2/msvc2019_64"
# export PATH="$QTDIR/bin:$PATH"

# ============================================================
# 5. Python 配置（RenderDoc 需要 Python 3.6）
# ============================================================
# 动态获取当前用户名（从 MSYS2 继承的 Windows 环境变量中获取）
WIN_USERNAME="${USERNAME:-${USER:-}}"
if [ -z "$WIN_USERNAME" ]; then
    WIN_USERNAME=$(whoami | sed 's/.*\\//')
fi
if [ -z "$WIN_USERNAME" ]; then
    echo "错误: 无法获取当前 Windows 用户名，请手动配置 Python 和 Android SDK 路径"
fi

PYTHON36_PATH="/c/Users/$WIN_USERNAME/AppData/Local/Programs/Python/Python36"
if [ -d "$PYTHON36_PATH" ]; then
    export PATH="$PYTHON36_PATH:$PATH"
    export PATH="$PYTHON36_PATH/Scripts:$PATH"
    echo "Python 3.6 路径: $PYTHON36_PATH"
else
    echo "警告: 未找到 Python 3.6，路径不存在: $PYTHON36_PATH"
    echo "  请确保已安装 Python 3.6 到默认位置，或手动设置 PATH"
fi

# ============================================================
# 6. Android SDK/NDK 配置（用于 Android 支持）
# ============================================================
# Android SDK 和 NDK 配置（动态获取用户路径）
ANDROID_SDK_PATH="/c/Users/$WIN_USERNAME/AppData/Local/Android/Sdk"
if [ -d "$ANDROID_SDK_PATH" ]; then
    export ANDROID_SDK="$ANDROID_SDK_PATH"
    echo "Android SDK 路径: $ANDROID_SDK"
else
    echo "警告: 未找到 Android SDK，路径不存在: $ANDROID_SDK_PATH"
    echo "  请确保已安装 Android SDK，或手动设置 ANDROID_SDK 环境变量"
fi

# NDK 必须使用 16.1.4479499 版本，其他版本会导致编译问题
REQUIRED_NDK_VERSION="16.1.4479499"
ANDROID_NDK_PATH="$ANDROID_SDK_PATH/ndk/$REQUIRED_NDK_VERSION"
if [ -d "$ANDROID_NDK_PATH" ]; then
    export ANDROID_NDK="$ANDROID_NDK_PATH"
    echo "Android NDK 路径: $ANDROID_NDK"
else
    echo "错误: 未找到指定版本的 Android NDK，路径不存在: $ANDROID_NDK_PATH"
    echo "  RenderDoc 必须使用 NDK $REQUIRED_NDK_VERSION，其他版本会导致编译问题"
    echo "  请通过 SDK Manager 安装该版本: sdkmanager \"ndk;$REQUIRED_NDK_VERSION\""
fi

export ANDROID_NDK_HOME="$ANDROID_NDK"
export ANDROID_NDK_ROOT="$ANDROID_NDK"
export NDK_HOME="$ANDROID_NDK"
export JAVA_HOME="/c/Program Files/Java/jdk-11"

# 添加 Android 工具到 PATH
if [ -d "$ANDROID_SDK/platform-tools" ]; then
    export PATH="$ANDROID_SDK/platform-tools:$PATH"
fi

if [ -d "$ANDROID_SDK/tools" ]; then
    export PATH="$ANDROID_SDK/tools:$PATH"
fi

if [ -d "$ANDROID_SDK/tools/bin" ]; then
    export PATH="$ANDROID_SDK/tools/bin:$PATH"
fi

# 新版 SDK 使用 cmdline-tools 替代 tools
if [ -d "$ANDROID_SDK/cmdline-tools/latest/bin" ]; then
    export PATH="$ANDROID_SDK/cmdline-tools/latest/bin:$PATH"
elif [ -d "$ANDROID_SDK/cmdline-tools/bin" ]; then
    export PATH="$ANDROID_SDK/cmdline-tools/bin:$PATH"
fi

# ============================================================
# 7. Java 配置（用于 Android 构建）
# ============================================================
# 自动检测 Java 安装 - 优先使用 Java 11+
JAVA_PATHS=(
    "/c/Program Files/Java/jdk-11"
    "/c/Program Files/Java/jdk-17"
    "/c/Program Files/OpenJDK/jdk-17"
    "/c/Program Files/OpenJDK/jdk-11"
    "/c/Program Files/Java/jdk-8"
    "/c/Program Files/Java/jdk1.8.0_*"
    "/c/Program Files/OpenJDK/jdk-8"
    "/c/Program Files (x86)/Java/jdk1.8.0_*"
)

if [ -z "$JAVA_HOME" ]; then
    for java_path in "${JAVA_PATHS[@]}"; do
        # 处理通配符路径
        for expanded_path in $java_path; do
            if [ -d "$expanded_path" ] && [ -f "$expanded_path/bin/javac" -o -f "$expanded_path/bin/javac.exe" ]; then
                export JAVA_HOME="$expanded_path"
                echo "自动检测到 Java: $JAVA_HOME"
                break 2
            fi
        done
    done
fi

# 如果仍然没有找到 JAVA_HOME，给出提示
if [ -z "$JAVA_HOME" ]; then
    echo "警告: 未找到 Java JDK，请手动设置 JAVA_HOME 环境变量"
    echo "建议安装 JDK 8 或 JDK 11 用于 Android 开发"
fi

# 添加 Java 到 PATH
if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME/bin" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

# ============================================================
# 验证配置
# ============================================================
echo ""
echo "=========================================="
echo "环境检查结果"
echo "=========================================="

echo -n "WiX Toolset: "
if [ -n "$WIX" ] && [ -f "$WIX/bin/candle.exe" ]; then
    echo "OK ($WIX)"
else
    echo "未配置或路径错误"
fi

echo -n "MSBuild: "
if which msbuild.exe > /dev/null 2>&1; then
    echo "OK ($(which msbuild.exe))"
else
    echo "未找到"
fi

echo -n "Git: "
if which git > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到 (pacman -S git)"
fi

echo -n "Zip: "
if which zip > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到 (pacman -S zip)"
fi

echo -n "CMake: "
if which cmake > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到 (pacman -S cmake)"
fi

echo -n "Make: "
if which make > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到 (pacman -S make)"
fi

echo -n "Sphinx: "
if which sphinx-build > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到 (pip install sphinx sphinx_rtd_theme)"
fi

echo -n "HTML Help Compiler: "
if which hhc > /dev/null 2>&1; then
    echo "OK"
else
    echo "未找到"
fi

echo -n "Android SDK: "
if [ -n "$ANDROID_SDK" ] && [ -d "$ANDROID_SDK" ]; then
    echo "OK ($ANDROID_SDK)"
    
    # 检查 Android SDK 子目录
    echo "  Android SDK 组件检查:"
    if [ -d "$ANDROID_SDK/platform-tools" ]; then
        echo "    platform-tools: OK"
    else
        echo "    platform-tools: 未找到"
    fi
    
    if [ -d "$ANDROID_SDK/build-tools" ]; then
        BUILD_TOOLS_COUNT=$(ls -1 "$ANDROID_SDK/build-tools" 2>/dev/null | wc -l)
        if [ "$BUILD_TOOLS_COUNT" -gt 0 ]; then
            LATEST_BUILD_TOOLS=$(ls -1 "$ANDROID_SDK/build-tools" | tail -n 1)
            echo "    build-tools: OK (最新版本: $LATEST_BUILD_TOOLS)"
        else
            echo "    build-tools: 目录为空"
        fi
    else
        echo "    build-tools: 未找到"
    fi
    
    if [ -d "$ANDROID_SDK/tools" ]; then
        echo "    tools: OK"
    else
        echo "    tools: 未找到 (已弃用，可忽略)"
    fi
else
    echo "未配置或路径错误"
fi

echo -n "Android NDK: "
if [ -n "$ANDROID_NDK" ] && [ -d "$ANDROID_NDK" ]; then
    echo "OK ($ANDROID_NDK)"
    
    # 检查 NDK 版本和结构
    echo "  Android NDK 组件检查:"
    if [ -f "$ANDROID_NDK/source.properties" ]; then
        NDK_VERSION=$(grep "Pkg.Revision" "$ANDROID_NDK/source.properties" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$NDK_VERSION" ]; then
            echo "    版本: $NDK_VERSION"
        fi
    fi
    
    if [ -d "$ANDROID_NDK/build/cmake" ] && [ -f "$ANDROID_NDK/build/cmake/android.toolchain.cmake" ]; then
        echo "    CMake 工具链: OK (现代 NDK)"
    elif [ -d "$ANDROID_NDK/build/core" ]; then
        echo "    构建系统: OK (旧版 NDK)"
    else
        echo "    构建系统: 未找到有效的构建系统"
    fi
    
    if [ -d "$ANDROID_NDK/toolchains" ]; then
        TOOLCHAIN_COUNT=$(ls -1 "$ANDROID_NDK/toolchains" 2>/dev/null | wc -l)
        echo "    工具链数量: $TOOLCHAIN_COUNT"
    fi
else
    echo "未配置或路径错误"
fi

echo -n "Java (JAVA_HOME): "
if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME" ]; then
    echo "OK ($JAVA_HOME)"
    
    # 检查 Java 版本和工具
    echo "  Java 环境检查:"
    if [ -f "$JAVA_HOME/bin/java" ] || [ -f "$JAVA_HOME/bin/java.exe" ]; then
        JAVA_VERSION=$("$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | cut -d'"' -f2)
        echo "    Java 版本: $JAVA_VERSION"
        
        # 检查Java版本是否适合Android构建
        JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION" | cut -d'.' -f1)
        if [ "$JAVA_MAJOR_VERSION" -ge 11 ] 2>/dev/null || [[ "$JAVA_VERSION" == 1.8* && "$JAVA_MAJOR_VERSION" -ge 8 ]] 2>/dev/null; then
            if [ "$JAVA_MAJOR_VERSION" -ge 11 ] 2>/dev/null; then
                echo "    Android构建兼容性: ✓ 推荐 (Java 11+)"
            else
                echo "    Android构建兼容性: ⚠ 可能不兼容 (需要Java 11+，当前是Java 8)"
                echo "    建议: 安装Java 11或更高版本用于Android构建"
            fi
        else
            echo "    Android构建兼容性: ✗ 不兼容 (需要Java 11+)"
        fi
    fi
    
    if [ -f "$JAVA_HOME/bin/javac" ] || [ -f "$JAVA_HOME/bin/javac.exe" ]; then
        echo "    javac: OK"
    else
        echo "    javac: 未找到"
    fi
    
    if [ -f "$JAVA_HOME/bin/jar" ] || [ -f "$JAVA_HOME/bin/jar.exe" ]; then
        echo "    jar: OK"
    else
        echo "    jar: 未找到"
    fi
else
    echo "未配置或路径错误"
    # 尝试检测系统 Java
    if which java > /dev/null 2>&1; then
        SYSTEM_JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        echo "  系统 Java: $SYSTEM_JAVA_VERSION (建议设置 JAVA_HOME)"
    fi
fi

echo ""
echo "=========================================="
echo "环境配置完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 下载 plugins: curl -LO https://renderdoc.org/plugins.zip && unzip plugins.zip"
echo "  2. 构建： ./util/buildscripts/build.sh --snapshot libpag"
echo ""
