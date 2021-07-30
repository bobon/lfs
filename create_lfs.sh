#!/bin/bash

set -e

# 为了配置一个良好的工作环境，我们为 bash 创建两个新的启动脚本。以 lfs 的身份，执行以下命令，创建一个新的 .bash_profile：
# 在以 lfs 用户登录时，初始的 shell 一般是一个登录 shell。它读取宿主系统的 /etc/profile 文件 (可能包含一些设置和环境变量)，然后读取 .bash_profile。
# 我们在 .bash_profile 中使用 exec env -i.../bin/bash 命令，新建一个除了 HOME, TERM 以及 PS1 外没有任何环境变量的 shell，替换当前 shell，
# 防止宿主环境中不必要和有潜在风险的环境变量进入编译环境。通过使用以上技巧，我们创建了一个干净环境。 
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
# 新的 shell 实例是 非登录 shell，它不会读取和执行 /etc/profile 或者 .bash_profile 的内容，而是读取并执行 .bashrc 文件。
# 现在我们就创建一个 .bashrc 文件：
#
# +h 命令关闭 bash 的散列功能。一般情况下，散列是很有用的 —— bash 使用一个散列表维护各个可执行文件的完整路径，
# 这样就不用每次都在 PATH 指定的目录中搜索可执行文件。然而，在构建 LFS 时，我们希望总是使用最新安装的工具。
# 因此，需要关闭散列功能，使得 shell 在运行程序时总是搜索 PATH。这样，shell 总是能够找到 $LFS/tools 目录中那些最
# 新编译的工具，而不是使用之前记忆的另一个目录中的程序。
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

#  一些商业发行版未做文档说明地将 /etc/bash.bashrc 引入 bash 初始化过程。该文件可能修改 lfs 用户的环境，并影响 LFS 关键软件包的构建。为了保证 lfs 用户环境的纯净，检查 /etc/bash.bashrc 是否存在，如果它存在就将它移走。以 root 用户身份，运行：
# 后续可以复原 /etc/bash.bashrc 文件
[ ! -e /etc/bash.bashrc ] || sudo mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
# 为了完全准备好编译临时工具的环境，指示 shell 读取刚才创建的配置文件：
#source ~/.bash_profile
