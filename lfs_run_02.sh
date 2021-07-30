#!/bin/bash

set -e

# login、agetty 和 init 等程序使用一些日志文件，以记录登录系统的用户和登录时间等信息。然而，这些程序不会创建不存在的
# 日志文件。初始化日志文件，并为它们设置合适的访问权限：
# 文件 /var/log/wtmp 记录所有的登录和登出，文件 /var/log/lastlog 记录每个用户最后登录的时间，
# 文件 /var/log/faillog 记录所有失败的登录尝试，文件 /var/log/btmp 记录所有错误的登录尝试。 
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp
# 文件 /run/utmp 记录当前登录的用户，它由引导脚本动态创建。


# 第三遍编译。首先安装 libstdc++。之后临时性地安装工具链的正常工作所必须的程序。此后，
# LFS目标系统的核心工具链成为自包含的本地工具链。最后，构建、测试并最终安装所有软件包，它们组成功能完整的系统。

# 安装LFS目标系统的 Libstdc++.  GCC-11.1.0 中的 Libstdc++，对于Libstdc++本身来说是第二遍编译.
# 使用第二遍编译时构建出来的本地编译器 cc-lfs ，在 chroot 环境中安装 Libstdc++ 
# 在构建第二遍的 GCC时，我们不得不暂缓安装 C++ 标准库，因为当时没有编译器能够编译它。我们不能使用那一节构建的编译器，
# 因为它是一个本地编译器，不应在 chroot 外使用，否则可能导致编译产生的库被宿主系统组件污染。
# Libstdc++ 是 GCC 源代码的一部分。先解压 GCC 压缩包并切换到解压出来的 gcc-11.1.0 目录。 
cd sources/  # 切换到源码目录

start_tool() {
  local tool_xz=$(ls ${1}*.tar.?z)
  tar -xf $tool_xz
  cd ${tool_xz:0:-7}
}

end_tool() {
  cd ../
  local tool_xz=$(ls ${1}*.tar.?z)
  rm -rf ${tool_xz:0:-7}
}

install_tools_use_cc_lfs () {
  local pkg_name=$1
  local conf=$2
  local mk_conf=$3
  local mk_build=$4
  echo "install $pkg_name"
  echo "./configure --prefix=/usr   \
              $conf"
  #read
  echo "make install $mk_conf"
  #read
  
  start_tool $pkg_name 
  echo "prepare compile $pkg_name"  
  if [ -z "$mk_build" ]; then
    bash -c "./configure --prefix=/usr   \
              $conf"
  else 
    mkdir -v build
    cd build
    bash -c "../configure --prefix=/usr   \
              $conf"
  fi
  echo "compile $pkg_name"
  make
  echo "install $pkg_name"
  bash -c "make install $mk_conf"
  if [ ! -z "$5" ]; then
    echo "$5"
    #read
    bash -c "$5"
  fi
  if [ ! -z "$mk_build" ]; then
    cd ..
  fi
  end_tool patch
}

start_tool gcc
#  创建一个符号链接，允许在 GCC 源码树中构建 Libstdc++：
ln -s gthr-posix.h libgcc/gthr-default.h
# 为 Libstdc++ 创建一个单独的构建目录，并切换到该目录：
mkdir -v build
cd build
# 准备编译 Libstdc++:
../libstdc++-v3/configure            \
    CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
    --prefix=/usr                    \
    --disable-multilib               \
    --disable-nls                    \
    --host=$(uname -m)-lfs-linux-gnu \
    --disable-libstdcxx-pch
# 运行以下命令编译 Libstdc++：
make
# 安装这个库：
make install
cd ..
end_tool gcc 

# 安装 Gettext. Gettext 软件包包含国际化和本地化工具，它们允许程序在编译时加入 NLS (本地语言支持) 功能，
# 使它们能够以用户的本地语言输出消息。 
# 对于我们的临时工具，只要安装 Gettext 中的三个程序即可。
start_tool gettext
# 准备编译 Gettext：
./configure --disable-shared
# 编译该软件包：
make
# 安装 msgfmt，msgmerge，以及 xgettext 这三个程序：
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
end_tool gettext 

# 安装 Bison. Bison 软件包包含语法分析器生成器。 
install_tools_use_cc_lfs 'bison' '--docdir=/usr/share/doc/bison-3.7.6'

# 安装 Perl. Perl 软件包包含实用报表提取语言。 
start_tool 'perl'
# 准备编译 Perl：
sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl     \
             -Darchlib=/usr/lib/perl5/5.34/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
# 编译该软件包：
make
# 安装该软件包：
make install
end_tool 'perl'

# 安装 Python-3.9.6  
install_tools_use_cc_lfs 'Python' '--enable-shared \
            --without-ensurepip'

# 安装 Texinfo. Texinfo 软件包包含阅读、编写和转换 info 页面的程序
install_tools_use_cc_lfs 'texinfo'

# 安装 Util-linux. Util-linux 软件包包含一些工具程序。
start_tool 'util-linux-2'
# FHS 建议使用 /var/lib/hwclock 目录，而非一般的 /etc 目录作为 adjtime 文件的位置。首先创建该目录：
mkdir -pv /var/lib/hwclock
# 准备编译 Util-linux：
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --docdir=/usr/share/doc/util-linux-2.37 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            runstatedir=/run
# 编译该软件包：
make
# 安装该软件包：
make install
end_tool 'util-linux-2'

# 清理和备份临时系统 
# libtool .la 文件仅在链接到静态库时有用。在使用动态共享库时它们没有意义，甚至可能有害，特别是在使用
# 非 autotools 构建系统时容易产生问题。继续在 chroot 环境中运行命令，删除它们：
find /usr/{lib,libexec} -name \*.la -delete
# 删除临时工具的文档，以防止它们进入最终构建的系统，并节省大约 35 MB：
rm -rf /usr/share/{info,man,doc}/*
# 一旦您开始在后续步骤中安装软件包，临时工具就会被覆盖。因此，按照下面描述的步骤备份临时工具可能是个好主意。
# 以下备份临时工具的步骤在 chroot 环境之外进行
exit   #退出 chroot 环境


