# OpenStarbound 编译脚本

本脚本仅适用于 Linux x86_64 系统，编译和运行需要较新的 CPU（支持 AVX2 指令集）。

在编译前，请确保系统已安装以下依赖（Arch Linux）：

- base-devel
- git
- cmake
- boost
- sdl2
- ninja
- woff2
- ccache（需要已配置，或重构建脚本以移除对 ccache 的依赖）
- vcpkg（需要已配置）

如果您是刚开始编译，请运行`./init.bash`以初始化子模块和下载依赖。

运行`./compiler.bash`以编译 OpenStarbound，第一次编译您需要打开`./compiler.bash`修改顶部变量以适合您的环境。
