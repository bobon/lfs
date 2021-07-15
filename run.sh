#!/bin/bash

set -e

# https://bf.mengyan1223.wang/lfs/zh_CN/development/LFS-BOOK.html

# env
LFS_DISK=/dev/sdb1
# 

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

