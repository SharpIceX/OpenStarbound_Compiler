#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" # 当前目录
steam_StarboundDirectory="$HOME/.local/share/Steam/steamapps/common/Starbound/" # Steam 上 Starbound 的安装目录

# # 仓库依赖
deps_OpenStarbound=(
    "https://github.com/OpenStarbound/OpenStarbound.git"
    "038a8d4eab64fc87f78131224ea712a459eaf4e7"
    "$SCRIPT_DIR/source/OpenStarbound"
)

deps_StarboundChineseMod=(
    "https://github.com/sffxzzp/Starbound-Chinese.git"
    "UTC-241105-1953"
    "$SCRIPT_DIR/source/Starbound-Chinese"
)

deps_AvaliMod=(
    "https://github.com/Avali-Triage-Team/Avali.git"
    "0c1f8ac51e00a08be76556a0519a3aec11a31e3e"
    "$SCRIPT_DIR/source/Avali"
)

deps_AvaliModChineseMod=(
    "https://github.com/Catoverflow/Avali-Triage-zh-CN-Patch.git"
    "a266b0ae55f45b782e48d3f3df454ba0c99bf3a2"
    "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch"
)

# # 加载系统的 makepkg 配置
# shellcheck disable=SC1091
[[ -f /etc/makepkg.conf ]] && source "/etc/makepkg.conf"
if [[ -d /etc/makepkg.conf.d ]]; then
    for conf in /etc/makepkg.conf.d/*.conf; do
        # shellcheck disable=SC1090
        [[ -f "$conf" ]] && source "$conf"
    done
fi

# # 加载用户的 makepkg 配置
USER_PACMAN_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf"
if [[ -f "$USER_PACMAN_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$USER_PACMAN_CONF"
fi

sync_repo() {
    local repo_url="$1"
    local version="$2"
    local repo_path="$3"

    echo ">>> 正在同步：$repo_url @ $version"

    if [[ ! -d "$repo_path/.git" ]]; then
		echo ">>>> 初始化：$repo_path"

        rm -rf "$repo_path"
		mkdir -p "$(dirname "$repo_path")"
        git init "$repo_path" --quiet
        git -C "$repo_path" remote add origin "$repo_url"
    fi

	# 清理
    git -C "$repo_path" clean -ffdx --quiet
    git -C "$repo_path" reset --hard HEAD --quiet 2>/dev/null || true

	# 同步
    git -C "$repo_path" fetch origin "$version" --quiet || { echo "错误：无法获取版本 $version"; exit 1; }
    git -C "$repo_path" reset --hard FETCH_HEAD --quiet || { echo "错误：重置失败"; exit 1; }

    # 回收
    git -C "$repo_path" gc --prune=now --quiet
}

pack_asset() {
    local src="$1"
    local dst="$2"
    local packer="$SCRIPT_DIR/dist/linux/asset_packer"

    [[ -x "$packer" ]] || { echo "错误：找不到「$packer」打包工具"; exit 1; }

    [[ -d "$src" ]] || { echo "错误：「$src」目录不存在"; exit 1; }

    "$packer" "$src" "$dst" || { echo "错误：「$src」打包失败"; exit 1; }
}

# 编译参数
TOOLCHAIN_ARGS="--gcc-install-dir=/usr/lib/gcc/x86_64-pc-linux-gnu/14.3.1"

EXTRA_COMPILER_ARGS="-fstrict-vtable-pointers"
DISABLE_ARGS="-Wno-nan-infinity-disabled -Wno-error=incompatible-pointer-types-discards-qualifiers"

export CFLAGS="${CFLAGS:-} ${TOOLCHAIN_ARGS} ${EXTRA_COMPILER_ARGS} ${DISABLE_ARGS}"
export CXXFLAGS="${CXXFLAGS:-} ${TOOLCHAIN_ARGS} ${EXTRA_COMPILER_ARGS} ${DISABLE_ARGS} -std=c++20 -D_GLIBCXX_USE_CXX11_ABI=1"
export LDFLAGS="${LDFLAGS:-} ${TOOLCHAIN_ARGS} -Wl,--gc-sections -Wl,--icf=all"

# VcPkg
export VCPKG_FORCE_SYSTEM_BINARIES=1
export VCPKG_KEEP_ENV_VARS="CFLAGS;CXXFLAGS;LDFLAGS"

NPROC=${NPROC:-$(nproc)}

echo "> 同步存储库..."
sync_repo "${deps_AvaliMod[@]}"
sync_repo "${deps_OpenStarbound[@]}"
sync_repo "${deps_StarboundChineseMod[@]}"
sync_repo "${deps_AvaliModChineseMod[@]}"

echo "> 清理先前的编译结果"
rm -rf "$SCRIPT_DIR"/{obj,dist}

# # 创建目录
mkdir -p "$SCRIPT_DIR/dist/"{linux,modules}

echo "> 初始化 OpenStarbound 构建配置"
CMAKE_OPTS=(
    --preset "linux-release-clang"
    -S "$SCRIPT_DIR/source/OpenStarbound/source"
    -B "$SCRIPT_DIR/obj/OpenStarbound"
    -DCMAKE_C_FLAGS="$CFLAGS"
    -DCMAKE_CXX_FLAGS="$CXXFLAGS"
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
	-DCMAKE_C_COMPILER_LAUNCHER="ccache"
	-DCMAKE_CXX_COMPILER_LAUNCHER="ccache"
    -DCMAKE_VERBOSE_MAKEFILE=OFF
)
cmake "${CMAKE_OPTS[@]}"

echo ">编译 OpenStarbound 使用「$NPROC」核心"
export LDFLAGS="$LDFLAGS -lmimalloc"
cmake --build "$SCRIPT_DIR/obj/OpenStarbound" --config Release --parallel "$NPROC"

echo "> 复制 OpenStarbound 编译产物"
cp -r "$SCRIPT_DIR/source/OpenStarbound/dist/"* "$SCRIPT_DIR/dist/linux/"
cp "$SCRIPT_DIR/source/OpenStarbound/lib/linux/"*.so "$SCRIPT_DIR/dist/linux/"
cp "$SCRIPT_DIR/source/OpenStarbound/scripts/steam_appid.txt" "$SCRIPT_DIR/dist/linux/"
cp -r "$steam_StarboundDirectory/assets/" "$SCRIPT_DIR/dist/" # 运行时资源
cp -r "$SCRIPT_DIR/assets/"* "$SCRIPT_DIR/dist/" # Steam 上的游戏资源

# 设置权限
chmod +x "$SCRIPT_DIR/dist/linux/starbound"
chmod +x "$SCRIPT_DIR/dist/linux/asset_packer"

# 打包资源
echo "> 打包游戏模块"
pack_asset "$SCRIPT_DIR/source/Avali" 						"$SCRIPT_DIR/dist/modules/Avali.pak"
pack_asset "$SCRIPT_DIR/source/OpenStarbound/assets/opensb" "$SCRIPT_DIR/dist/assets/opensb.pak"
pack_asset "$SCRIPT_DIR/source/Starbound-Chinese" 			"$SCRIPT_DIR/dist/modules/Starbound-Chinese.pak"
pack_asset "$SCRIPT_DIR/source/Avali-Triage-zh-CN-Patch" 	"$SCRIPT_DIR/dist/modules/Avali-Triage-zh-CN-Patch.pak"

echo "> 清理中间结果"
rm -rf "$SCRIPT_DIR/obj" || true

echo "> 完成 <"
