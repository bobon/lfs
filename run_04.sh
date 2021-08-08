#!/bin/bash

set -e

# 如果解除了虚拟内核文件系统的挂载，必须通过手动或重启系统的方式重新挂载它们，保证在进入 chroot 时它们已经挂载好。
# 如果已经挂载好了，则以下命令可以忽略。
sudo -E umount $LFS/dev{/pts,} || true
sudo -E umount $LFS/{sys,proc,run} || true
sudo mount -v --bind /dev $LFS/dev
sudo mount -v --bind /dev/pts $LFS/dev/pts
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run

# 使用新的 chroot 命令行重新进入 chroot 环境。从现在起，在退出并重新进入 chroot 环境时，要使用下面的修改过的 chroot 命令：
# 这里不再使用 +h 选项，因为所有之前安装的程序都已经替换成了最终版本，可以进行散列。 
sudo chroot "$LFS" /usr/bin/env -i          \
    HOME=/root TERM="$TERM"            \
    PS1='(lfs chroot) \u:\w\$ '        \
    PATH=/usr/bin:/usr/sbin            \
    /bin/bash --login

# 手工执行 source lfs_run_04.sh
# 手工执行 source lfs_run_04_01.sh