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



