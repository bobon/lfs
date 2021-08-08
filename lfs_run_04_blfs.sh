#!/bin/bash

set -e

# lfs收尾工作
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


# BLFS 超越Linux
# 现在已经安装好了本书中的所有软件，可以重新启动进入 LFS 了。然而，您应该注意一些可能出现的问题。您根据本书构建的系统是很小的，可能缺失一些功能，导致您无法继续使用。您可以在当前的 chroot 环境中安装一些 BLFS 手册提供的额外软件包，以便在重启进入新的 LFS 系统后更容易工作。下面是一些建议您考虑的软件包： 


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


# wget
start_tool wget
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl &&
make
make install
end_tool wget

# 字符模式浏览器，例如 Lynx 基于文本的网络浏览器，这样您可以在一个虚拟终端中阅读 BLFS 手册，同时在另一个虚拟终端构建软件包。 
wget --no-check-certificate -c https://invisible-mirror.net/archives/lynx/tarballs/lynx2.8.9rel.1.tar.bz2
md5sum lynx2.8.9rel.1.tar.bz2 | grep 44316f1b8a857b59099927edc26bef79
tar -xf lynx2.8.9rel.1.tar.bz2
cd lynx2.8.9rel.1
./configure --prefix=/usr          \
            --sysconfdir=/etc/lynx \
            --datadir=/usr/share/doc/lynx-2.8.9rel.1 \
            --with-zlib            \
            --with-bzlib           \
            --with-ssl             \
            --with-screen=ncursesw \
            --enable-locale-charset &&
make
make install-full &&
chgrp -v -R root /usr/share/doc/lynx-2.8.9rel.1/lynx_doc
cd ..
rm -rf lynx2.8.9rel.1
# 配置Lynx
# The proper way to get the display character set is to examine the current locale. However, Lynx does not do this by default. As the root user, change this setting:
sed -e '/#LOCALE/     a LOCALE_CHARSET:TRUE'     \
    -i /etc/lynx/lynx.cfg
#The built-in editor in Lynx Breaks Multibyte Characters. This issue manifests itself in multibyte locales, e.g., as the Backspace key not erasing non-ASCII characters properly, and as incorrect data being sent to the network when one edits the contents of text areas. The only solution to this problem is to configure Lynx to use an external editor (bound to the “Ctrl+X e” key combination by default). Still as the root user:
sed -e '/#DEFAULT_ED/ a DEFAULT_EDITOR:vi'       \
    -i /etc/lynx/lynx.cfg
#Lynx handles the following values of the DEFAULT_EDITOR option specially by adding cursor-positioning arguments: “emacs”, “jed”, “jmacs”, “joe”, “jove”, “jpico”, “jstar”, “nano”, “pico”, “rjoe”, “vi” (but not “vim”: in order to position the cursor in Vim-8.2.2890, set this option to “vi”).
#By default, Lynx doesn't save cookies between sessions. Again as the root user, change this setting:
sed -e '/#PERSIST/    a PERSISTENT_COOKIES:TRUE' \
    -i /etc/lynx/lynx.cfg
#许多其他全系统设置（如代理）也可以设置在文件中。/etc/lynx/lynx.cfg

# OpenSSH
wget --no-check-certificate -c https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.6p1.tar.gz
md5sum openssh-8.6p1.tar.gz | grep 805f7048aec6dd752584e570383a6f00
start_tool openssh
#打开SSH在连接到其他计算机时作为两个过程运行。第一个过程是特权流程，并在必要时控制特权的发放。第二个过程与网络通信。设置适当的环境需要额外的安装步骤，这些安装步骤通过作为用户发出以下命令来执行：root
install  -v -m700 -d /var/lib/sshd &&
chown    -v root:sys /var/lib/sshd &&
groupadd -g 50 sshd        &&
useradd  -c 'sshd PrivSep' \
         -d /var/lib/sshd  \
         -g sshd           \
         -s /bin/false     \
         -u 50 sshd
./configure --prefix=/usr                            \
            --sysconfdir=/etc/ssh                    \
            --with-md5-passwords                     \
            --with-privsep-path=/var/lib/sshd        \
            --with-default-path=/usr/bin             \
            --with-superuser-path=/usr/sbin:/usr/bin \
            --with-pid-dir=/run
make
make install &&
install -v -m755    contrib/ssh-copy-id /usr/bin     &&

install -v -m644    contrib/ssh-copy-id.1 \
                    /usr/share/man/man1              &&
install -v -m755 -d /usr/share/doc/openssh-8.6p1     &&
install -v -m644    INSTALL LICENCE OVERVIEW README* \
                    /usr/share/doc/openssh-8.6p1
end_tool openssh
# 配置openssh
#这些文件中没有任何必要的更改。但是，您可能需要查看文件并做出适合系统安全性的任何更改。一个建议的更改是，您通过ssh禁用登录。执行以下命令，用户可通过ssh禁用登录：/etc/ssh/rootrootroot
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
# 启动脚本，留着用于以后再安装服务使用，因此不删除源代码。
wget --no-check-certificate -c https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-20210711.tar.xz
start_tool blfs-bootscripts
make install-sshd
cd ..

# sudo
wget --no-check-certificate -c https://www.sudo.ws/dist/sudo-1.9.7p2.tar.gz
md5sum sudo-1.9.7p2.tar.gz | grep d6f8217bfd16649236e100c49e0a7cc4
start_tool sudo
./configure --prefix=/usr              \
            --libexecdir=/usr/lib      \
            --with-secure-path         \
            --with-all-insults         \
            --with-env-editor          \
            --docdir=/usr/share/doc/sudo-1.9.7p2 \
            --with-passprompt="[sudo] password for %p: " &&
make
make install &&
ln -sfv libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0
end_tool sudo
