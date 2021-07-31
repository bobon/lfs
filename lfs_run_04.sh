#!/bin/bash

set -e

# 在 /usr/lib 和 /usr/libexec 目录中还有一些扩展名为 .la 的文件。它们是 "libtool 档案" 文件。正如我们已经讨论过的，它们在链接到共享库，特别是使用 autotools 以外的构建系统时，是不必要，甚至有害的。执行以下命令删除它们：
find /usr/lib /usr/libexec -name \*.la -delete

# 在第一次和第二次编译时，构建的交叉编译器仍然有一部分安装在系统上，它现在已经没有存在的意义了。执行命令删除它：
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rvf
# 交叉编译器 /tools 也可以被删除，从而获得更多可用空间：
rm -rf /tools
# 最后，移除上一章开始时创建的临时 'tester' 用户账户。
userdel -r tester

