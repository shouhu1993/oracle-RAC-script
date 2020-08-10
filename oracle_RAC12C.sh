#!/bin/bash
NODE=1
# Install packages
yum install -y bc binutils.x86_64 compat-libcap1.x86_64 compat-libstdc++-33.i686 compat-libstdc++-33.x86_64 glibc.i686 glibc.x86_64 glibc-devel.i686 glibc-devel.x86_64 ksh libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libxcb.i686 libxcb.x86_64 libX11.i686 libX11.x86_64 libXau.i686 libXau.x86_64 libXi.i686 libXi.x86_64 libXtst.i686 libXtst.x86_64 libXrender.i686 libXrender.x86_64 libXrender-devel.i686 libXrender-devel.x86_64 make.x86_64 net-tools.x86_64 nfs-utils.x86_64 smartmontools.x86_64 sysstat.x86_64 unixODBC-devel.i686 unixODBC-devel.x86_64 unixODBC.i686 unixODBC.x86_64 gcc-c++.x86_64

# install shared storage package cvuqdisk-1.0.10-1.rpm, path cv/rpm

echo \
"#RAC12C Public
10.26.1.100  rac12c1
10.26.1.101  rac12c2

#RAC12C VIP
10.26.1.102  rac12c1-vip
10.26.1.103  rac12c2-vip

#RAC12C Private
10.26.1.104  rac12c1-priv
10.26.1.105  rac12c2-priv

#RAC12C Scan IP
10.26.1.106  rac-scan
">>/etc/hosts
hostnamectl set-hostname rac12c$NODE

# configure ntpd or chronyd

# configure /etc/fstab, add tmpfs /dev/shm tmpfs defaults,size=5G 0 0 size>= half of memory

# Create user and group
groupadd  oinstall
groupadd  dba
groupadd  oper
groupadd  backupdba
groupadd  dgdba
groupadd  kmdba
groupadd  asmdba
groupadd  asmoper
groupadd  asmadmin
groupadd  racdba
useradd  -g oinstall -G dba,oper,asmdba oracle 
useradd  -g oinstall -G dba,oper,backupdba,dgdba,kmdba,asmdba,asmoper,asmadmin,racdba grid

echo "oracle" | passwd oracle --stdin
echo "grid" | passwd grid --stdin


systemctl disable avahi-daemon.service NetworkManager.service firewalld.service
systemctl stop NetworkManager.service avahi-daemon.socket avahi-daemon.service firewalld.service

# disable selinux
GET_SESTATUS=$(getenforce)
if [ $GET_SESTATUS == "Enforcing" -o $GET_SESTATUS == "Permissive" ];then
	setenforce 0
	sed -i -e "s/^SELINUX=enforcing/SELINUX=disabled/"
else
	echo $GET_SESTATUS
fi
	
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
echo "session required pam_limits.so" >> /etc/pam.d/login

# Create directories and grant permission
mkdir -p /u01/app/12.2.0/grid
mkdir -p /u01/app/grid
chown -R grid:oinstall /u01
chmod -R 775 /u01
mkdir -p /u01/app/oracle/product/12.2.0/dbhome_1
chown -R oracle:oinstall /u01/app/oracle

# Disable transparent_hugepage
# get the option from /sys/kernel/mm/transparent_hugepage/enabled, the START_VLAUE is the byte offset of '[', the END_VLAUE is the byte offset of ']', the TSHG is the current option of the transparent_hugepage. the oracle's recommend option is never 
START_VLAUE=$(echo $(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -b -o "\[" |cut -d ":" -f 1)+2|bc)
END_VLAUE=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -b -o "\]"|cut -d ":" -f 1|bc)
TSHG=$(cat /sys/kernel/mm/transparent_hugepage/enabled |cut -c $START_VLAUE-$END_VLAUE)
echo $TSHG
if [ "$TSHG" != "never" ];then
	# generate a new profile for disable transparent_hugepage,CURRENT_TUNE_PROFILE is the current tune profile, NEW_TUNE_PROFILE is the new one
	CURRENT_TUNE_PROFILE=$(tuned-adm active | cut -d " " -f4)
	NEW_TUNE_PROFILE=$CURRENT_TUNE_PROFILE-oracle
	cp -R /usr/lib/tuned/$CURRENT_TUNE_PROFILE /usr/lib/tuned/$NEW_TUNE_PROFILE
	echo \
	'[vm]
	transparent_hugepages=never' \
	>> /usr/lib/tuned/$NEW_TUNE_PROFILE/tuned.conf
	tuned-adm profile $NEW_TUNE_PROFILE
	tuned-adm active
	cat /sys/kernel/mm/transparent_hugepage/enabled
else
	echo "transparent_hugepage is already disabled"
fi
# Edit hosts file



# it should be moved to /etc/security/limits.d/ ,check for ulimit
declare -i TOTAL_MEMORY=$(free -b | grep Mem | awk '{print $2}')
declare -i MEMLOCK_VALUE=$(echo "$TOTAL_MEMORY*9/10240+1"|bc)
echo \
"# at least 1024
oracle soft nofile 1024
# at least 65536
oracle hard nofile 65536
# at least 2047
oracle soft nproc 2047
# at least 16384
oracle hard nproc 16384
# at least 10240 KB
oracle soft stack 10240
# at least 10240 KB, and at most 32768 KB
oracle hard stack 32768
# at least 90 percent of the current RAM when HugePages memory is enabled and at least 3145728 KB (3 GB) when HugePages memory is disabled
oracle hard memlock $MEMLOCK_VALUE
# at least 90 percent of the current RAM when HugePages memory is enabled and at least 3145728 KB (3 GB) when HugePages memory is disabled
oracle soft memlock $MEMLOCK_VALUE
# at least 1024
grid soft nofile 1024
# at least 65536
grid hard nofile 65536
# at least 2047
grid soft nproc 2047
# at least 16384
grid hard nproc 16384
# at least 10240 KB
grid soft stack 10240
# at least 10240 KB, and at most 32768 KB
grid hard stack 32768
# at least 90 percent of the current RAM when HugePages memory is enabled and at least 3145728 KB (3 GB) when HugePages memory is disabled
grid hard memlock $MEMLOCK_VALUE
# at least 90 percent of the current RAM when HugePages memory is enabled and at least 3145728 KB (3 GB) when HugePages memory is disabled
grid soft memlock $MEMLOCK_VALUE" > /etc/security/limits.d/99-oracle_RAC12C.conf


# it should be moved to /etc/sysctl.d/
declare -i PAGE_SIZE_VALUE=$(getconf PAGE_SIZE)
declare -i KERNEL_SHMMAX=$(echo "$TOTAL_MEMORY/2"|bc)
declare -i KERNEL_SHMALL=$(echo "($TOTAL_MEMORY*2)/($PAGE_SIZE_VALUE*5)"|bc)
echo \
"# Note: This value limits concurrent outstanding requests and should be set to avoid I/O subsystem failures.
fs.aio-max-nr = 1048576
fs.file-max = 6815744
# 40 percent of the size of physical memory in pages
# Note: If the server supports multiple databases, or uses a large SGA, then set this parameter to a value that is equal to the total amount of shared memory, in 4K pages, that the system can use at one time.
kernel.shmall = $KERNEL_SHMALL
# Half the size of physical memory in bytes 
kernel.shmmax = $KERNEL_SHMMAX
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576" > /etc/sysctl.d/99-oracle_RAC12C.conf

sysctl --system



# add environment value
# oracle environment
# get oracle/gird home directory path
ORACLE_HOME_PATH=$(grep oracle /etc/passwd | cut -d ":" -f 6)
GRID_HOME_PATH=$(grep grid /etc/passwd | cut -d ":" -f 6)
echo \
"# Oracle Settings
export ORACLE_UNQNAME=racdb
export ORACLE_SID=rac12c$NODE
export ORACLE_HOSTNAME=rac12c$NODE " >> $ORACLE_HOME_PATH/.bash_profile
echo \
'export TMP=/tmp
export TMPDIR=$TMP
#export ORACLE_UNQNAME=racdb
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/12.2.0/dbhome_1
#export ORACLE_SID=rac12c1
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
#export ORACLE_HOSTNAME=rac12c1
umask 022' >> $ORACLE_HOME_PATH/.bash_profile
# grid environment
echo \
"#Grid Settings
export ORACLE_HOSTNAME=rac12c$NODE
export ORACLE_SID=+ASM$NODE" >> $GRID_HOME_PATH/.bash_profile
echo \
'export TMP=/tmp
export TMPDIR=$TMP
#export ORACLE_HOSTNAME=rac12c1
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/12.2.0/grid
#export ORACLE_SID=+ASM
export PATH=/usr/sbin:$PATH
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
umask 022' >> $GRID_HOME_PATH/.bash_profile
