#!/bin/bash

set -e

[ ! -z "$LFS" ]

#  改变所有者 
# 目前，$LFS 中整个目录树的所有者都是 lfs，这个用户只在宿主系统存在。如果不改变 $LFS 中文件和目录的所有权，
# 它们会被一个没有对应账户的用户 ID 所有。这是危险的，因为后续创建的新用户可能获得这个用户 ID，并成为 $LFS 中全部文件的所有者，从而产生恶意操作这些文件的可能。
# 为了避免这样的问题，执行以下命令，将 $LFS/* 目录的所有者改变为 root：
sudo chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) sudo chown -R root:root $LFS/lib64 ;;
esac

# 准备虚拟内核文件系统
# 内核对外提供了一些文件系统，以便自己和用户空间进行通信。它们是虚拟文件系统，并不占用磁盘空间，其内容保留在内存中。
# 首先创建这些文件系统的挂载点：
sudo mkdir -pv $LFS/{dev,proc,sys,run}
# 创建初始设备节点
# 在内核引导系统时，它需要一些设备节点，特别是 console 和 null 两个设备。它们需要创建在硬盘上，这样在内核填
# 充 /dev 前，或者 Linux 使用 init=/bin/bash 内核选项启动时，也能使用它们。运行以下命令创建它们：
sudo mknod -m 600 $LFS/dev/console c 5 1
sudo mknod -m 666 $LFS/dev/null c 1 3
# 挂载和填充 /dev
# 用设备文件填充 /dev 目录的推荐方法是挂载一个虚拟文件系统 (例如 tmpfs) 到 /dev，然后在设备被发现或访问时动态地
# 创建设备文件。这个工作通常由 Udev 在系统引导时完成。然而，我们的新系统还没有 Udev，也没有被引导过，因此必须手工
# 挂载和填充 /dev。这可以通过绑定挂载宿主系统的 /dev 目录就实现。绑定挂载是一种特殊挂载类型，它允许在另外的位置创
# 建某个目录或挂载点的映像。运行以下命令进行绑定挂载：
sudo mount -v --bind /dev $LFS/dev
# 挂载其余的虚拟内核文件系统：
sudo mount -v --bind /dev/pts $LFS/dev/pts
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run
# 在某些宿主系统上，/dev/shm 是一个指向 /run/shm 的符号链接。我们已经在 /run 下挂载了 tmpfs 文件系统，因此在这
# 里只需要创建一个目录。
if [ -h $LFS/dev/shm ]; then
  sudo mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# 进入 Chroot 环境并完成剩余临时工具的安装. 在安装最终的系统时，会继续使用这个 chroot 环境。
# 以 root 用户身份，运行以下命令以进入当前只包含临时工具的 chroot 环境：
#
# 通过传递 -i 选项给 env 命令，可以清除 chroot 环境中的所有环境变量。随后，只重新设定 HOME，TERM，PS1，以及 
# PATH 变量。参数 TERM=$TERM 将 chroot 环境中的 TERM 变量设为和 chroot 环境外相同的值。一些程序需要这个变量才
# 能正常工作，例如 vim 和 less。如果需要设定其他变量，例如 CFLAGS 或 CXXFLAGS，也可以在这里设定。
#
# +h 命令关闭 bash 的散列功能。与前文的.baserc中的 set +h 作用相同.
# 注意 /tools/bin 不在 PATH 中。这意味着交叉工具链在 chroot 环境中不被再使用。这还需要保证 shell 不“记忆”执行过
# 的程序的位置 —— 因此需要传递 +h 参数给 bash 以关闭散列功能。
sudo cp -rvf lfs_run_*.sh "$LFS"/
sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    /bin/bash +h lfs_run_02_01.sh 

# 手工执行
sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    /bin/bash --login +h
# 手工执行 bash lfs_run_02.sh
