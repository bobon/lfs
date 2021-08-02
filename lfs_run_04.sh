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

