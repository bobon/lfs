#!/bin/bash

set -e

# 清理系统
# 在 /usr/lib 和 /usr/libexec 目录中还有一些扩展名为 .la 的文件。它们是 "libtool 档案" 文件。正如我们已经讨论过的，它们在链接到共享库，特别是使用 autotools 以外的构建系统时，是不必要，甚至有害的。执行以下命令删除它们：
find /usr/lib /usr/libexec -name \*.la -delete

# 在第一次和第二次编译时，构建的交叉编译器仍然有一部分安装在系统上，它现在已经没有存在的意义了。执行命令删除它：
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rvf
# 交叉编译器 /tools 也可以被删除，从而获得更多可用空间：
rm -rf /tools
# 最后，移除上一章开始时创建的临时 'tester' 用户账户。
userdel -r tester


# 系统配置
# System V

cd sources
start_tool() {
  local tool_xz=$(ls ${1}*.tar.?z)
  if [ -z "$tool_xz" ]; then 
    local tool_xz=$(ls ${1}*.tar.?z2)
    tar -xf $tool_xz
    cd ${tool_xz:0:-8}
  else
    tar -xf $tool_xz
    cd ${tool_xz:0:-7}
  fi  
}

end_tool() {
  cd ../
  local tool_xz=$(ls ${1}*.tar.?z)
  if [ -z "$tool_xz" ]; then 
    local tool_xz=$(ls ${1}*.tar.?z2)
    rm -rf ${tool_xz:0:-8}
  else 
    rm -rf ${tool_xz:0:-7}
  fi  
}

read_ () {
  #read
  echo
}

install_tools_to_lfs () {
  local pkg_name=$1
  local before=$2
  local conf=$3
  local mk_conf=$4
  local after=$5
  echo "install $pkg_name"

  if [ ! -z "$before" ]; then
    echo "$before"
    read_  
  fi
  local configure_=./configure
  if [ ! -f "$configure_" ]; then local configure_=../configure; local popd_='cd ..'; fi
  echo "$configure_ --prefix=/usr   \
              $conf"
  read_
  echo "make $mk_conf"
  read_
  if [ ! -z "$after" ]; then
    echo "$after"
    read_  
  fi
  
  start_tool $pkg_name 
  echo "prepare compile $pkg_name"
  if [ ! -z "$before" ]; then
    eval "$before"
  fi  
  bash -c "$configure_ --prefix=/usr   \
         $conf"
  echo "compile and install $pkg_name"
  bash -c "make $mk_conf"
  if [ ! -z "$after" ]; then
    bash -c "$after"
  fi
  $popd_
  end_tool $pkg_name
}

# 安装 LFS-Bootscripts. LFS-Bootscripts 软件包包含一组在引导和关机过程中，启动和停止 LFS 系统的脚本。它们的配置文件和自定义引导过程的方法将在后续章节中描述。
start_tool lfs-bootscripts
make install
end_tool lfs-bootscripts


# 设备和模块管理
# 创建 /etc/resolv.conf 文件
# 系统需要某种方式，获取域名服务 (DNS)，以将 Internet 域名解析成 IP 地址，或进行反向解析。为了达到这一目的，最好的方法是将 ISP 或网络管理员提供的 DNS 服务器的 IP 地址写入 /etc/resolv.conf。执行以下命令创建该文件：
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

#domain <您的域名>
nameserver 8.8.8.8
nameserver 8.8.4.4

# End /etc/resolv.conf
EOF

# 配置系统主机名
# 在引导过程中，/etc/hostname 被用于设定系统主机名。
# 执行以下命令，创建 /etc/hostname 文件，并输入一个主机名：
echo "lfs" > /etc/hostname

# 自定义 /etc/hosts 文件
# 选择一个全限定域名 (FQDN) 和可能的别名，以供 /etc/hosts 文件使用。如果使用静态 IP 地址，您还需要确定要使用的 IP 地址。hosts 文件条目的语法是： 
# 执行以下命令，创建 /etc/hosts：
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
#127.0.1.1 <FQDN> <HOSTNAME>
127.0.1.1  lfs
#<192.168.1.1> <FQDN> <HOSTNAME> [alias1] [alias2 ...]
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

# System V 引导脚本使用与配置
# 在内核初始化过程中，如果内核命令行中指定了程序，则会首先运行它，否则默认首先运行 init。这个程序读取初始化文件 /etc/inittab。执行以下命令创建该文件：
cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

# 切换运行级别

# Udev 引导脚本

# 配置系统时钟 
# 执行以下命令，创建新的 /etc/sysconfig/clock 文件：
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

# 配置 Linux 控制台 
# 注意
# /etc/sysconfig/console 文件只控制 Linux 字符控制台的本地化。它和 X 窗口系统，ssh 连接，或者串口终端中的键盘布局设置和终端字体毫无关系。在这些情况下，不存在上述的两项限制。

# 在引导时创建文件. 有时，我们希望在引导时创建一些文件，例如可能需要 /tmp/.ICE-unix 目录。为此，可以在 /etc/sysconfig/createfiles 配置脚本中创建一项。该文件的格式包含在默认配置文件的注释中。

# 配置 sysklogd 脚本
# sysklogd 脚本启动 sysklogd 程序，这是 System V 初始化过程的一部分。-m 0 选项关闭 sysklogd 每 20 分钟写入日志文件的时间戳。如果您希望启用这个周期性时间戳标志，编辑 /etc/sysconfig/rc.site，将 SYSKLOGD_PARMS 定义为您希望的值。例如，如果要删除所有参数，将该变量设定为空：
# SYSKLOGD_PARMS=

# rc.site 文件
# 可选的 /etc/sysconfig/rc.site 文件包含了为每个 System V 引导脚本自动设定的配置。/etc/sysconfig/ 目录中 hostname，console，以及 clock 文件中的变量值也可以在这里设定。如果这些分立的文件和 rc.site 包含相同的变量名，则分立文件中的设定被优先使用。
# rc.site 也包含自定义引导过程其他属性的参数。设定 IPROMPT 变量会启用引导脚本的选择性执行。其他选项在文件注释中描述。

# 自定义引导和关机脚本
# LFS 引导脚本能够较为高效地引导和关闭系统，但是您仍然可以微调 rc.site 文件以进一步提高速度，或根据您的个人品味调整引导消息。为此，需要修改上面给出的/etc/sysconfig/rc.site 文件。 
# 默认配置中，文件系统检查是静默的。这可能看上去像引导过程中的时延。设定变量 VERBOSE_FSCK=y 可以显示 fsck 的输出。 
sed -i '/VERBOSE_FSCK/s,.*VERBOSE_FSCK.*,VERBOSE_FSCK=yes,' /etc/sysconfig/rc.site


# Bash Shell 启动文件 
# Shell 程序 /bin/bash (之后简称 “shell”) 使用一组启动文件，以帮助创建运行环境。每个文件都有专门的用途，它们可能以不同方式影响登录和交互环境。/etc 中的文件提供全局设定。如果在用户主目录中有对应的文件存在，它可能覆盖全局设定。 
# 在成功登录后，/bin/login 读取 /etc/passwd 中的 shell 命令行，启动一个交互式登录 shell。通过命令行 (如 [prompt]$/bin/bash) 启动的 shell 是交互式非登录 shell。非交互 shell 通常在运行 shell 脚本时存在，它处理脚本，在执行命令的过程中不等待用户输入，因此是非交互的。 
# 登录 shell 会读取文件 /etc/profile 和 ~/.bash_profile
cat > /etc/profile << "EOF"
# Begin /etc/profile
export LANG=en_US.UTF-8
export export PATH=/usr/bin:/bin:/usr/sbin:/sbin
# End /etc/profile
EOF

# 创建 /etc/inputrc 文件 
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

# 创建 /etc/shells 文件
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

# 使 LFS 系统可引导
# 创建 /etc/fstab 文件，为新的 LFS 系统构建内核，以及安装 GRUB 引导加载器，使得系统引导时可以选择进入 LFS 系统。 
# 创建 /etc/fstab 文件
# 一些程序使用 /etc/fstab 文件，以确定哪些文件系统是默认挂载的，和它们应该按什么顺序挂载，以及哪些文件系统在挂载前必须被检查 (确定是否有完整性错误)。参考以下命令，创建一个新的文件系统表：
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# 文件系统     挂载点       类型     选项                转储  检查
#                                                            顺序

/dev/sdb1      /            ext4     defaults            1     1
#/dev/<yyy>     swap         swap     pri=1               0     0
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0

# End /etc/fstab
EOF

# Linux-5.13.1  Linux 内核
# 构建内核需要三步 —— 配置、编译、安装。
start_tool linux
# 运行以下命令，准备编译内核. 该命令确保内核源代码树绝对干净，内核开发组建议在每次编译内核前运行该命令。尽管内核源代码树在解压后应该是干净的，但这并不完全可靠。
make mrproper
make defconfig
# 为vm虚拟机选择硬盘和网卡驱动。 这里会弹出界面，要手工选择。
# 先在宿主机上查找宿主系统的硬盘和网卡驱动型号
# sudo lshw -c storage
# 虚拟机使用scsi硬盘，类型为LSI Logic设备。lshw显示信息：53c1030 PCI-X Fusion-MPT Dual Ultra320 SCSI
# sudo lshw -c network
# 虚拟机使用Intel 82545EM Gigabit Ethernet Controller 网卡
# 因此，执行make menuconfig后，选择如下驱动
#Device Drivers -> SCSI device support->
#<*> SCSI disk support
#<*> SCSI generic support
#<*> SCSI low-level drivers ->
#-*- LSI MPT Fusion SAS 3.0 & SAS 2.0 Device Driver
#(128) LSI MPT Fusion SAS 2.0 Max number of SG Entries (16 - 256)
#(128) LSI MPT Fusion SAS 3.0 Max number of SG Entries (16 - 256)
#<*> Legacy MPT2SAS config option

#Device Drivers ->
#[*] Fusion MPT device support —>
#--- Fusion MPT device support
#<*> Fusion MPT ScsiHost drivers for SPI
#<*> Fusion MPT ScsiHost drivers for SAS
#(128) Maximum number of scatter gather entries (16 - 128)
#<*> Fusion MPT misc device (ioctl) driver
#[*] Fusion MPT logging facility 

# Intel 82545EM Gigabit Ethernet Controller 网卡驱动已经默认被选中，所以不用修改。

make menuconfig
# 编译内核映像和模块：
make
# 如果内核配置使用了模块，安装它们：
make modules_install
# 指向内核映像的路径可能随机器平台的不同而变化。下面使用的文件名可以依照您的需要改变，但文件名的开头应该保持为 vmlinuz，以保证和下一节描述的引导过程自动设定相兼容。下面的命令假定是机器是 x86 体系结构：
cp -iv arch/x86/boot/bzImage /boot/vmlinuz-5.13.1-lfs-r10.1-124
# System.map 是内核符号文件，它将内核 API 的每个函数入口点和运行时数据结构映射到它们的地址。它被用于调查分析内核可能出现的问题。执行以下命令安装该文件：
cp -iv System.map /boot/System.map-5.13.1
# 内核配置文件 .config 由上述的 make menuconfig 步骤生成，包含编译好的内核的所有配置选项。最好能将它保留下来以供日后参考：
cp -iv .config /boot/config-5.13.1
# 安装 Linux 内核文档：
install -d /usr/share/doc/linux-5.13.1
cp -r Documentation/* /usr/share/doc/linux-5.13.1
#  需要注意的是，在内核源代码目录中可能有不属于 root 的文件。在以 root 身份解压源代码包时 (就像我们在 chroot 环境中所做的那样)，这些文件会获得它们之前在软件包创建者的计算机上的用户和组 ID。这一般不会造成问题，因为在安装后通常会删除源代码目录树。然而，Linux 源代码目录树一般会被保留较长时间，这样创建者当时使用的用户 ID 就可能被分配给本机的某个用户，导致该用户拥有内核源代码的写权限。
#注意,之后在 BLFS 中安装软件包时往往需要修改内核配置。因此，和其他软件包不同，我们在安装好内核后可以不移除源代码树。
#如果要保留内核源代码树，切换到内核源代码目录，执行 chown -R 0:0，以保证 linux-5.13.1 目录中所有文件都属于 root。
chown -R 0:0 ./
# 配置 Linux 内核模块加载顺序 
# 多数情况下 Linux 内核模块可以自动加载，但有时需要指定加载顺序。负责加载内核模块的程序 modprobe 和 insmod 从 /etc/modprobe.d 下的配置文件中读取加载顺序，例如，如果 USB 驱动程序 (ehci_hcd、ohci_hcd 和 uhci_hcd) 被构建为模块，则必须按照先加载 echi_hcd，再加载 ohci_hcd 和 uhci_hcd 的正确顺序，才能避免引导时出现警告信息。
# 为此，执行以下命令创建文件 /etc/modprobe.d/usb.conf：
install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF
#end_tool linux
cd ..

# 使用 GRUB 设定引导过程。 下述过程较危险，需手工执行
#start_tool grub
# LFS_DISK=/dev/sdb1  lfs系统安装在/dev/sdb上，将 GRUB 文件安装到 /dev/sdb的/boot/grub 并设定引导磁道：
# grub-install /dev/sdb
# 生成 /boot/grub/grub.cfg：注意在 /dev/sdb 引导区安装了GRUB，需要在bios里手工切换为/dev/sdb 第一个引导启动。因此set root=(hd0,1)
#cat > /boot/grub/grub.cfg << "EOF"
## Begin /boot/grub/grub.cfg
#set default=0
#set timeout=5
#
#insmod ext2
#set root=(hd0,1)
#
#menuentry "GNU/Linux, Linux 5.13.1-lfs-r10.1-124" {
#        linux   /boot/vmlinuz-5.13.1-lfs-r10.1-124 root=/dev/sdb1 ro
#}
#EOF

# 使用 宿主机上的 grub-customizer 代替，将如上引导信息写入宿主机的启动菜单。
#在宿主机上执行 sudo grub-customizer  (注意用MoBaXterm自带的Xserver启动此程序时，要先执行 sudo ~/.Xauthority /root/)
# 将如上引导信息写入宿主机的启动菜单,注意要改为 set root=(hd1,1)   root=/dev/sdb1
#end_tool grub

