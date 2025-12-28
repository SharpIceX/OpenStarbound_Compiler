#!/usr/bin/env bash

set -euo pipefail

# 版本
OpenStarbound_Version="v0.1.14"
StarboundChinese_Version="UTC-241105-1953"
LxgwWenKai_Version="v1.521"
StarboundDirectory="$HOME/.local/share/Steam/steamapps/common/Starbound/" # Steam 上 Starbound 的安装目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" # 当前目录

# 编译和链接器等
export VCPKG_FORCE_SYSTEM_BINARIES=1
export CC="/usr/bin/clang"
export CXX="/usr/bin/clang++"
export LD="/usr/bin/ld.lld"
export AR="/usr/bin/llvm-ar"
export NM="/usr/bin/llvm-nm"
export RANLIB="/usr/bin/llvm-ranlib"
export OBJCOPY="/usr/bin/llvm-objcopy"
export OBJDUMP="/usr/bin/llvm-objdump"

# 编译参数
export CFLAGS="-O3 -march=native -mtune=native \
  -funroll-loops -fvectorize \
  -ffast-math \
    -fno-finite-math-only \
    -fno-unsafe-math-optimizations \
  -fno-omit-frame-pointer -g3 -gdwarf-5 \
  -fstack-protector-strong \
  -pipe"

export CXXFLAGS="-O3 -march=native -mtune=native \
  -funroll-loops -fvectorize \
  -ffast-math \
    -fno-finite-math-only \
    -fno-unsafe-math-optimizations \
  -fno-omit-frame-pointer -g3 -gdwarf-5 \
  -fstack-protector-strong \
  -D_GLIBCXX_USE_CXX11_ABI=1 \
  -std=c++20 -pipe"

export LDFLAGS="-flto=full -fuse-ld=lld \
  -Wl,--gc-sections \
  -lmimalloc"

echo "清理存储库..."
git -C "$SCRIPT_DIR/source/OpenStarbound" checkout . || true
git -C "$SCRIPT_DIR/source/OpenStarbound" clean -fdx || true

git -C "$SCRIPT_DIR/source/Starbound-Chinese" checkout . || true
git -C "$SCRIPT_DIR/source/Starbound-Chinese" clean -fdx || true

git -C "$SCRIPT_DIR/source/LxgwWenKai" checkout . || true
git -C "$SCRIPT_DIR/source/LxgwWenKai" clean -fdx || true

git -C "$SCRIPT_DIR/source/Avali" checkout . || true
git -C "$SCRIPT_DIR/source/Avali" clean -fdx || true

git -C "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch" checkout . || true
git -C "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch" clean -fdx || true

echo "拉取更新..."
git -C "$SCRIPT_DIR/source/OpenStarbound" fetch --depth=1 origin "$OpenStarbound_Version"
git -C "$SCRIPT_DIR/source/OpenStarbound" reset --hard FETCH_HEAD || true

git -C "$SCRIPT_DIR/source/Starbound-Chinese" fetch --depth=1 origin "$StarboundChinese_Version"
git -C "$SCRIPT_DIR/source/Starbound-Chinese" reset --hard FETCH_HEAD || true

git -C "$SCRIPT_DIR/source/LxgwWenKai" fetch --depth=1 origin "$LxgwWenKai_Version"
git -C "$SCRIPT_DIR/source/LxgwWenKai" reset --hard FETCH_HEAD || true

git -C "$SCRIPT_DIR/source/Avali" fetch --depth=1 origin master
git -C "$SCRIPT_DIR/source/Avali" reset --hard FETCH_HEAD || true

git -C "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch" fetch --depth=1 origin master
git -C "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch" reset --hard FETCH_HEAD || true

echo "清理先前的编译结果..."
rm -rf "$SCRIPT_DIR/obj" || true
rm -rf "$SCRIPT_DIR/dist" || true

# 创建目录
mkdir -p "$SCRIPT_DIR/dist/linux" "$SCRIPT_DIR/dist/modules"

echo "初始化 OpenStarbound 构建配置..."
cmake --preset linux-release-clang \
    -S "$SCRIPT_DIR/source/OpenStarbound/source" \
    -B "$SCRIPT_DIR/obj/OpenStarbound" \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_C_COMPILER_LAUNCHER="/usr/bin/ccache" \
    -DCMAKE_CXX_COMPILER_LAUNCHER="/usr/bin/ccache" \
    -DCMAKE_VERBOSE_MAKEFILE=OFF

echo "编译 OpenStarbound..."
cmake --build "$SCRIPT_DIR/obj/OpenStarbound" --config Release -- -j"$(nproc)"

echo "复制 Starbound 编译结果..."
cp -r "$SCRIPT_DIR/source/OpenStarbound/dist/"* "$SCRIPT_DIR/dist/linux/"
cp "$SCRIPT_DIR/source/OpenStarbound/lib/linux/"*.so "$SCRIPT_DIR/dist/linux/"
cp "$SCRIPT_DIR/source/OpenStarbound/scripts/steam_appid.txt" "$SCRIPT_DIR/dist/linux/"
cp -r "$StarboundDirectory/assets/" "$SCRIPT_DIR/dist/" # 运行时资源
cp -r "$SCRIPT_DIR/assets/"* "$SCRIPT_DIR/dist/" # Steam 上的游戏资源

# 设置权限
chmod +x "$SCRIPT_DIR/dist/linux/starbound"
chmod +x "$SCRIPT_DIR/dist/linux/asset_packer"

echo "打包游戏资源..."
"$SCRIPT_DIR/dist/linux/asset_packer" "$SCRIPT_DIR/source/OpenStarbound/assets/opensb" "$SCRIPT_DIR/dist/assets/opensb.pak"

echo "打包简体中文语言模块..."
mkdir -p "$SCRIPT_DIR/obj/Starbound-Chinese"
cp -r "$SCRIPT_DIR/source/Starbound-Chinese/"* "$SCRIPT_DIR/obj/Starbound-Chinese/"
"$SCRIPT_DIR/dist/linux/asset_packer" "$SCRIPT_DIR/obj/Starbound-Chinese" "$SCRIPT_DIR/dist/modules/Starbound-Chinese.pak"

echo "打包字体模块..."
mkdir -p "$SCRIPT_DIR/obj/fonts/fonts"
cp -r "$SCRIPT_DIR/mods/fonts/"* "$SCRIPT_DIR/obj/fonts/"
woff2_compress "$SCRIPT_DIR/source/LxgwWenKai/fonts/TTF/LXGWWenKai-Medium.ttf"
mv "$SCRIPT_DIR/source/LxgwWenKai/fonts/TTF/LXGWWenKai-Medium.woff2" "$SCRIPT_DIR/obj/fonts/fonts/LXGWWenKai-Medium.woff2"
"$SCRIPT_DIR/dist/linux/asset_packer" "$SCRIPT_DIR/obj/fonts" "$SCRIPT_DIR/dist/modules/Fonts.pak"

echo "打包 Avali 物种模块..."
mkdir -p "$SCRIPT_DIR/obj/Avali"
cp -r "$SCRIPT_DIR/source/Avali/"* "$SCRIPT_DIR/obj/Avali/"
"$SCRIPT_DIR/dist/linux/asset_packer" "$SCRIPT_DIR/obj/Avali" "$SCRIPT_DIR/dist/modules/Avali.pak"

echo "打包 Avali 中文补丁模块..."
mkdir -p "$SCRIPT_DIR/obj/Avali-Triage-zh-CN-Patch"
cp -r "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch/"* "$SCRIPT_DIR/obj/Avali-Triage-zh-CN-Patch/"
"$SCRIPT_DIR/dist/linux/asset_packer" "$SCRIPT_DIR/obj/Avali-Triage-zh-CN-Patch" "$SCRIPT_DIR/dist/modules/Avali-Triage-zh-CN-Patch.pak"

echo  "回收空间..."
git -C "$SCRIPT_DIR/source/OpenStarbound" gc || true
git -C "$SCRIPT_DIR/source/Starbound-Chinese" gc || true
git -C "$SCRIPT_DIR/mods/Avali" gc || true
git -C "$SCRIPT_DIR/mods/Avali-Triage-zh-CN-Patch" gc || true
git -C "$SCRIPT_DIR/source/LxgwWenKai" gc || true
rm -rf "$SCRIPT_DIR/obj" || true
