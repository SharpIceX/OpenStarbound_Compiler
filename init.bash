#!/usr/bin/env bash

set -euo pipefail

## 此脚本用于初始化环境，其实就是拉取仓库

git clone https://github.com/OpenStarbound/OpenStarbound.git ./source/OpenStarbound
git clone https://github.com/sffxzzp/Starbound-Chinese.git ./source/Starbound-Chinese
git clone https://github.com/Avali-Triage-Team/Avali.git ./mods/Avali
git clone https://github.com/Catoverflow/Avali-Triage-zh-CN-Patch.git ./mods/Avali-Triage-zh-CN-Patch
git clone https://gitee.com/mirrors/lxgw-wenkai.git ./source/LxgwWenKai --depth=1
