#!/bin/sh

# mongodb base dir
MONGO_BASE_DIR=
# 解压安装包
tar xvf $1 --strip-components=1 --directory=$MONGO_BASE_DIR
# mongodb二进制执行文件路径，DEFAULT: /usr/bin/mongod
MONGO_BIN=
# mongodb数据文件目录，DEFAULT: /var/lib/mongo
DATA_DIR=
# mongodb日志文件目录，DEFAULT: /var/log/mongodb
LOG_DIR=
# mongodb PID文件目录，DEFAULT: /var/run/mongodb
PID_FILE_DIR=
# mongodb开放端口，DEFAULT: 27017
MONGO_PORT=
# mongodb配置文件
MONGO_CFG=

if [ -z $DATA_DIR ];then
        DATA_DIR=/var/lib/mongo
        if [ ! -d $DATA_DIR ];then
                mkdir -p $DATA_DIR
        fi
fi
if [ -z $LOG_DIR ];then
        LOG_DIR=/var/log/mongodb
        if [ ! -d $LOG_DIR ];then
                mkdir -p $LOG_DIR
        fi
fi
if [ -z $PID_FILE_DIR ];then
        PID_FILE_DIR=/var/run/mongodb
        if [ ! -d $PID_FILE_DIR ];then
                mkdir -p $PID_FILE_DIR
        fi
fi
if [ -z $MONGO_PORT ];then
        MONGO_PORT=27017
fi
if [ -z $MONGO_CFG ];then
        MONGO_CFG=/etc/mongod.conf
fi
if [ -z $MONGO_BIN ];then
        MONGO_BIN=/usr/bin/mongod
fi

# 安装所需依赖
yum install libcurl openssl xz-libs checkpolicy policycoreutils-python

# 增加mongo运行的用户组和用户
groupadd mongod
useradd -r -g mongod -s /bin/false mongod
# 配置数据文件和日志存放位置的权限
chown -R mongod:mongod $DATA_DIR $LOG_DIR $PID_FILE_DIR

# 配置SELinux策略
# Permit Access to cgroup
cat > mongodb_cgroup_memory.te <<EOF
module mongodb_cgroup_memory 1.0;

require {
    type cgroup_t;
    type mongod_t;
    class dir search;
    class file { getattr open read };
}

#============= mongod_t ==============
allow mongod_t cgroup_t:dir search;
allow mongod_t cgroup_t:file { getattr open read };
EOF

checkmodule -M -m -o mongodb_cgroup_memory.mod mongodb_cgroup_memory.te
semodule_package -o mongodb_cgroup_memory.pp -m mongodb_cgroup_memory.mod
sudo semodule -i mongodb_cgroup_memory.pp

# Permit Access to netstat for FTDC
cat > mongodb_proc_net.te <<EOF
module mongodb_proc_net 1.0;

require {
    type proc_net_t;
    type mongod_t;
    class file { open read };
}

#============= mongod_t ==============
allow mongod_t proc_net_t:file { open read };
EOF

checkmodule -M -m -o mongodb_proc_net.mod mongodb_proc_net.te
semodule_package -o mongodb_proc_net.pp -m mongodb_proc_net.mod
sudo semodule -i mongodb_proc_net.pp

# 修改自定义文件的selinux策略
# mongod_var_lib_t for data directory; mongod_log_t for log file directory; mongod_var_run_t for pid file directory
# Be sure to include the   .* at the end of the directory for the   semanage fcontext operations.
sudo semanage fcontext -a -t mongod_var_lib_t $DATA_DIR.*
sudo chcon -Rv -u system_u -t mongod_var_lib_t $DATA_DIR
restorecon -R -v $DATA_DIR

sudo semanage fcontext -a -t mongod_log_t $LOG_DIR.*
sudo chcon -Rv -u system_u -t mongod_log_t $LOG_DIR
restorecon -R -v $LOG_DIR

sudo semanage fcontext -a -t mongod_var_run_t $PID_FILE_DIR.*
sudo chcon -Rv -u system_u -t mongod_var_run_t $PID_FILE_DIR
restorecon -R -v $PID_FILE_DIR

sudo semanage port -a -t mongod_port_t -p tcp $MONGO_PORT


# systemd启动脚本
cat > /usr/lib/systemd/system/mongo.service <<EOF
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network-online.target
Wants=network-online.target

[Service]
User=mongod
Group=mongod
Environment="OPTIONS=-f $MONGO_CFG"
EnvironmentFile=-/etc/sysconfig/mongod
ExecStart=$MONGO_BIN \$OPTIONS
ExecStartPre=/usr/bin/mkdir -p $PID_FILE_DIR
ExecStartPre=/usr/bin/chown mongod:mongod $PID_FILE_DIR
ExecStartPre=/usr/bin/chmod 0755 $PID_FILE_DIR
PermissionsStartOnly=true
PIDFile=$PID_FILE_DIR/mongod.pid
Type=forking
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false
# Recommended limits for mongod as specified in
# https://docs.mongodb.com/manual/reference/ulimit/#recommended-ulimit-settings

[Install]
WantedBy=multi-user.target
EOF

