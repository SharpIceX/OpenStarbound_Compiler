#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CURRENT_DIR"

# 优化相关
export MI_OPTION_EAGER_COMMIT=1
export MI_OPTION_LARGE_OS_PAGES=1

./starbound "$@"
