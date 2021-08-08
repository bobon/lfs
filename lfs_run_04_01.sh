#!/bin/bash

set -e

# 收尾工作
# 创建一个 /etc/lfs-release 文件似乎是一个好主意。通过使用它，您 (或者我们，如果您向我们寻求帮助的话) 能够容易地找出当前安装的 LFS 系统版本。运行以下命令创建该文件：
echo r10.1-124 > /etc/lfs-release
#后续安装在系统上的软件包可能需要两个描述当前安装的系统的文件，这些软件包可能是二进制包，也可能是需要构建的源代码包。
#另外，最好创建一个文件，根据 Linux Standards Base (LSB) 的规则显示系统状态。运行命令创建该文件：
cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="r10.1-124"
DISTRIB_CODENAME="bobon"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF
#第二个文件基本上包含相同的信息，systemd 和一些图形桌面环境会使用它。运行命令创建该文件：
cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="r10.1-124"
ID=lfs
PRETTY_NAME="Linux From Scratch r10.1-124"
VERSION_CODENAME="bobon"
EOF

