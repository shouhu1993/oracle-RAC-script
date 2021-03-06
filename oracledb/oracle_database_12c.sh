#!/bin/bash

$DB_UNQNAME=orcl
$DB_SID==orcl
# Install packages
yum install -y bc binutils.x86_64 compat-libcap1.x86_64 compat-libstdc++-33.i686 compat-libstdc++-33.x86_64 glibc.i686 glibc.x86_64 glibc-devel.i686 glibc-devel.x86_64 ksh libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libxcb.i686 libxcb.x86_64 libX11.i686 libX11.x86_64 libXau.i686 libXau.x86_64 libXi.i686 libXi.x86_64 libXtst.i686 libXtst.x86_64 libXrender.i686 libXrender.x86_64 libXrender-devel.i686 libXrender-devel.x86_64 make.x86_64 net-tools.x86_64 nfs-utils.x86_64 smartmontools.x86_64 sysstat.x86_64 unixODBC-devel.i686 unixODBC-devel.x86_64 unixODBC.i686 unixODBC.x86_64 gcc-c++.x86_64


# configure /etc/fstab, add tmpfs /dev/shm tmpfs defaults,size=5G 0 0 size>= half of memory

# Create user and group
groupadd  oinstall
groupadd  dba
groupadd  oper
useradd  -g oinstall -G dba,oper oracle 

echo "oracle" | passwd oracle --stdin

# disable selinux
GET_SESTATUS=$(getenforce)
if [ $GET_SESTATUS == "Enforcing" -o $GET_SESTATUS == "Permissive" ];then
	setenforce 0
	sed -i -e "s/^SELINUX=enforcing/SELINUX=disabled/"
else
	echo $GET_SESTATUS
fi
	
echo "session required pam_limits.so" >> /etc/pam.d/login

# Create directories and grant permission
mkdir -p /u01/app/oracle/product/12.2.0/dbhome_1
chown -R oracle:oinstall /u01

# Disable transparent_hugepage
# get the option from /sys/kernel/mm/transparent_hugepage/enabled, the TSHG is the current option of the transparent_hugepage. the oracle's recommend option is never 
TSHG=$(awk '{for(i=1;i<=NF;i++){if($i ~ /\[([a-z]*)\]/){print $i;break;}}}' /sys/kernel/mm/transparent_hugepage/enabled)
echo $TSHG
if [ "$TSHG" != "[never]" ];then
	# generate a new profile for disable transparent_hugepage,CURRENT_TUNE_PROFILE is the current tune profile, NEW_TUNE_PROFILE is the new one
	CURRENT_TUNE_PROFILE=$(tuned-adm active | cut -d " " -f4)
	NEW_TUNE_PROFILE=$CURRENT_TUNE_PROFILE-oracle
	cp -R /usr/lib/tuned/$CURRENT_TUNE_PROFILE /usr/lib/tuned/$NEW_TUNE_PROFILE
	echo -e '[vm]\ntransparent_hugepages=never' >> /usr/lib/tuned/$NEW_TUNE_PROFILE/tuned.conf
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
" > /etc/security/limits.conf


# it should be moved to /etc/sysctl.d/
# https://man7.org/linux/man-pages/man5/proc.5.html

# shmall:
# This parameter sets the total amount of shared memory pages that can be used system wide. Hence, SHMALL should always be at least ceil(shmmax/PAGE_SIZE).
# If you are not sure what the default PAGE_SIZE is on your Linux system, you can run the following command:
# getconf PAGE_SIZE

# shmmax:
# This value can be used to query and set the run time limit on the maximum shared memory segment size that can be created.
# Shared memory segments up to 1Gb are now supported in the kernel.  This value defaults to SHMMAX.

# shmmni:
# This file specifies the system-wide maximum number of System V shared memory segments that can be created.

declare -i PAGE_SIZE_VALUE=$(getconf PAGE_SIZE)
declare -i KERNEL_SHMMAX=$(echo "$TOTAL_MEMORY*3/4"|bc)
# so KERNEL_SHMALL must greater than SGA ?
# declare -i KERNEL_SHMALL=$(echo "($TOTAL_MEMORY*2)/($PAGE_SIZE_VALUE*5)"|bc)
declare -i KERNEL_SHMALL=$(echo "$KERNEL_SHMMAX/$PAGE_SIZE_VALUE"|bc)

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
net.core.wmem_max = 1048576" > /etc/sysctl.conf

sysctl -p



# add environment value
# oracle environment
# get oracle/gird home directory path
ORACLE_HOME_PATH=$(grep oracle /etc/passwd | cut -d ":" -f 6)
echo \
"# Oracle Settings
export ORACLE_UNQNAME=$DB_UNQNAME
export ORACLE_SID=$DB_SID " >> $ORACLE_HOME_PATH/.bash_profile
echo \
'export TMP=/tmp
export TMPDIR=$TMP
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/12.2.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
umask 022' >> $ORACLE_HOME_PATH/.bash_profile