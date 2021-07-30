#!/bin/bash

set -e


# 从现在开始，就不再需要使用 LFS 环境变量，因为所有工作都被局限在 LFS 文件系统内。这是由于 Bash 被告知 $LFS 现在
# 是根目录 (/)。 
# bash 的提示符会包含 I have no name!。这是正常的，因为现在还没有创建 /etc/passwd 文件。


# 剩余部分的命令都要在 chroot 环境中运行。如果您因为一些原因 (如重新启动计算机) 离开了该环境，必须重新挂载虚拟内核文件系统
# 并重新进入 chroot 环境.

# 在 LFS 文件系统中创建完整的目录结构. 基于FHS标准建立目录树.
# 创建一些位于根目录中的目录，它们不属于之前章节需要的有限目录结构. 下面给出的一些目录已经在之前使用命令创建，
# 或者在安装一些软件包时被创建。这里出于内容完整性的考虑，仍然给出它们。
mkdir -pv /{boot,home,mnt,opt,srv}
#为这些直接位于根目录中的目录创建次级目录结构：
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

# 默认情况下，新创建的目录具有权限模式 755，但这并不适合所有目录。在以上命令中，两个目录的访问权限被修改
# 一个是 root 的主目录，另一个是包含临时文件的目录。
# 第一个修改能保证不是所有人都能进入 /root —— 一般用户也可以为他/她的主目录设置同样的 0750 权限模式。
# 第二个修改保证任何用户都可写入 /tmp 和 /var/tmp 目录，但不能从中删除其他用户的文件，因为所谓
# 的 “粘滞位” (sticky bit)，即八进制权限模式 1777 的最高位 (1) 阻止这样做。 
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
# 以上目录树是基于 Filesystem Hierarchy Standard (FHS) 
# (可以在 https://refspecs.linuxfoundation.org/fhs.shtml 查阅) 建立的。FHS 标准还规定了某些可选的目录，
# 例如 /usr/local/games 和 /usr/share/games。我们只创建了必要的目录。不过，如果您需要的话可以自己创建这些可选目录。 

# 创建必要的文件和符号链接 
# 历史上，Linux 在 /etc/mtab 维护已经挂载的文件系统的列表。现代内核在内部维护该列表，并通过 /proc 文件系统将它展示
# 给用户。为了满足那些需要 /etc/mtab 的工具，执行以下命令，创建符号链接：
rm -rvf /etc/mtab
ln -svf /proc/self/mounts /etc/mtab

# 创建一个基本的 /etc/hosts 文件，一些测试套件，以及 Perl 的一个配置文件将会使用它：
cat > /etc/hosts << EOF
"127.0.0.1 localhost $(hostname)" 
::1        localhost
EOF

# 为了使得 root 能正常登录，而且用户名 “root” 能被正常识别，必须在文件 /etc/passwd 和 /etc/groups 中写入相关的条目。
# 执行以下命令创建 /etc/passwd 文件：
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
# 以后再设置 root 用户的实际密码。 
# 创建 /etc/group 文件：
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
# 这里创建的用户组并不属于任何标准 —— 它们一部分是为了满足后面 Udev 配置的需要，另一部分借鉴了一些 Linux 发行
# 版的通用惯例。另外，某些测试套件需要特定的用户或组。Linux Standard Base
#  (LSB，可以在 http://refspecs.linuxfoundation.org/lsb.shtml 查看) 标准只推荐以组 ID 0 创建用户组 root，
# 以及以组 ID 1 创建用户组 bin，其他组名和组 ID 由系统管理员自由分配，因为好的程序不会依赖组 ID 数字，而是使用组名。

# 后续的一些测试需要使用一个普通用户。我们这里创建一个用户，在那一章的末尾再删除该用户。
echo "tester:x:$(ls -n $(tty) | cut -d" " -f3):101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
# 为了移除 “I have no name!” 提示符，需要打开一个新 shell。由于已经创建了文件 /etc/passwd 和 /etc/group，用户名和组名现在就可以正常解析了：
# 注意这里使用了 +h 参数。它告诉 bash 不要使用内部的路径散列机制。如果没有指定该参数，bash 会记忆它执行过程序的路径。
# 为了在安装新编译好的程序后马上使用它们，在本章和下一章中总是使用 +h。
#exec /bin/bash --login +h
exit
