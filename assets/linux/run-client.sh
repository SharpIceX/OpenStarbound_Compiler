#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CURRENT_DIR"

# 游戏目前对 Wayland 支持不佳，强制使用 X11
export SDL_VIDEODRIVER=x11

# 优化相关
export MI_OPTION_EAGER_COMMIT=1
export MI_OPTION_LARGE_OS_PAGES=1

./starbound "$@"
