#!/bin/bash

set -e


# 解除挂载内核虚拟文件系统, 以 root 身份执行. 注意环境变量 LFS 会自动为用户 lfs 设定，但可能没有为 root 设定
# 因此需要指定-E 参数，确保root身份执行命令时有LFS环境变量。
[ ! -z "$LFS" ]
sudo -E umount $LFS/dev{/pts,} || true
sudo -E umount $LFS/{sys,proc,run} || true
# 移除无用内容. 到现在为止，已经构建的可执行文件和库包含大约 90MB 的无用调试符号。
# 从二进制文件移除调试符号： 
# 注意不要对库文件使用 --strip-unneeded 选项。这会损坏静态库，结果工具链软件包都要重新构建。
sudo -E strip --strip-debug $LFS/usr/lib/* || true
sudo -E strip --strip-unneeded $LFS/usr/{,s}bin/* || true
sudo -E strip --strip-unneeded $LFS/tools/bin/* || true
# 备份
# 现在已经建立了必要的工具，可以考虑备份它们。如果对之前构建的软件包进行的各项检查都没有发现问题，即可判定您的临时工具状态良好，可以将它们备份起来供以后重新使用。如果在后续章节发生了无法挽回的错误，通常来说，最好的办法是删除所有东西，然后 (更小心地) 从头开始。不幸的是，这也会删除所有临时工具。为了避免浪费时间对已经构建成功的部分进行返工，可以准备一个备份。 
cd $LFS && sudo -E tar -vcJpf $HOME/lfs-temp-tools-r10.1-121.tar.xz .
# 还原
# 如果您犯下了一些错误，并不得不重新开始构建，您可以使用备份档案还原临时工具，节约一些工作时间。由于源代码在 $LFS 中，它们也包含在备份档案内，因此不需要重新下载它们。在确认 $LFS设定正确后，运行以下命令从备份档案进行还原：
#cd $LFS && sudo -E rm -rf ./* && sudo -E tar -xpf $HOME/lfs-temp-tools-r10.1-121.tar.xz

# 重新挂载挂载内核虚拟文件系统，并重新进入 chroot 环境。
sudo mount -v --bind /dev $LFS/dev
sudo mount -v --bind /dev/pts $LFS/dev/pts
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run
sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    /bin/bash --login +h


#手工执行 source lfs_run_03.sh
