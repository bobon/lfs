#!/bin/bash

set -e


# 真正开始构造 LFS 系统。
 #升级问题
# 使用包管理器可以在软件包新版本发布后容易地完成升级。一般来说，使用 LFS 或者 BLFS 手册给出的构建方法即可升级软件包。下面是您在升级时必须注意的重点，特别是升级正在运行的系统时。
#   如果需要升级 Linux 内核 (例如，从 5.10.17 升级到 5.10.18 或 5.11.1)，则不需要重新构建其他任何软件包。因为内核态与用户态的边界十分清晰，系统仍然能够继续正常工作。特别地，在升级内核时，不需要 (也不应该，详见下一项说明) 一同更新 Linux API 头文件。必须重新引导系统，才能使用升级后的内核。
#   如果需要升级 Linux API 头文件或 Glibc (例如从 Glibc-2.31 升级到 Glibc-2.32)，最安全的方法是重新构建 LFS。尽管您或许能按依赖顺序重新构建所有软件包，但我们不推荐这样做。
#   如果更新了一个包含共享库的软件包，而且共享库的名称发生改变，那么所有动态链接到这个库的软件包都需要重新编译，以链接到新版本的库。(注意软件包的版本和共享库的名称没有关系。) 例如，考虑一个软件包 foo-1.2.3 安装了名为 libfoo.so.1 的共享库，如果您把该软件包升级到了新版本 foo-1.2.4，它安装了名为 libfoo.so.2 的共享库。那么，所有链接到 libfoo.so.1 的软件包都要重新编译以链接到 libfoo.so.2。注意，您不能删除旧版本的库，直到将所有依赖它的软件包都重新编译完成。
#   如果更新了一个包含共享库的软件包，且共享库的名称没有改变，但是库文件的版本号降低了 (例如，库的名称保持 libfoo.so.1 不变，但是库文件名由 libfoo.so.1.25 变为 libfoo.so.1.24)，则需要删除旧版本软件包安装的库文件 (对于上述示例，需要删除 libfoo.so.1.25)。否则，ldconfig 命令在执行时 (可能是通过命令行执行，也可能由一些软件包的安装过程自动执行)，会将符号链接 libfoo.so.1 的目标重设为旧版本的库文件，因为它版本号更大，看上去更“新”。在不得不降级软件包，或者软件包突然更改库文件版本号格式时，可能出现这种问题。
#   如果更新了一个包含共享库的软件包，且共享库的名称没有改变，但是这次更新修复了一个严重问题 (特别是安全缺陷)，则要重新启动所有链接到该库的程序。以 root 身份，运行以下命令，即可列出所有正在使用旧版本共享库的进程 (将 libfoo 替换成库名)：
#    grep -l  -e 'libfoo.*deleted' /proc/*/maps |
#       tr -cd 0-9\\n | xargs -r ps u
#   如果正在使用 OpenSSH 访问系统，且它链接到了被更新的库，则需要重启 sshd 服务，登出并重新登录，然后再次运行上述命令，确认没有进程使用被删除的库文件。

cd sources/  # 切换到源码目录

start_tool() {
  echo "start tool ${1}"
  local tool_xz=$(ls ${1}*.tar.?z)
  tar -xf $tool_xz
  cd ${tool_xz:0:-7}
}

end_tool() {
  cd ../
  local tool_xz=$(ls ${1}*.tar.?z)
  rm -rf ${tool_xz:0:-7}
}

install_tools_to_lfs () {
  local pkg_name=$1
  local conf=$2
  local mk_conf=$3
  local check=$4
  echo "install $pkg_name"
  echo "./configure --prefix=/usr   \
              $conf"
  #read
  echo "make install $mk_conf"
  #read
  
  start_tool $pkg_name 
  echo "prepare compile $pkg_name"  
  bash -c "./configure --prefix=/usr   \
         $conf"
  echo "compile $pkg_name"
  make
  if [ ! -z "$check" ]; then
    echo "make $check"
    #read
    make $check
  fi
  echo "install $pkg_name"
  bash -c "make install $mk_conf"
  if [ ! -z "$5" ]; then
    echo "$5"
    #read
    bash -c "$5"
  fi
  end_tool $pkg_name
}

# 安装 Man-pages. Man-pages 软件包包含 2,200 多个 man 页面。
start_tool man-pages
# 安装 Man-pages：
make prefix=/usr install
end_tool man-pages

# 安装 Iana-Etc. Iana-Etc 软件包包含网络服务和协议的数据。
start_tool iana-etc
cp services protocols /etc
end_tool iana-etc

# 安装 Glibc
start_tool glibc
# 某些 Glibc 程序使用与 FHS 不兼容的 /var/db 目录存放运行时数据。应用下列补丁，使得这些程序在 FHS 兼容的位置存储运行时数据：
patch -Np1 -i ../glibc-2.33-fhs-1.patch
# 修复导致 chroot 环境中应用程序出现故障的问题：
sed -e '402a\      *result = local->data.services[database_index];' \
    -i nss/nss_database.c
# 修复使用 gcc-11.1 构建时出现的问题：
sed 's/amx_/amx-/' -i sysdeps/x86/tst-cpu-features-supports.c
mkdir -v build
cd build
# 准备编译 Glibc：
../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=3.2                      \
             --enable-stack-protector=strong          \
             --with-headers=/usr/include              \
             libc_cv_slibdir=/usr/lib
# 编译该软件包：
make
# 运行 Glibc 的测试套件是很关键的。在任何情况下都不要跳过这个测试。
# 通常来说，可能会有极少数测试不能通过，下面列出的失败结果一般可以安全地忽略。执行以下命令进行测试：
make check || true
# 在安装 Glibc 时，它会抱怨文件 /etc/ld.so.conf 不存在。尽管这是一条无害的消息，执行以下命令即可防止这个警告：
touch /etc/ld.so.conf
# 修正生成的 Makefile，跳过一个在 LFS 的不完整环境中会失败的完整性检查：
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
# 安装该软件包：
make install
# 改正 ldd 脚本中硬编码的可执行文件加载器路径：
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
# 安装 nscd 的配置文件和运行时目录：
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
# 下面，安装一些 locale，它们可以使得系统用不同语言响应用户请求。这些 locale 都不是必须的，但是如果缺少了它们
# 中的某些，在将来运行软件包的测试套件时，可能跳过重要的测试。 
# 可以用 localedef 程序安装单独的 locale。例如，下面的第一个 localedef 命令将 /usr/share/i18n/locales/cs_CZ 中的字符集无关 locale 定义和 /usr/share/i18n/charmaps/UTF-8.gz 中的字符映射定义组合起来，并附加到 /usr/lib/locale/locale-archive 文件。以下命令将会安装能够覆盖测试所需的最小 locale 集合：
mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f ISO-8859-1 en_GB
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_ES -f ISO-8859-15 es_ES@euro
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i is_IS -f ISO-8859-1 is_IS
localedef -i is_IS -f UTF-8 is_IS.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f ISO-8859-15 it_IT@euro
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i se_NO -f UTF-8 se_NO.UTF-8
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

# 配置 Glibc 
# 创建 nsswitch.conf 
# 由于 Glibc 的默认值在网络环境下不能很好地工作，需要创建配置文件 /etc/nsswitch.conf。
# 执行以下命令创建新的 /etc/nsswitch.conf：
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

# 添加时区数据 
# 输入以下命令，安装并设置时区数据：
tar -xf ../../tzdata2021a.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 配置动态加载器 
# 默认情况下，动态加载器 (/lib/ld-linux.so.2) 在 /lib 和 /usr/lib 中搜索程序运行时需要的动态库。然而，如果在除了 /lib 和 /usr/lib 以外的其他目录中有动态库，为了使动态加载器能够找到它们，需要把这些目录添加到文件 /etc/ld.so.conf 中。有两个目录 /usr/local/lib 和 /opt/lib 经常包含附加的共享库，所以现在将它们添加到动态加载器的搜索目录中。
# 运行以下命令，创建一个新的 /etc/ld.so.conf：
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
# 如果希望的话，动态加载器也可以搜索一个目录，并将其中的文件包含在 ld.so.conf 中。通常包含文件目录中的文件只有一行，指定一个期望的库文件目录。如果需要这项功能，执行以下命令：
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
cd ..
end_tool glibc


# 安装 Zlib. Zlib 软件包包含一些程序使用的压缩和解压缩子程序。 
#install_tools_to_lfs 'zlib' '' '' check
# 删除无用的静态库： 
rm -fv /usr/lib/libz.a

# 安装 Bzip2. Bzip2 软件包包含用于压缩和解压缩文件的程序。使用 bzip2 压缩文本文件可以获得比传统的 gzip 优秀许多的压缩比。 
start_tool bzip2
# 应用一个补丁，以安装该软件包的文档：
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
# 以下命令保证安装的符号链接是相对的：
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
# 确保 man 页面被安装到正确位置：
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
# 执行以下命令，准备编译 Bzip2：
make clean
make -f Makefile-libbz2_so
make clean
# 编译并测试该软件包：
make
# 安装软件包中的程序：
make PREFIX=/usr install
# 安装共享库：
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
# 安装链接到共享库的 bzip2 二进制程序到 /bin 目录，并将两个和 bzip2 完全相同的文件替换成符号链接：
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
# 删除无用的静态库：
rm -fv /usr/lib/libbz2.a
end_tool bzip2

# 安装 Xz. Xz 软件包包含文件压缩和解压缩工具，它能够处理 lzma 和新的 xz 压缩文件格式。使用 xz 压缩文本文件，可以得到比传统的 gzip 或 bzip2 更好的压缩比。 
install_tools_to_lfs 'xz' '--disable-static \
            --docdir=/usr/share/doc/xz-5.2.5' '' check

# 安装 Zstd. Zstandard 是一种实时压缩算法，提供了较高的压缩比。它具有很宽的压缩比/速度权衡范围，同时支持具有非常快速的解压缩。
start_tool zstd
# 编译该软件包
make
# 运行以下命令，以测试编译结果：
make check
# 安装该软件包：
make prefix=/usr install
# 删除静态库：
rm -v /usr/lib/libzstd.a
end_tool zstd

# 安装 File. File 软件包包含用于确定给定文件类型的工具。 
install_tools_to_lfs 'file' '' '' check

# 安装 Readline. Readline 软件包包含一些提供命令行编辑和历史记录功能的库。 
start_tool readline
# 重新安装 Readline 会导致旧版本的库被重命名为 <库名称>.old。这一般不是问题，但某些情况下会触发 ldconfig 的一个链接 bug。运行下面的两条 sed 命令防止这种情况：
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
# 准备编译 Readline：
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.1
# 编译该软件包：
make SHLIB_LIBS="-lncursesw"
# 安装该软件包：
make SHLIB_LIBS="-lncursesw" install
# 如果您希望的话，可以安装文档：
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.1
end_tool readline

# 安装 M4. M4 软件包包含一个宏处理器。 
install_tools_to_lfs 'm4' '' '' check

#安装 Bc. Bc 软件包包含一个任意精度数值处理语言。
start_tool bc 
# 准备编译 Bc：
CC=gcc ./configure --prefix=/usr -G -O3
# 编译该软件包：
make
# 为了测试 bc，运行：
make test
# 安装该软件包：
make install
end_tool bc

# 安装 Flex. Flex 软件包包含一个工具，用于生成在文本中识别模式的程序。
install_tools_to_lfs 'flex' '--docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static' '' check
# 个别程序还不知道 flex，并试图去运行它的前身 lex。为了支持这些程序，创建一个名为 lex 的符号链接，它运行 flex 并启动其模拟 lex 的模式：
ln -sfv flex /usr/bin/lex

# 安装 Tcl. Tcl 软件包包含工具命令语言，它是一个可靠的通用脚本语言。Except 软件包是用 Tcl 语言编写的.
tar -zxf tcl*src.tar.gz
cd tcl8.6.11
# 为了支持 Binutils 和 GCC 等软件包测试套件的运行，需要安装这个软件包和接下来的两个 (Expect 与 DejaGNU)。为了测试目的安装三个软件包看似浪费，但是只有运行了测试，才能放心地确定多数重要工具可以正常工作，即使测试不是必要的。我们必须安装这些软件包，才能执行本章中的测试套件。
# 首先，运行以下命令解压文档：
tar -xf ../tcl8.6.11-html.tar.gz --strip-components=1
# 准备编译 Tcl：
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            $([ "$(uname -m)" = x86_64 ] && echo --enable-64bit)
# 构建该软件包：
make
sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|"            \
    -i pkgs/tdbc1.1.2/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
    -e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|"            \
    -i pkgs/itcl4.2.1/itclConfig.sh

unset SRCDIR
#“make”命令之后的若干“sed”命令从配置文件中删除构建目录，并用安装目录替换它们。构建 LFS 的后续过程不对此严格要求，但如果之后构建使用 Tcl 的软件包，则可能需要这样的操作。 
# 运行以下命令，以测试编译结果：
make test
# 安装该软件包：
make install
# 将安装好的库加上写入权限，以便将来移除调试符号：
chmod -v u+w /usr/lib/libtcl8.6.so
# 安装 Tcl 的头文件。下一个软件包 Expect 需要它们才能构建。
make install-private-headers
# 创建一个必要的符号链接：
ln -sfv tclsh8.6 /usr/bin/tclsh
# 最后，重命名一个与 Perl man 页面文件名冲突的 man 页面：
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
cd ../../
rm -rf tcl8.6.11

# 安装 Expect. Expect 软件包包含通过脚本控制的对话，自动化 telnet，ftp，passwd，fsck，rlogin，以及 tip 等交互应用的工具。Expect 对于测试这类程序也很有用，它简化了这类通过其他方式很难完成的工作。DejaGnu 框架是使用 Expect 编写的。 
install_tools_to_lfs 'expect' '--with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include' '' test
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

# 安装 DejaGNU. DejaGnu 包含使用 GNU 工具运行测试套件的框架。它是用 expect 编写的，后者又使用 Tcl (工具命令语言)。
start_tool dejagnu
# DejaGNU 开发者建议在专用的目录中进行构建：
mkdir -v build
cd build
# 准备编译 DejaGNU：
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
# 构建并安装该软件包：
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
# 如果要测试该软件包，执行：
make check
cd ..
end_tool dejagnu 

# 安装 Binutils. Binutils 包含汇编器、链接器以及其他用于处理目标文件的工具。 
# 进行简单测试，确认伪终端 (PTY) 在 chroot 环境中能正常工作：
# 该命令应该输出 spawn ls
expect -c "spawn ls" | grep 'spawn ls'
start_tool binutils
# 删除一项导致测试套件无法完成的测试：
sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in
# Binutils 文档推荐在一个专用的构建目录中构建 Binutils：
mkdir -v build
cd build
# 准备编译 Binutils：
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
# 编译该软件包：
make tooldir=/usr
# 测试编译结果：
make -k check || true
# 安装该软件包：
make tooldir=/usr install -j1
# 删除无用的静态库：
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
cd ..
end_tool binutils 

# 安装 GMP. GMP 软件包包含提供任意精度算术函数的数学库。
start_tool gmp
# 准备编译 GMP：
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.2.1
# 编译该软件包，并生成 HTML 文档：
make
make html
# 测试编译结果：
make check 2>&1 | tee gmp-check-log
# 务必确认测试套件中的 197 个测试全部通过。运行以下命令检验结果：
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log | grep 197
# 安装该软件包及其文档：
make install
make install-html
end_tool gmp 


install_tools_to_lfs () {
  local pkg_name=$1
  local conf=$2
  local mk_conf=$3
  local install_conf=$4
  echo "install $pkg_name"
  echo "./configure --prefix=/usr   \
              $conf"
  #read
  echo "make $mk_conf"
  #read
  echo "make install $install_conf"
  #read
  
  start_tool $pkg_name 
  echo "prepare compile $pkg_name"  
  bash -c "./configure --prefix=/usr   \
         $conf"
  echo "compile $pkg_name"
  bash -c "make $mk_conf"
  echo "install $pkg_name"
  bash -c "make install $install_conf"
  if [ ! -z "$5" ]; then
    echo "$5"
    #read
    bash -c "$5"
  fi
  end_tool $pkg_name
}

# 安装 MPFR. MPFR 软件包包含多精度数学函数。 
install_tools_to_lfs 'mpfr' '--disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.1.0' '&& make html && make check || true' '&& make install-html'

# 安装 MPC. MPC 软件包包含一个任意高精度，且舍入正确的复数算术库。
install_tools_to_lfs 'mpc' '--disable-static \
            --docdir=/usr/share/doc/mpc-1.2.1' '&& make html && make check' '&& make install-html'

# 安装 Attr. Attr 软件包包含管理文件系统对象扩展属性的工具。
install_tools_to_lfs 'attr' '--disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.1' '&& make check' ''

# 安装 Acl. Acl 软件包包含管理访问控制列表的工具，访问控制列表能够更细致地自由定义文件和目录的访问权限。 
install_tools_to_lfs 'acl' '--disable-static      \
            --docdir=/usr/share/doc/acl-2.3.1'

# 安装 Libcap. Libcap 软件包为 Linux 内核提供的 POSIX 1003.1e 权能字实现用户接口。这些权能字是 root 用户的最高特权分割成的一组不同权限。 
start_tool libcap
# 防止静态库的安装：
sed -i '/install -m.*STA/d' libcap/Makefile
# 编译该软件包：
make prefix=/usr lib=lib
# 运行以下命令以测试编译结果：
make test
# 安装该软件包：
make prefix=/usr lib=lib install
# 调整共享库的权限模式：
chmod -v 755 /usr/lib/lib{cap,psx}.so.2.51
end_tool libcap

# 安装 Shadow. Shadow 软件包包含安全地处理密码的程序。
start_tool shadow
# 禁止该软件包安装 groups 程序和它的 man 页面，因为 Coreutils 会提供更好的版本。同样，避免安装第 8.3 节 “Man-pages-5.12”软件包已经提供的 man 页面：
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
# 不使用默认的 crypt 加密方法，使用更安全的 SHA-512 方法加密密码，该方法也允许长度超过 8 个字符的密码。还需要把过时的用户邮箱位置 /var/spool/mail 改为当前普遍使用的 /var/mail 目录。另外，从默认的 PATH 中删除/bin 和 /sbin，因为它们只是指向 /usr 中对应目录的符号链接： 
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
    -e 's:/var/spool/mail:/var/mail:'                 \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
    -i etc/login.defs
# 进行微小的改动，使 useradd 使用 1000 作为第一个组编号：
sed -i 's/1000/999/' etc/useradd
# 准备编译 Shadow：
touch /usr/bin/passwd
./configure --sysconfdir=/etc \
            --with-group-name-max-length=32
# 编译该软件包：
make
# 安装该软件包：
make exec_prefix=/usr install
end_tool shadow
# 配置 Shadow 
# 为用户 root 选择一个密码，并执行以下命令设定它：
#passwd root 
echo root:'Omc!2012.' | chpasswd

# 安装 GCC(第三次) 
# 应用补丁以修复一些退化问题，并解除对于 linux-5.13 中移除的过时内核头文件的依赖：
start_tool gcc
patch -Np1 -i ../gcc-11.1.0-upstream_fixes-1.patch
# 在 x86_64 上构建时，修改存放 64 位库的默认路径为 “lib”:
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
# GCC 文档推荐在专用的构建目录中构建 GCC：
mkdir -v build
cd build
# 准备编译 GCC： 
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib
# 编译该软件包：
make
# 已知 GCC 测试套件中的一组测试可能耗尽默认栈空间，因此运行测试前要增加栈空间：
ulimit -s 32768
# 以非特权用户身份测试编译结果，但出错时继续执行其他测试：
chown -Rv tester . 
su tester -c "PATH=$PATH make -k check" || true
# 输入以下命令查看测试结果的摘要：
../contrib/test_summary
# 安装该软件包，并移除一个不需要的目录：
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/11.1.0/include-fixed/bits/
# GCC 构建目录目前属于用户 tester，这会导致安装的头文件目录 (及其内容) 具有不正确的所有权。将所有者修改为 root 用户和组：
chown -v -R root:root /usr/lib/gcc/*linux-gnu/11.1.0/include{,-fixed}
# 创建一个 FHS 因 “历史原因” 要求的符号链接。
ln -svfr /usr/bin/cpp /usr/lib
# 创建一个兼容性符号链接，以支持在构建程序时使用链接时优化 (LTO)：
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/11.1.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
# 现在最终的工具链已经就位，重要的是再次确认编译和链接像我们期望的一样正常工作。我们通过进行一些完整性检查，进行确认：
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
# 动态链接器名称
readelf -l a.out | grep ': /lib' | grep '[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]'
# 下面确认我们的设定能够使用正确的启动文件：
# gcc 应该找到所有三个 crt*.o 文件，它们应该位于 /usr/lib 目录中。 
echo '/usr/lib/gcc/x86_64-pc-linux-gnu/11.1.0/../../../../lib/crt1.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/11.1.0/../../../../lib/crti.o succeeded
/usr/lib/gcc/x86_64-pc-linux-gnu/11.1.0/../../../../lib/crtn.o succeeded' | diff - <(grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log)
# 确认编译器能正确查找头文件：
echo '#include <...> search starts here:
 /usr/lib/gcc/x86_64-pc-linux-gnu/11.1.0/include
 /usr/local/include
 /usr/lib/gcc/x86_64-pc-linux-gnu/11.1.0/include-fixed
 /usr/include' | diff - <(grep -B4 '^ /usr/include' dummy.log)
# 确认新的链接器使用了正确的搜索路径：
echo 'SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib64")
SEARCH_DIR("/usr/local/lib64")
SEARCH_DIR("/lib64")
SEARCH_DIR("/usr/lib64")
SEARCH_DIR("/usr/x86_64-pc-linux-gnu/lib")
SEARCH_DIR("/usr/local/lib")
SEARCH_DIR("/lib")
SEARCH_DIR("/usr/lib");' | diff - <(grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g')
# 确认我们使用了正确的 libc：
grep "/lib.*/libc.so.6 " dummy.log | grep 'attempt to open /usr/lib/libc.so.6 succeeded'
# 确认 GCC 使用了正确的动态链接器：
grep found dummy.log | grep 'found ld-linux-x86-64.so.2 at /usr/lib/ld-linux-x86-64.so.2'
# 在确认一切工作良好后，删除测试文件：
rm -v dummy.c a.out dummy.log
# 最后移动一个位置不正确的文件：
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd ..
end_tool gcc

# 安装 Pkg-config. pkg-config 软件包提供一个在软件包安装的配置和编译阶段，向构建工具传递头文件和/或库文件路径的工具。
install_tools_to_lfs () {
  local pkg_name=$1
  local before=$2
  local conf=$3
  local mk_conf=$4
  local after=$5
  echo "install $pkg_name"

  if [ ! -z "$before" ]; then
    echo "$before"
    #read  
  fi
  echo "./configure --prefix=/usr   \
              $conf"
  #read
  echo "make $mk_conf"
  #read
  if [ ! -z "$after" ]; then
    echo "$after"
    #read  
  fi
  
  start_tool $pkg_name 
  echo "prepare compile $pkg_name"
  if [ ! -z "$before" ]; then
    bash -c "$before"
  fi  
  bash -c "./configure --prefix=/usr   \
         $conf"
  echo "compile and install $pkg_name"
  bash -c "make $mk_conf"
  if [ ! -z "$after" ]; then
    bash -c "$after"
  fi
  end_tool $pkg_name
}

install_tools_to_lfs 'pkg-config' '' '--with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2' '&& make check && make install'

# 安装 Ncurses. Ncurses 软件包包含使用时不需考虑终端特性的字符屏幕处理函数库。 
install_tools_to_lfs 'ncurses' '' '--mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec' '&& make install' 'rm -vf /usr/share/doc/ncurses-6.2 && mkdir -v       /usr/share/doc/ncurses-6.2 && cp -v -R doc/* /usr/share/doc/ncurses-6.2'
# 许多程序仍然希望链接器能够找到非宽字符版本的 Ncurses 库。通过使用符号链接和链接脚本，诱导它们链接到宽字符库：
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
# 最后，确保那些在构建时寻找 -lcurses 的老式程序仍然能够构建：
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
# 删除一个 configure 脚本未处理的静态库：
rm -fv /usr/lib/libncurses++w.a
# 上述指令没有创建非宽字符的 Ncurses 库，因为从源码编译的软件包不会在运行时链接到它。然而，已知的需要链接到非宽字符 Ncurses 库的二进制程序都需要版本 5。如果您为了满足一些仅有二进制版本的程序，或者满足 LSB 兼容性，必须安装这样的库，执行以下命令再次构建该软件包：
install_tools_to_lfs 'ncurses' 'make distclean || true' '--with-shared    \
            --without-normal \
            --without-debug  \
            --without-cxx-binding \
            --with-abi-version=5' 'sources libs' 'cp -av lib/lib*.so.5* /usr/lib'

# 安装 Sed. 
install_tools_to_lfs 'sed' '' '' '&& make html && chown -Rv tester . && su tester -c "PATH=$PATH make check" && make install' \
 'install -d -m755           /usr/share/doc/sed-4.8 && install -m644 doc/sed.html /usr/share/doc/sed-4.8' 

# 安装 Psmisc. Psmisc 软件包包含显示正在运行的进程信息的程序。 
install_tools_to_lfs 'psmisc' '' '' '&& make install'

# 安装 Gettext. Gettext 软件包包含国际化和本地化工具，它们允许程序在编译时加入 NLS (本地语言支持) 功能，使它们能够以用户的本地语言输出消息。
install_tools_to_lfs 'gettext' '' '--disable-static \
            --docdir=/usr/share/doc/gettext-0.21' '&& make check && make install && chmod -v 0755 /usr/lib/preloadable_libintl.so'

# 安装 Bison. Bison 软件包包含语法分析器生成器。 
install_tools_to_lfs 'bison' '' '--docdir=/usr/share/doc/bison-3.7.6' '&& make check && make install'

# Grep
install_tools_to_lfs 'grep' '' '' '&& make check && make install'

# 安装 Bash. 
install_tools_to_lfs 'bash' '' '--docdir=/usr/share/doc/bash-5.1.8 \
            --without-bash-malloc            \
            --with-installed-readline' '&& chown -Rv tester . && su tester -c "PATH=$PATH make tests < $(tty)" && make install'
# 执行新编译的 bash 程序 (替换当前正在执行的版本)：
exec /bin/bash --login +h

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

install_tools_to_lfs () {
  local pkg_name=$1
  local before=$2
  local conf=$3
  local mk_conf=$4
  local after=$5
  echo "install $pkg_name"

  if [ ! -z "$before" ]; then
    echo "$before"
    #read  
  fi
  local configure_=./configure
  if [ ! -f "$configure_" ]; then local configure_=../configure; local popd_='cd ..'; fi
  echo "$configure_ --prefix=/usr   \
              $conf"
  #read
  echo "make $mk_conf"
  #read
  if [ ! -z "$after" ]; then
    echo "$after"
    #read  
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

# 安装 Libtool. Libtool 软件包包含 GNU 通用库支持脚本。它在一个一致、可移植的接口下隐藏了使用共享库的复杂性。 
install_tools_to_lfs 'libtool' '' '' '&& make install' 'rm -fv /usr/lib/libltdl.a'

# 安装 GDBM. GDBM 软件包包含 GNU 数据库管理器。它是一个使用可扩展散列的数据库函数库，工作方法和标准 UNIX dbm 类似。该库提供用于存储键值对、通过键搜索和获取数据，以及删除键和对应数据的原语。 
install_tools_to_lfs 'gdbm' '' '--disable-static \
            --enable-libgdbm-compat' '&& make check || true && make install'

#  安装 Gperf. Gperf 根据一组键值，生成完美散列函数。
install_tools_to_lfs 'gperf' '' '--docdir=/usr/share/doc/gperf-3.1' '&& make -j1 check && make install'

# 安装 Expat. Expat 软件包包含用于解析 XML 文件的面向流的 C 语言库。
install_tools_to_lfs 'expat' '' '--disable-static \
            --docdir=/usr/share/doc/expat-2.4.1' '&& make check && make install' 'install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.4.1'

# 安装 Inetutils. Inetutils 软件包包含基本网络程序。 
install_tools_to_lfs 'inetutils' '' '--bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers' '&& make check && make install' 'mv -v /usr/{,s}bin/ifconfig'

# 安装 Less. Less 软件包包含一个文本文件查看器。 
install_tools_to_lfs 'less' '' '--sysconfdir=/etc' '&& make install'

# 安装 Perl 
# 首先，应用补丁，以修复该软件包中由较新的 gdbm 版本暴露出的问题：
start_tool perl
patch -Np1 -i ../perl-5.34.0-upstream_fixes-1.patch
# 该版本的 Perl 会构建 Compress::Raw::ZLib 和 Compress::Raw::BZip2 模块。默认情况下 Perl 会使用内部的源码副本构建它们。执行以下命令，使得 Perl 使用系统中已经安装好的库：
export BUILD_ZLIB=False
export BUILD_BZIP2=0
# 为了能够完全控制 Perl 的设置，您可以在以下命令中移除 “-des” 选项，并手动选择构建该软件包的方式。或者，直接使用下面的命令，以使用 Perl 自动检测的默认值：
sh Configure -des                                         \
             -Dprefix=/usr                                \
             -Dvendorprefix=/usr                          \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl      \
             -Darchlib=/usr/lib/perl5/5.34/core_perl      \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl      \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl     \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl  \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl \
             -Dman1dir=/usr/share/man/man1                \
             -Dman3dir=/usr/share/man/man3                \
             -Dpager="/usr/bin/less -isR"                 \
             -Duseshrplib                                 \
             -Dusethreads
# 编译该软件包：
make
# 为了测试编译结果 (需要约 11 SBU)，执行以下命令：
make test
# 安装该软件包，并清理环境变量：
make install
unset BUILD_ZLIB BUILD_BZIP2
end_tool perl

# 安装 XML::Parser. XML::Parser 模块是 James Clark 的 XML 解析器 Expat 的 Perl 接口。 
start_tool XML-Parser
# 准备编译 XML::Parser：
perl Makefile.PL
# 编译该软件包：
make
# 执行以下命令以测试编译结果：
make test
# 安装该软件包：
make install
end_tool XML-Parser

# 安装 Intltool. Intltool 是一个从源代码文件中提取可翻译字符串的国际化工具。
start_tool intltool
# 首先修复由 perl-5.22 及更新版本导致的警告：
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
# 准备编译 Intltool：
./configure --prefix=/usr
# 编译该软件包：
make
# 运行以下命令以测试编译结果：
make check
# 安装该软件包：
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
end_tool intltool

# 安装 Autoconf. Autoconf 软件包包含生成能自动配置软件包的 shell 脚本的程序。 
install_tools_to_lfs 'autoconf' '' '' '&& make check TESTSUITEFLAGS=-j4 && make install'

# 安装 Automake. Automake 软件包包含自动生成 Makefile，以便和 Autoconf 一同使用的程序。
install_tools_to_lfs 'automake' "sed -i \"s/''/etags/\" t/tags-lisp-space.sh" '--docdir=/usr/share/doc/automake-1.16.3' '&& make -j4 check || true && make install'

# 安装 Kmod. Kmod 软件包包含用于加载内核模块的库和工具。 
install_tools_to_lfs 'kmod' '' '--sysconfdir=/etc      \
            --with-xz              \
            --with-zstd            \
            --with-zlib' '&& make install'
# 创建与 Module-Init-Tools (曾经用于处理 Linux 内核模块的软件包) 兼容的符号链接：
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done
ln -sfv kmod /usr/bin/lsmod

# 安装 Libelf. Libelf 是一个处理 ELF (可执行和可链接格式) 文件的库。
install_tools_to_lfs 'elfutils' '' '--disable-debuginfod         \
            --enable-libdebuginfod=dummy' '&& make check && make -C libelf install && install -vm644 config/libelf.pc /usr/lib/pkgconfig '
rm /usr/lib/libelf.a

# 安装 Libffi. Libffi 库提供一个可移植的高级编程接口，用于处理不同调用惯例。这允许程序在运行时调用任何给定了调用接口的函数。
install_tools_to_lfs 'libffi' '' '--disable-static --with-gcc-arch=native' '&& make check && make install'

# 安装 OpenSSL. OpenSSL 软件包包含密码学相关的管理工具和库。它们被用于向其他软件包提供密码学功能，例如 OpenSSH，电子邮件程序和 Web 浏览器 (以访问 HTTPS 站点)。
start_tool openssl
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
# 编译该软件包：
make
# 运行以下命令以测试编译结果：
make test
# 一项名为 30-test_afalg.t 的测试在某些内核配置下会失败 (它假定选择了一些未说明的内核配置选项)。
# 安装该软件包：
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
# 将版本号添加到文档目录名，以和其他软件包保持一致：
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1k
# 如果需要的话，安装一些额外的文档：
cp -vfr doc/* /usr/share/doc/openssl-1.1.1k
end_tool openssl

# 安装 Python 3.9.6
install_tools_to_lfs 'Python' '' '--enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes \
            --enable-optimizations' '&& make install'
# 安装预先格式化的文档
install -v -dm755 /usr/share/doc/python-3.9.6/html 
tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.9.6/html \
    -xvf python-3.9.6-docs-html.tar.bz2

# 安装 Ninja. Ninja 是一个注重速度的小型构建系统。
start_tool ninja
# 如果您希望 Ninja 能够使用环境变量 NINJAJOBS，执行以下命令，添加这一功能：
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
# 构建 Ninja：
python3 configure.py --bootstrap
# 运行以下命令以测试编译结果：
./ninja ninja_test
./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
# 安装该软件包：
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
end_tool ninja

# 安装 Meson. Meson 是一个开放源代码构建系统，它的设计保证了非常快的执行速度，和尽可能高的用户友好性。 
start_tool meson
# 执行以下命令编译 Meson：
python3 setup.py build
# 安装该软件包：
python3 setup.py install --root=dest
cp -rv dest/* /
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
end_tool meson

#安装 Coreutils. Coreutils 软件包包含用于显示和设定系统基本属性的工具。 
start_tool coreutils
# POSIX 要求 Coreutils 中的程序即使在多字节 locale 中也能正确识别字符边界。下面应用一个补丁，以解决 Coreutils 不满足该要求的问题，并修复其他一些国际化相关的 bug：
patch -Np1 -i ../coreutils-8.32-i18n-1.patch
# 阻止一个在某些机器上会无限循环的测试：
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
# 现在准备编译 Coreutils：
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
# 编译该软件包：
make
# 现在测试套件已经可以运行了。首先运行那些设计为由 root 用户运行的测试：
make NON_ROOT_USERNAME=tester check-root
# 之后我们要以 tester 用户身份运行其余测试。然而，某些测试要求测试用户属于至少一个组。为了不跳过这些测试，我们添加一个临时组，并使得 tester 用户成为它的成员：
echo "dummy:x:102:tester" >> /etc/group
# 修正访问权限，使得非 root 用户可以编译和运行测试：
chown -Rv tester . 
# 现在运行测试：
su tester -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check || true"
# 已知名为 test-getlogin 的测试在 LFS chroot 环境中可能失败。
# 删除临时组：
sed -i '/dummy/d' /etc/group
# 安装该软件包：
make install
# 将程序移动到 FHS 要求的位置：
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
end_tool coreutils

# 安装 Check. Check 是一个 C 语言单元测试框架。
install_tools_to_lfs 'check' '' '--disable-static' '&& make check && make docdir=/usr/share/doc/check-0.15.2 install'

# 安装 Diffutils. Diffutils 软件包包含显示文件或目录之间差异的程序。 
install_tools_to_lfs 'diffutils' '' '' '&& make check && make install'

# 安装 Gawk
install_tools_to_lfs 'gawk' "sed -i 's/extras//' Makefile.in" '' '&& make check && make install && mkdir -v /usr/share/doc/gawk-5.1.0 && cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.1.0'

# 安装 Findutils. Findutils 软件包包含用于查找文件的程序。这些程序能够递归地搜索目录树，以及创建、维护和搜索文件数据库 (一般比递归搜索快，但在数据库最近没有更新时不可靠)。 
install_tools_to_lfs 'findutils' '' '--localstatedir=/var/lib/locate' '&& chown -Rv tester . && su tester -c "PATH=$PATH make check" && make install'

# 安装 Groff. Groff 软件包包含处理和格式化文本的程序。
start_tool groff
#Groff 期望环境变量 PAGE 包含默认纸张大小。对于美国用户来说，PAGE=letter 是正确的。对于其他地方的用户，PAGE=A4 可能更好。尽管在编译时配置了默认纸张大小，可以通过写入 “A4” 或 “letter” 到 /etc/papersize 文件，覆盖默认值。 
# 准备编译 Groff：
PAGE=A4 ./configure --prefix=/usr
# 该软件包不支持并行构建。编译该软件包：
make -j1
# 安装该软件包：
make install
end_tool groff

# 安装 GRUB (不支持UEFI)
install_tools_to_lfs 'grub' '' '--sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror' '&& make install && mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions'

# 安装 Gzip
install_tools_to_lfs 'gzip' '' '' '&& make check && make install'

# 安装 IPRoute2. IPRoute2 软件包包含基于 IPv4 的基本和高级网络程序。
start_tool iproute2
# 该软件包中的 arpd 程序依赖于 LFS 不安装的 Berkeley DB，因此不会被构建。然而，用于 arpd 的一个目录和它的 man 页面仍会被安装。运行以下命令以防止它们的安装。如果需要使用 arpd 二进制程序，参考 BLFS 手册中的 Berkeley DB 编译说明，它位于 https://www.linuxfromscratch.org/blfs/view/svn/server/db.html。
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
# 还需要禁用两个需要 https://www.linuxfromscratch.org/blfs/view/svn/postlfs/iptables.html 的模块。
sed -i 's/.m_ipt.o//' tc/Makefile
# 编译该软件包：
make
# 安装该软件包：
make SBINDIR=/usr/sbin install
# 如果需要的话，安装文档：
mkdir -v              /usr/share/doc/iproute2-5.13.0
cp -v COPYING README* /usr/share/doc/iproute2-5.13.0
end_tool iproute2

# 安装 Kbd. Kbd 软件包包含按键表文件、控制台字体和键盘工具。 
start_tool kbd
# 退格和删除键的行为在 Kbd 软件包的不同按键映射中不一致。以下补丁修复 i386 按键映射中的这个问题：
patch -Np1 -i ../kbd-2.4.0-backspace-1.patch
# 删除多余的 resizecons 程序 (它需要已经不存在的 svgalib 提供视频模式文件 —— 一般使用 setfont 即可调整控制台大小) 及其 man 页面。
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
# 准备编译 Kbd：
./configure --prefix=/usr --disable-vlock
# 编译该软件包：
make
# 运行以下命令以测试编译结果：
make check
# 安装该软件包：
make install
# 如果需要的话，安装文档：
mkdir -v            /usr/share/doc/kbd-2.4.0
cp -R -v docs/doc/* /usr/share/doc/kbd-2.4.0
end_tool kbd

# 安装 Libpipeline. Libpipeline 软件包包含用于灵活、方便地处理子进程流水线的库。 
install_tools_to_lfs 'libpipeline' '' '' '&& make check && make install'

# 安装 Make
install_tools_to_lfs 'make' '' '' '&& make check && make install'

# 安装 Patch
install_tools_to_lfs 'patch' '' '' '&& make check && make install'

# 安装 Tar 
start_tool tar
# 准备编译 Tar：
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr
# 编译该软件包：
make
# 执行以下命令测试编译结果 (需要约 3 SBU)：
make check || true
# 一项名为 capabilities: binary store/restore 的测试在运行时会失败，然而如果宿主系统的内核在构建 LFS 使用的文件系统上不支持扩展属性，该测试会被跳过。
# 安装该软件包：
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.34
end_tool tar

# 安装 Texinfo. Texinfo 软件包包含阅读、编写和转换 info 页面的程序。
install_tools_to_lfs 'texinfo' '' '' '&& make check && make install && make TEXMF=/usr/share/texmf install-tex'
# Info 文档系统使用一个纯文本文件保存目录项的列表。该文件位于 /usr/share/info/dir。不幸的是，由于一些软件包 Makefile 中偶然出现的问题，它有时会与系统实际安装的 info 页面不同步。如果需要重新创建 /usr/share/info/dir 文件，可以运行以下命令完成这一工作：
pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd

# 安装 Vim. 
start_tool vim
# 修改 vimrc 配置文件的默认位置为 /etc：
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
# 准备编译 Vim：
./configure --prefix=/usr
# 编译该软件包：
make
# 为了准备运行测试套件，需要使得 tester 用户拥有写入源代码目录树的权限：
chown -Rv tester .
# 现在，以 tester 用户身份运行测试：
su tester -c "LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
grep 'ALL DONE' vim-test.log
# 测试套件会将大量二进制数据输出到屏幕。这可能扰乱当前终端设置。为了避免这个问题，像上面的命令一样，将输出重定向到日志文件。测试成功完成后，日志文件末尾会包含 “ALL DONE”。
# 安装该软件包：
make install
# 许多用户习惯于使用命令 vi，而不是 vim。为了在用户习惯性地输入 vi 时能够执行 vim，为二进制程序和各种语言的 man 页面创建符号链接：
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
# 默认情况下，Vim 的文档安装在 /usr/share/vim 中。下面创建符号链接，使得可以通过 /usr/share/doc/vim-8.2.3001 访问符号链接，这个路径与其他软件包的文档位置格式一致：
ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.3001
end_tool vim
# 配置 Vim
# 默认情况下，vim 在不兼容 vi 的模式下运行。这对于过去使用其他编辑器的用户来说可能显得陌生。以下配置包含的 “nocompatible” 设定是为了强调编辑器使用了新的行为这一事实。它也提醒那些想要使用 “compatible” 模式的用户，必须在配置文件的一开始改变模式。这是因为它会修改其他设置，对这些设置的覆盖必须在设定模式后进行。执行以下命令创建默认 vim 配置文件：
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

# 安装 Eudev. Eudev 软件包包含动态创建设备节点的程序。
install_tools_to_lfs 'eudev' '' '--bindir=/usr/sbin      \
            --sysconfdir=/etc       \
            --enable-manpages       \
            --disable-static' '&& mkdir -pv /usr/lib/udev/rules.d && mkdir -pv /etc/udev/rules.d && make check && make install && tar -xvf ../udev-lfs-20171102.tar.xz && make -f udev-lfs-20171102/Makefile.lfs install'
# 配置 Eudev
# 硬件设备的相关信息被维护在 /etc/udev/hwdb.d 和 /usr/lib/udev/hwdb.d 目录中。Eudev 需要将这些信息编译到二进制数据库 /etc/udev/hwdb.bin 中。初始化该数据库：
udevadm hwdb --update
# 每次硬件信息有更新时，都要运行该命令。 

# 安装 Man-DB. Man-DB 软件包包含查找和阅读 man 页面的程序。
install_tools_to_lfs 'man-db' '' '--docdir=/usr/share/doc/man-db-2.9.4 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=' '&& make check && make install'

# 安装 Procps-ng. Procps-ng 软件包包含监视进程的程序。
if [ -f procps-ng-3.3.17.tar.xz ]; then mv -vf procps-ng-3.3.17.tar.xz procps-3.3.17.tar.xz; fi
install_tools_to_lfs 'procps' '' '--docdir=/usr/share/doc/procps-ng-3.3.17 \
            --disable-static                         \
            --disable-kill' '&& make check || true && make install'

# 安装 Util-linux. Util-linux 软件包包含若干工具程序。这些程序中有处理文件系统、终端、分区和消息的工具。 
start_tool util-linux-2
# 准备安装 Util-linux：
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
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
            --without-systemd    \
            --without-systemdsystemunitdir \
            runstatedir=/run
# 编译该软件包：
make
# 以非 root 用户身份运行测试套件： 
#  一项测试依赖于特定内核配置。如果 CONFIG_USER_NS 或 CONFIG_PID_NS 没有设定，该测试会陷入无限等待状态。删除这项测试，以绕过这个问题：
rm tests/ts/lsns/ioctl_ns
chown -Rv tester .
su tester -c "make -k check"
# 安装该软件包：
make install
# 最后，安装 man 页面：
tar -xf ../util-linux-man-pages-2.37.tar.xz --directory /usr/share/man --strip-components=1
end_tool util-linux-2

# 安装 E2fsprogs. E2fsprogs 软件包包含处理 ext2 文件系统的工具。此外它也支持 ext3 和 ext4 日志文件系统。
install_tools_to_lfs 'e2fsprogs' 'mkdir -v build && cd build' '--sysconfdir=/etc       \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck' '&& make check || true && make install' \
             'gunzip -v /usr/share/info/libext2fs.info.gz && install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info && makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo && install -v -m644 doc/com_err.info /usr/share/info && install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info'

# 删除无用的静态库： 
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

# 安装 Sysklogd. Sysklogd 软件包包含记录系统消息的程序，例如在意外情况发生时内核给出的消息。 
start_tool sysklogd
# 首先，修复 klogd 中在特定情况下会发生段错误的问题，并改正一个已弃用的程序结构：
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
# 编译该软件包：
make
# 安装该软件包：
make BINDIR=/sbin install
end_tool sysklogd
# 配置 Sysklogd
# 执行以下命令，创建一个新的 /etc/syslog.conf 文件：
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF

# 安装 Sysvinit. Sysvinit 软件包包含控制系统启动、运行和关闭的程序。
start_tool sysvinit
# 首先，应用一个补丁，它会删除 sysvinit 中其他软件包已经安装的程序，使一条消息更加清晰，并修复一个引发编译器警告的问题：
patch -Np1 -i ../sysvinit-2.99-consolidated-1.patch
# 编译该软件包：
make
# 安装该软件包：
make install
end_tool sysvinit



# 再次移除调试符号
# 许多程序和库在默认情况下被编译为带有调试符号的二进制文件 (通过使用 gcc 的 -g 选项)。这意味着在调试这些带有调试信息的程序和库时，调试器不仅能给出内存地址，还能给出子程序和变量的名称。 
# 由于大多数用户永远不会用调试器调试系统软件，可以通过移除它们的调试符号，回收大量磁盘空间。

# 首先将一些库的调试符号保存在单独的文件中。之后在 BLFS 中，如果使用 valgrind 或 gdb 运行退化测试，则需要这些调试信息的存在。
save_usrlib="ld-2.33.so libc-2.33.so libpthread-2.33.so libthread_db-1.0.so
             libquadmath.so.0.0.0 libstdc++.so.6.0.29
             libitm.so.1.0.0 libatomic.so.1.2.0" 
cd /usr/lib
for LIB in $save_usrlib; do
    objcopy --only-keep-debug $LIB $LIB.dbg
    strip --strip-unneeded $LIB
    objcopy --add-gnu-debuglink=$LIB.dbg $LIB
done
unset LIB save_usrlib
# 现在即可移除程序和库的调试符号：
find /usr/lib -type f -name \*.a \
   -exec strip --strip-debug {} ';'
find /usr/lib -type f -name \*.so* ! -name \*dbg \
   -exec strip --strip-unneeded {} ';'
find /usr/{bin,sbin,libexec} -type f \
    -exec strip --strip-all {} ';'


# 清理系统. 清理在执行测试的过程中遗留的一些文件：
rm -rf /tmp/*

# 登出
logout
