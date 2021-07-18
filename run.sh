#!/bin/bash

set -e

# https://bf.mengyan1223.wang/lfs/zh_CN/development/LFS-BOOK.html

# env
LFS_DISK=/dev/sdb1
# 

# 安装必须的软件
ln -f -s /bin/bash /bin/sh

# 您的宿主系统必须拥有下列软件，且版本不能低于我们给出的最低版本。对于大多数现代 Linux 发行版来说这不成问题。要注意的是，很多发行版会把软件的头文件放在单独的软件包中，
# 这些软件包的名称往往是 “<软件包名>-devel” 或者 “<软件包名>-dev”。如果您的发行版为下列软件提供了这类软件包，一定要安装它们。 
# 为了确定您的宿主系统拥有每个软件的合适版本，且能够编译程序，请运行下列脚本。
cat > version-check.sh << "EOF"
#!/bin/bash
# Simple script to list version numbers of critical development tools
export LC_ALL=C
bash --version | head -n1 | cut -d" " -f2-4
MYSH=$(readlink -f /bin/sh)
echo "/bin/sh -> $MYSH"
echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
unset MYSH

echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
bison --version | head -n1

if [ -h /usr/bin/yacc ]; then
  echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
elif [ -x /usr/bin/yacc ]; then
  echo yacc is `/usr/bin/yacc --version | head -n1`
else
  echo "yacc not found" 
fi

bzip2 --version 2>&1 < /dev/null | head -n1 | cut -d" " -f1,6-
echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
diff --version | head -n1
find --version | head -n1
gawk --version | head -n1

if [ -h /usr/bin/awk ]; then
  echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
elif [ -x /usr/bin/awk ]; then
  echo awk is `/usr/bin/awk --version | head -n1`
else 
  echo "awk not found" 
fi

gcc --version | head -n1
g++ --version | head -n1
ldd --version | head -n1 | cut -d" " -f2-  # glibc version
grep --version | head -n1
gzip --version | head -n1
cat /proc/version
m4 --version | head -n1
make --version | head -n1
patch --version | head -n1
echo Perl `perl -V:version`
python3 --version
sed --version | head -n1
tar --version | head -n1
makeinfo --version | head -n1  # texinfo version
xz --version | head -n1

echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
if [ -x dummy ]
  then echo "g++ compilation OK";
  else echo "g++ compilation failed"; fi
rm -f dummy.c dummy
EOF

bash version-check.sh

# 在本书中，我们经常使用环境变量 LFS。您应该保证，在构建 LFS 的全过程中，该变量都被定义且设置为您构建 LFS 使用的目录 —— 我们使用 /mnt/lfs 作为例子，但您可以选择其他目录。
# 如果您在一个独立的分区上构建 LFS，那么这个目录将成为该分区的挂载点。选择一个目录，然后用以下命令设置环境变量：
export LFS=/mnt/lfs

# 创建挂载点，并挂载 LFS 文件系统
sudo mkdir -pv $LFS
sudo mount -v -t ext4 $LFS_DISK $LFS

# 本章包含了构建基本的 Linux 系统时需要下载的软件包列表。 下载好的软件包和补丁需要保存在一个适当的位置，使得在整个构建过程中都能容易地访问它们。另外，还需要一个工作目录，
# 以便解压和编译软件包。我们可以将 $LFS/sources 既用于保存软件包和补丁，又作为工作目录。这样，我们需要的所有东西都在 LFS 分区中，因此在整个构建过程中都能够访问。
# 为了创建这个目录，在开始下载软件包之前，以root身份执行： 
sudo mkdir -v $LFS/sources
# 为该目录添加写入权限和 sticky 标志。“Sticky” 标志使得即使有多个用户对该目录有写入权限，也只有文件所有者能够删除其中的文件。输入以下命令，启用写入权限和 sticky 标志：
sudo chmod -v a+wt $LFS/sources

# 获取构建 LFS 必须的软件包和补丁
wget -c https://bf.mengyan1223.wang/lfs/zh_CN/development/wget-list
wget -c -P $LFS/sources https://bf.mengyan1223.wang/lfs/zh_CN/development/md5sums
wget -c wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
# 检查所有软件包的正确性
pushd $LFS/sources
md5sum -c md5sums
popd

# 除了软件包外，我们还需要一些补丁。有些补丁解决了本应由维护者修复的问题，有些则对软件包进行微小的修改，使得它们更容易使用。构建 LFS 系统需要下列补丁
cat > wget-list-patch << "EOF"
https://www.linuxfromscratch.org/patches/lfs/development/bzip2-1.0.8-install_docs-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/coreutils-8.32-i18n-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/glibc-2.33-fhs-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/gcc-11.1.0-upstream_fixes-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/kbd-2.4.0-backspace-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/kbd-2.4.0-backspace-1.patch
https://www.linuxfromscratch.org/patches/lfs/development/sysvinit-2.99-consolidated-1.patch
EOF

cat > $LFS/sources/md5sums-patch << "EOF"
6a5ac7e89b791aae556de0f745916f7f  bzip2-1.0.8-install_docs-1.patch
cd8ebed2a67fff2e231026df91af6776  coreutils-8.32-i18n-1.patch
9a5997c3452909b1769918c759eff8a2  glibc-2.33-fhs-1.patch
27266d2a771f2ff812cb6ec9c8b456b4  gcc-11.1.0-upstream_fixes-1.patch
f75cca16a38da6caa7d52151f7136895  kbd-2.4.0-backspace-1.patch
4900322141d493e74020c9cf437b2cdc  sysvinit-2.99-consolidated-1.patch
EOF

wget --input-file=wget-list-patch --continue --directory-prefix=$LFS/sources

# 检查所有补丁包的正确性
pushd $LFS/sources
md5sum -c md5sums-patch
popd

# 在 LFS 文件系统中创建有限目录布局, 使得在第 6 章中编译的程序 (以及第 5 章中的 glibc 和 libstdc++) 可以被安装到它们的最终位置。
sudo mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  sudo ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) sudo mkdir -pv $LFS/lib64 ;;
esac

# 在第 6 章中，会使用交叉编译器编译程序 (细节参见工具链技术说明一节)。为了将这个交叉编译器和其他程序分离，它会被安装在一个专门的目录。执行以下命令创建该目录
sudo mkdir -pv $LFS/tools

# 添加 LFS 用户
# 在作为 root 用户登录时，一个微小的错误就可能损坏甚至摧毁整个系统。因此，我们建议在后续两章中，以非特权用户身份编译软件包。
# 您可以使用自己的系统用户，但为了更容易地建立一个干净的工作环境，最好创建一个名为 lfs 的新用户，以及它从属于的一个新组 (组名也是 lfs)，以便我们在安装过程中使用。
# 为了创建新用户，以 root 身份执行以下命令：
sudo groupadd lfs
sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
# 为 lfs 设置密码，密码为lfs
echo -e 'lfs\nlfs' | sudo passwd lfs
# 设置lfs账号可以免密执行sudo xxx命令，为后续以 lfs 的身份执行命令做好准备。 add by zw
echo "lfs ALL=NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/lfs"

# 将 lfs 设为 $LFS 中所有目录的所有者，使 lfs 对它们拥有完全访问权：
sudo chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) sudo chown -v lfs $LFS/lib64 ;;
esac
# 如果您按照本书的建议，建立了一个单独的工作目录，那么将这个目录的所有者也设为 lfs：
sudo chown -v lfs $LFS/sources

# 以 lfs 的身份登录。参数 “-” 使得 su 启动一个登录 shell，而不是非登录 shell。
sudo su - lfs

# 为了配置一个良好的工作环境，我们为 bash 创建两个新的启动脚本。以 lfs 的身份，执行以下命令，创建一个新的 .bash_profile：
# 在以 lfs 用户登录时，初始的 shell 一般是一个登录 shell。它读取宿主系统的 /etc/profile 文件 (可能包含一些设置和环境变量)，然后读取 .bash_profile。
# 我们在 .bash_profile 中使用 exec env -i.../bin/bash 命令，新建一个除了 HOME, TERM 以及 PS1 外没有任何环境变量的 shell，替换当前 shell，
# 防止宿主环境中不必要和有潜在风险的环境变量进入编译环境。通过使用以上技巧，我们创建了一个干净环境。 
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
# 新的 shell 实例是 非登录 shell，它不会读取和执行 /etc/profile 或者 .bash_profile 的内容，而是读取并执行 .bashrc 文件。
# 现在我们就创建一个 .bashrc 文件：
#
# +h 命令关闭 bash 的散列功能。一般情况下，散列是很有用的 —— bash 使用一个散列表维护各个可执行文件的完整路径，
# 这样就不用每次都在 PATH 指定的目录中搜索可执行文件。然而，在构建 LFS 时，我们希望总是使用最新安装的工具。
# 因此，需要关闭散列功能，使得 shell 在运行程序时总是搜索 PATH。这样，shell 总是能够找到 $LFS/tools 目录中那些最
# 新编译的工具，而不是使用之前记忆的另一个目录中的程序。
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

#  一些商业发行版未做文档说明地将 /etc/bash.bashrc 引入 bash 初始化过程。该文件可能修改 lfs 用户的环境，并影响 LFS 关键软件包的构建。为了保证 lfs 用户环境的纯净，检查 /etc/bash.bashrc 是否存在，如果它存在就将它移走。以 root 用户身份，运行：
# 后续可以复原 /etc/bash.bashrc 文件
[ ! -e /etc/bash.bashrc ] || sudo mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
# 为了完全准备好编译临时工具的环境，指示 shell 读取刚才创建的配置文件：
source ~/.bash_profile


# 概念  https://www.jianshu.com/p/62613863aed0
# "build, haost, target"
# build：构建 gcc 编译器的平台系统环境，编译该软件使用的平台。
# host：是执行 gcc 编译器的平台系统环境，该软件将运行的平台。
# target：是让 gcc 编译器产生能在什么格式运行的平台的系统环境，该软件所处理的目标平台。
#
# 在gcc编译中我们使用    https://blog.csdn.net/u013246792/article/details/96701557
#　　./configure --build=编译平台　--host=运行平台　--target=目标平台　[各种编译参数]
# build：表示目前我们正在运行的平台名称是什么. 自动测试在用平台名称，若无法检测出来则需要指定。
# host：表示我们把这个编译好的gcc在什么样的平台下运行. 若无指定，自动使用build的结果。
# build和host相同时表示本地编译，若不相同则表示交叉编译。
# target：该参数的目的是让配置程序知道这个软件被编译后使用来处理什么平台上的文件的。
# target这个参数只有在为数不多的几个包中有用处，虽然在./configure --help中经常能看到该参数，但实际上绝大多数软件包都是不需要该参数的。
#　从这个参数的含义来看，说明其处理的目标只有在不同平台下表现为不同的时候才有作用，而这些文件通常都跟目标平台 的指令系统直接或间接有关：比如可执行文件，对于不同平台下使用的可执行文件的编码可以是完全不同的，因此必须使用 对应能处理该编码的程序才能正确处理，而如果错误的使用则可能导致程序错误或者破坏文件，对于这样要处理不同平台下会 出现不同编码的软件，我们就应当对它指定目标平台，以免另其错误处理；而对于文本文件，对于不同的平台同样的内容表达的 含义都是相同的，因此我们不需要专门针对平台来处理，这样的软件我们就可以不必对它指定需要处理的平台了。
#  表示需要处理的目标平台名称，若无指定使用host相同名称，gcc、binutils等与平台指令相关软件有此参数，多数软件此参数无用处。
#
# 三元组： CPU-供应商-内核-操作系统  比如对于 64 位系统输出应该是 x86_64-pc-linux-gnu
# 有一种简单方法可以获得您的机器的三元组，即运行许多软件包附带的 config.guess 脚本。解压缩 Binutils 源码，
# 然后运行脚本：./config.guess，观察输出。例如，对于 32 位 Intel 处理器，输出应该是 i686-pc-linux-gnu，而对于 64 位系统输出应该是 x86_64-pc-linux-gnu。
#
# 平台的动态链接器的名称，它又被称为动态加载器 (不要和 Binutils 中的普通链接器 ld 混淆)。动态链接器由 Glibc 提供，
# 它寻找并加载程序所需的共享库，为程序运行做好准备，然后运行程序。在 32 位 Intel 机器上动态链接器的名称是 ld-linux.so.2 
# (在 64 位系统上是 ld-linux-x86-64.so.2)。一个确定动态链接器名称的准确方法是从宿主系统找一个二进制可执行文件，
# 然后执行：readelf -l <二进制文件名> | grep interpreter 并观察输出。包含所有平台的权威参考可以在 Glibc 源码树根
# 目录的 shlib-versions 文件中找到。 
# 
# build与host不同是交叉编译器；build与target不同是交叉编译链(交叉链接器)；三者都相同则为本地编译。
# 交叉编译器 + 交叉链接器 组成交叉编译工具链
# 指定：- -build=X86, - -host=X86, - -target=X86
#  使用X86下构建X86的gcc编译器，编译出能在X86下运行的程序。
# 指定：- -build=X86, - -host=ARM, - -target=MIPS
#  在X86下构建 gcc交叉编译器，在ARM上运行 gcc交叉编译器，编译出能在 MIPS 运行的可执行程序。


## LFS 的交叉编译实现
# build：指构建程序时使用的机器。注意在某些其他章节，这台机器被称为“host”(宿主)。
# host：指将来会运行被构建的程序的机器。注意这里说的“host”与其他章节使用的“宿主”(host) 一词不同。
# target：只有编译器使用这个术语。编译器为这台机器产生代码。它可能和 build 与 host 都不同。
# 交叉编译器: 它们为与它们本身运行的机器不同的机器产生代码。
# 本地编译器: 为它们本身运行的机器产生代码。
#
# 阶段 	Build 	Host 	Target 	操作描述
#  1 	  pc 	    pc    lfs     在 pc 上使用 cc-pc 构建交叉编译器 cc1
#  2 	  pc 	    lfs 	lfs 	  在 pc 上使用 cc1 构建本地编译器 cc-lfs
#  3 	  lfs 	  lfs 	lfs 	  在 lfs 上使用 cc-lfs 重新构建并测试它本身
# 在上表中，“在 pc 上” 意味着命令在已经安装好的发行版中执行。“在 lfs 上” 意味着命令在 chroot 环境中执行。
# 为了将本机伪装成交叉编译目标机器，我们在 LFS_TGT 变量中，对宿主系统三元组的 "vendor" 域进行修改。我们还会在构建
# 交叉链接器和交叉编译器时使用 --with-sysroot 选项，指定查找所需的 host 系统文件的位置。这保证在第一遍编译中的其他程
# 序在构建时不会链接到宿主 (build) 系统的库。前两个阶段是必要的，第三个阶段不是必须的，但可以用于测试.
#
# 解决编译循环依赖问题.
# 现在，关于交叉编译，还有更多要处理的问题：C 语言并不仅仅由一个编译器实现，它还规定了一个标准库。在本书中，
# 我们使用 GNU C 运行库，即 glibc。它必须为 lfs 目标机器使用交叉编译器 cc1 编译。但是，编译器本身使用一个库，
# 实现汇编指令集并不支持的一些复杂指令。这个内部库称为 libgcc，它必须链接到 glibc 库才能实现完整功能！另外，
# C++ 标准库 (libstdc++) 也必须链接到 glibc。为了解决这个”先有鸡还是先有蛋“的问题，只能先构建一个降级的 cc1，
# 它的 libgcc 缺失线程和异常等功能，再用这个降级的编译器构建 glibc (这不会导致 glibc 缺失功能)，再构建 libstdc++。
# 但是这种方法构建的 libstdc++ 和 libgcc 一样，会缺失一些功能。
# 
# 讨论还没有结束：上面一段的结论是 cc1 无法构建功能完整的 libstdc++，但这是我们在阶段 2 构建 C/C++ 库时唯一可用
# 的编译器！当然，在阶段 2 中构建的编译器 cc-lfs 将会可以构建这些库，但是 (1) GCC 构建系统不知道这个编译器在 pc 
# 上可以使用，而且 (2) 它是一个本地编译器，因此在 pc 上使用它可能产生链接到 pc (宿主系统) 库的风险。因此我们必须
# 在进入 chroot 后再次构建 libstdc++。 


# 编译交叉工具链
# 编译的程序(交叉工具链)会被安装在 $LFS/tools 目录中，以将它们和后续章节中安装的文件分开。
# 但是，本章中编译的库会被安装到它们的最终位置，因为这些库在我们最终要构建的系统中也存在。 

# 切换到放着源码包的目录。
cd $LFS/sources



## 第一遍、第二遍编译
# 对应上文的1,2阶段
# 阶段 	Build 	Host 	Target 	操作描述
# 1 	  pc 	    pc 	  lfs 	  在 pc 上使用 cc-pc 构建交叉编译器 cc1
# 2 	  pc 	    lfs 	lfs 	  在 pc 上使用 cc1 构建本地编译器 cc-lfs 
# 总目标是构造一个临时环境，它包含一组可靠的，能够与宿主系统完全分离的工具。这样，第三遍编译时使用 chroot 命令后，
# 再次执行的命令就被限制在这个临时环境中。这确保我们能够干净、顺利地构建 LFS 系统。
# 第一遍、第二遍构建过程是基于交叉编译过程的。交叉编译通常被用于为一台与本机完全不同的计算机构建编译器及其工具链。
# 这对于 LFS 并不严格必要，因为新系统运行的机器就是构建它时使用的。但是，交叉编译拥有一项重要优势，即任何交叉编译
# 产生的程序都不可能依赖于宿主环境。 
## 

##
# 第一遍编译: 在 pc 上使用 cc-pc 构建交叉编译器 cc1
##
# 安装交叉工具链中的汇编工具 Binutils, 首先构建 Binutils 相当重要，因为 Glibc 和 GCC 都会对可用的链接器和汇编器进行测试，以决定可以启用它们自带的哪些特性。
binutils_xz=$(ls binutils*.tar.xz)
tar -xf $binutils_xz
cd ${binutils_xz:0:-7}
# Binutils 文档推荐在一个专用的目录中构建 Binutils：
mkdir -v build
cd build

# 配置编译，准备编译Binutils
# --with-sysroot=$LFS 该选项告诉构建系统，交叉编译时在 $LFS 中寻找目标系统的库。
# --with-sysroot用来指定系统的root。该选项主要用于新系统（比如LFS）构建或交叉编译。比如你的LFS的root在/mnt/lfs，
# 那么configure时指定--with-sysroot=/mnt/lfs，编译器就会使用/mnt/lfs上的header和lib，而不是host上的。交叉编译
# 器也会设定sysroot，避免搜索默认的header和lib路径。可以写个最小程序然后gcc -v main.c，如果编译器的sysroot非默认，
# 就会打印出sysroot路径。
#
# --target=$LFS_TGT  由于 LFS_TGT 变量中的机器描述和 config.guess 脚本的输出略有不同, 这个开关使得 configure 脚
# 本调整 Binutils 的构建系统，以构建交叉链接器。
../configure --prefix=$LFS/tools       \
             --with-sysroot=$LFS        \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror

# 编译Binutils
make
# 安装Binutils
make install -j1

cd ../../
rm -rf ${binutils_xz:0:-7}


# (第一遍)安装交叉工具链中的 GCC, 即上文提到的第一遍编译中的交叉编译器 cc1
# GCC 依赖于 GMP、MPFR 和 MPC 这三个包。由于宿主发行版未必包含它们，
gcc_xz=$(ls gcc*.tar.xz)
tar -xf $gcc_xz
cd ${gcc_xz:0:-7}

# 我们将它们和 GCC 一同构建。将它们都解压到 GCC 源码目录中，并重命名解压出的目录，这样 GCC 构建过程就能自动使用它们：
tar -xf ../mpfr-*.tar.xz
mv -v mpfr-* mpfr
tar -xf ../gmp-*.tar.xz
mv -v gmp-* gmp
tar -xf ../mpc-*.tar.gz
mv -v mpc-* mpc

# 对于 x86_64 平台，还要设置存放 64 位库的默认目录为 “lib”：
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
# GCC 文档建议在一个专用目录中构建 GCC：
mkdir -v build
cd build
#  准备编译 GCC：
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=$LFS/tools                            \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++

# 执行以下命令编译 GCC：
make
# 安装GCC软件包：
make install
# 创建一个完整版本的内部头文件
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h

cd ../
rm -rf ${gcc_xz:0:-7}


# 安装 Linux API 头文件. Linux API 头文件 (在 linux-5.13.1.tar.xz 中) 导出内核 API 供 Glibc 使用
kernel_xz=$(ls linux*.tar.xz)
tar -xf $kernel_xz
cd ${kernel_xz:0:-7}

# 确保软件包中没有遗留陈旧的文件：
make mrproper
# 从源代码中提取用户可见的头文件。我们不能使用推荐的 make 目标“headers_install”，因为它需要 rsync，
# 这个程序在宿主系统中未必可用。头文件会先被放置在 ./usr 目录中，之后再将它们复制到最终的位置。 
make headers
find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include $LFS/usr

cd ../
rm -rf ${kernel_xz:0:-7}


# 安装 Glibc. Glibc 软件包包含主要的 C 语言库。它提供用于分配内存、检索目录、打开和关闭文件、读写文件、字符串处理、模式匹配、算术等用途的基本子程序。
glibc_xz=$(ls glibc*.tar.xz)
tar -xf $glibc_xz
cd ${glibc_xz:0:-7}

# 创建一个 LSB 兼容性符号链接。另外，对于 x86_64，创建一个动态链接器正常工作所必须的符号链接$LFS/lib64/ld-linux-x86-64.so.2
# LSB是一套核心标准，它保证了LINUX发行版同LINUX应用程序之间的良好结合。 LSB(全称：Linux Standards Base)
# 以下操作兼容了LSB 3.0标准. 即创建了LSB 3.0兼容性符号链接lib64/ld-lsb-x86-64.so.3，类似于ubuntu里的 sudo apt-get install lsb. 
# 使得符合LSB 3.0标准的应用程序可以链接到$LFS/下的库并正常运行。
# 如果要兼容LSB 2.0标准，还需要创建LSB 2.0兼容性符号链接lib64/ld-lsb-x86-64.so.2
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

#  一些 Glibc 程序使用与 FHS 不兼容的 /var/db 目录存放它们的运行时数据。
# 下面应用一个补丁，使得这些程序在 FHS 兼容的位置存放运行时数据.
# FHS标准(英文：Filesystem Hierarchy Standard 中文:文件系统层次结构标准)，多数Linux版本采用这种文件组织形式，
# FHS定义了系统中每个区域的用途、所需要的最小构成的文件和目录同时还给出了例外处理与矛盾处理。 FHS定义了两层规范，
# 第一层是， / 下面的各个目录应该要放什么文件数据，例如/etc应该要放置设置文件，/bin与/sbin则应该要放置可执行文件等等。 
# 第二层则是针对/usr及/var这两个目录的子目录来定义。例如/var/log放置系统登录文件、/usr/share放置共享数据等等。
patch -Np1 -i ../glibc-2.33-fhs-1.patch

# 修复使用 gcc-11.1 构建时出现的问题：
sed 's/amx_/amx-/' -i sysdeps/x86/tst-cpu-features-supports.c

# Glibc 文档推荐在一个专用目录中构建 Glibc：
mkdir -v build
cd build
# 准备编译 Glibc：
#  --host=$LFS_TGT, --build=$(../scripts/config.guess)
#  在它们的共同作用下，Glibc 的构建系统将自身配置为使用 $LFS/tools 中的交叉链接器和交叉编译器，进行交叉编译。
#  –-build和-–host在不同的时候就被配置文件认定为交叉编译方式。
#  --host=$LFS_TGT 指定使用我们刚刚构建的交叉编译器，而不是 /usr/bin 中的宿主系统编译器。
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib
 
# 编译该软件包：
make
# 安装该软件包：
# DESTDIR=$LFS  多数软件包使用 DESTDIR 变量指定软件包应该安装的位置。如果不设定它，默认值为根 (/) 目录。
# 这里我们指定将软件包安装到 $LFS，它在第三遍编译 “进入 Chroot 环境”之后将成为根目录。
make DESTDIR=$LFS install
# 改正 ldd 脚本中硬编码的可执行文件加载器路径，使其符合前面在 LFS 文件系统中创建有限目录布局.
sed '/RTLDLIST=/s,/usr,,g' -i $LFS/usr/bin/ldd

# 检查gcc和glibc，确认新工具链的各基本功能 (编译和链接) 能如我们所预期的那样工作
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c -o a.out
readelf -l a.out | grep '/ld-linux' | grep '[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]'
rm -v dummy.c a.out
# 后续构建各软件包的过程可以作为对工具链是否正常构建的额外检查。如果 一些软件包，特别是第二遍编译时，Binutils 或者 
# GCC 不能构建，说明在之前第一遍编译时，安装 Binutils，GCC，或者 Glibc 时出了问题。 

# 运行 Glibc 的测试套件是很关键的。在任何情况下都不要跳过这个测试。
# 通常会有一些测试不能通过，但是一般你可以忽略任何下面列出来的失败项。现在开始测试编译结果：
#make check

#  现在我们的交叉工具链已经构建完成，可以完成 limits.h 头文件的安装。为此，运行 GCC 开发者提供的一个工具：
$LFS/tools/libexec/gcc/$LFS_TGT/11.1.0/install-tools/mkheaders

cd ../../
rm -rf ${glibc_xz:0:-7}


# 安装目标系统GCC-11.1.0 中的 Libstdc++ (Libstdc++ 是 GCC 源代码的一部分)，第一遍
# Libstdc++ 是 C++ 标准库。我们需要它才能编译 C++ 代码 (GCC 的一部分用 C++ 编写)。
# 但在构建第一遍的 GCC时我们不得不暂缓安装它，因为它依赖于当时还没有安装到目标目录的 Glibc。 
gcc_xz=$(ls gcc*.tar.xz)
tar -xf $gcc_xz
cd ${gcc_xz:0:-7}

# 为 Libstdc++ 创建一个单独的构建目录，并进入它：
mkdir -v build
cd build 

# 准备编译 Libstdc++：
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.1.0
# 编译 Libstdc++：
make
# 安装 Libstdc++：
make DESTDIR=$LFS install

cd ../../
rm -rf ${gcc_xz:0:-7}



# 交叉编译临时工具
# 使用刚刚第一遍编译时构建的交叉工具链对基本工具进行交叉编译。这些工具会被安装到它们的最终位置，但现在还无法使用。
# 基本操作仍然依赖宿主系统的工具。尽管如此，在链接时会使用刚刚第一遍编译时安装的库。
# 在第三遍编译时进入“chroot”环境后，就可以使用这些工具。但是在此之前，我们必须将本章中所有的软件包构建完毕。
# 因此现在我们还不能脱离宿主系统。 
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

install_tools_use_cc1 () {
  local pkg_name=$1
  local conf=$2
  local mk_conf=$3
  local mk_build=$4
  echo "安装 $pkg_name"
  echo "./configure --prefix=/usr   \
              --host=$LFS_TGT \
              $conf"
  read
  echo "make DESTDIR=$LFS install $mk_conf"
  read
  
  start_tool $pkg_name 
  echo "准备编译 $pkg_name"  
  if [ -z "$mk_build" ]; then
    bash -c "./configure --prefix=/usr   \
              --host=$LFS_TGT \
              $conf"
  else 
    mkdir -v build
    cd build
    bash -c "../configure --prefix=/usr   \
              --host=$LFS_TGT \
              $conf"
  fi
  echo "编译软件包 $pkg_name"
  make
  echo "安装该软件包 $pkg_name"
  bash -c "make DESTDIR=$LFS install $mk_conf"
  if [ ! -z "$5" ]; then
    echo "$5"
    read
    bash -c "$5"
  fi
  if [ ! -z "$mk_build" ]; then
    cd ..
  fi
  end_tool patch
}


# 安装 M4. M4 软件包包含一个宏处理器。
start_tool m4
# 准备编译 M4：
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool m4

# 安装 Ncurses. Ncurses 软件包包含使用时不需考虑终端特性的字符屏幕处理函数库。 
start_tool ncurses
# 保证在配置时优先查找 gawk 命令：
sed -i s/mawk// configure
# 在宿主系统构建“tic”程序：
mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd
# 准备编译 Ncurses：
#  --enable-widec
# 该选项使得宽字符库 (例如 libncursesw.so.6.2) 被构建，而不构建常规字符库 (例如 libncurses.so.6.2)。
# 宽字符库在多字节和传统 8 位 locale 中都能工作，而常规字符库只能在 8 位 locale 中工作。宽字符库和普通字符库
# 在源码层面是兼容的，但二进制不兼容。
./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-debug              \
            --without-ada                \
            --without-normal             \
            --enable-widec
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
# 我们很快将会构建一些需要 libncurses.so 库的软件包(库名称没有 “w” 的非宽字符替代品)。创建这个简短的链接脚本.
# 让常规非宽字符库 libncurses.so 指向宽字符库.
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
end_tool ncurses

# 安装 Bash. Bash 软件包包含 Bourne-Again SHell
start_tool bash
# 准备编译 Bash：
./configure --prefix=/usr                   \
            --build=$(support/config.guess) \
            --host=$LFS_TGT                 \
            --without-bash-malloc
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
# 为那些使用 sh 命令运行 shell 的程序考虑，创建一个链接：
ln -sv bash $LFS/bin/sh
end_tool bash

# 安装 Coreutils. Coreutils 软件包包含用于显示和设定系统基本属性的工具。 
start_tool coreutils
# 准备编译 Coreutils：

./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install  
# 将程序移动到它们最终安装时的正确位置。在临时环境中这看似不必要，但一些程序会硬编码它们的位置，
# 因此必须进行这步操作：
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
end_tool coreutils

# 安装 Diffutils. Diffutils 软件包包含显示文件或目录之间差异的程序。
start_tool diffutils
# 准备编译 Diffutils：
./configure --prefix=/usr --host=$LFS_TGT
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool diffutils

# 安装 File. File 软件包包含用于确定给定文件类型的工具。
start_tool file
# 宿主系统 file 命令的版本必须和正在构建的软件包相同，才能在构建过程中创建必要的签名数据文件。运行以下命令，为宿主系统构建它：
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make
popd
# 准备编译 File：
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
# 编译该软件包：
make FILE_COMPILE=$(pwd)/build/src/file
# 安装该软件包：
make DESTDIR=$LFS install
end_tool file

# 安装 Findutils. Findutils 软件包包含用于查找文件的程序。这些程序能够递归地搜索目录树，
# 以及创建、维护和搜索文件数据库 (一般比递归搜索快，但在数据库最近没有更新时不可靠)。 
start_tool findutils
# 准备编译 Findutils：
./configure --prefix=/usr   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool findutils

# 安装 Gawk. Gawk 软件包包含操作文本文件的程序。
start_tool gawk
# 首先，确保不要安装一些没有必要的文件：
sed -i 's/extras//' Makefile.in
# 准备编译 Gawk：
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./config.guess)
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool gawk

# 安装 Grep. Grep 软件包包含在文件内容中进行搜索的程序。
start_tool grep
# 准备编译 Grep：
./configure --prefix=/usr   \
            --host=$LFS_TGT
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool grep

# 安装 Gzip. Gzip 软件包包含压缩和解压缩文件的程序。 
start_tool gzip
# 准备编译 Gzip：
./configure --prefix=/usr --host=$LFS_TGT
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool gzip

# 安装 Make. Make 软件包包含一个程序，用于控制从软件包源代码生成可执行文件和其他非源代码文件的过程。 
start_tool make 
# 准备编译 Make：
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool gzip

# 安装 Patch. Patch 软件包包含通过应用 “补丁” 文件，修改或创建文件的程序，补丁文件通常是 diff 程序创建的。
start_tool patch 
# 准备编译 Patch：
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
end_tool patch

# 安装 Sed. Sed 软件包包含一个流编辑器。 
install_tools_use_cc1 'sed'

# 安装 Tar. Tar 软件包提供创建 tar 归档文件，以及对归档文件进行其他操作的功能。
install_tools_use_cc1 'tar' '--build=$(build-aux/config.guess)'

# 安装 Xz. Xz 软件包包含文件压缩和解压缩工具，它能够处理 lzma 和新的 xz 压缩文件格式。
# 使用 xz 压缩文本文件，可以得到比传统的 gzip 或 bzip2 更好的压缩比。
install_tools_use_cc1 'xz' '--build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.2.5'


##
# 第二遍编译: 在 pc 上使用 cc1 构建本地编译器 cc-lfs 
# 首先使用和其他程序相同的 DESTDIR 第二次构建 binutils，然后第二次构建 GCC，构建时忽略 libstdc++ 和其他不重要的库。
# 由于 GCC 配置脚本的一些奇怪逻辑，CC_FOR_TARGET 变量在 host 系统和 target 相同，但与 build 不同时，被设定为 cc。
# 因此我们必须显式地在配置选项中指定 CC_FOR_TARGET=$LFS_TGT-gcc。 
##

# 安装 Binutils (第二遍编译)
# 绕过导致 libctf.so 链接到宿主发行版 zlib 的问题
install_tools_use_cc1 'binutils' '--build=$(../config.guess) \
    --disable-nls              \
    --enable-shared            \
    --disable-werror           \
    --enable-64-bit-bfd' '-j1' 'build' 'install -vm755 libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib'

# 安装 GCC (第二遍编译)
start_tool gcc 
# 就像第一次构建 GCC 时一样，它需要 GMP、MPFR 和 MPC 三个包。解压它们的源码包，并将它们移动到 GCC 要求的目录名
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
# 如果是在 x86_64 上构建，修改 64 位库文件的默认目录名为 “lib”：
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
# 再次创建一个独立的构建目录：
mkdir -v build
cd build
# 创建一个符号链接，以允许 libgcc 在构建时启用 POSIX 线程支持：
mkdir -pv $LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h
# 准备编译 GCC：
# 构建时忽略 libstdc++ 和其他不重要的库。由于 GCC 配置脚本的一些奇怪逻辑，CC_FOR_TARGET 变量在 host 系统
# 和 target 相同，但与 build 不同时，被设定为 cc。因此我们必须显式地在配置选项中指定 CC_FOR_TARGET=$LFS_TGT-gcc
#
# --with-build-sysroot=$LFS
# 通常，使用 --host 即可保证使用交叉编译器cc1构建 GCC，这个交叉编译器知道它应该在 $LFS 中查找头文件和库。
# 但是，GCC 构建系统使用其他一些工具，它们不知道这个位置。因此需要该选项告诉它们在 $LFS 中查找需要的文件，而不是
# 在宿主系统中查找。
# --enable-initfini-array
# 该选项在使用 x86 本地编译器构建另一个本地编译器时自动启用。然而我们使用交叉编译器进行编译，因此必须显式启用它。
../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --prefix=/usr                                  \
    CC_FOR_TARGET=$LFS_TGT-gcc                     \
    --with-build-sysroot=$LFS                      \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
# 编译该软件包：
make
# 安装该软件包：
make DESTDIR=$LFS install
# 创建一个符号链接。许多程序和脚本运行 cc 而不是 gcc，因为前者能够保证程序的通用性，使它可以在所有 UNIX 系统上使用，
# 无论是否安装了 GNU C 编译器。运行 cc 可以将安装哪种 C 编译器的选择权留给系统管理员：
ln -sv gcc $LFS/usr/bin/cc
cd ..
end_tool gcc



## 
# 第三遍编译： 进入 Chroot 并构建其他临时工具
##
# 安装一些软件包的构建机制所必须的工具，然后安装三个用于运行测试的软件包。这样，就解决了所有的循环依赖问题，
# 我们可以使用“chroot”环境进行构建，它与宿主系统除正在运行的内核外完全隔离。
# 为了隔离环境的正常工作，必须它与正在运行的内核之间建立一些通信机制。我们通过所谓的虚拟内核文件系统达成这一目的，
# 它们必须在进入 chroot 环境时挂载。您可能希望用 findmnt 命令检查它们是否挂载好。 

# 后续的所有命令都应该在以 root 用户登录的情况下完成，而不是 lfs 用户。另外，请再次检查 $LFS 变量已经
# 在 root 用户的环境中设定好。 
exit #退出lfs用户
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
sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    /bin/bash --login +h
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

