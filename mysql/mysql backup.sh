#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/mysql/bin
BinLogDir=/usr/local/mysql/data
BinLogIndex=/usr/local/mysql/data/mysql-bin.index
BackupDir=/root/mysqlbackup

if [[ $1 != "Full" && $1 != "Incremental" ]];then
        echo "INVALID PARAMETER VALUE"
        exit 1
fi

if [ ! -f $BackupDir/LastPosition ];then
        touch $BackupDir/LastPosition
        basename $(tail -n 1 $BinLogIndex) > $BinLogDir/LastPosition
fi

IncrementalBinLog=$(find $BinLogDir  -name "mysql-bin.[0-9]*" -newer $BinLogDir/$(cat $BackupDir/LastPosition) -print)
basename $(tail -n 1 $BinLogIndex) > $BackupDir/LastPosition


if [ $1 == "Full" ];then
        echo "FullBcakup" >> $BackupDir/log
                echo "begin fullbackup"
                FullBackupName=$(date "+%y%m%d").sql
                mysqldump -uroot -p12345678 --single-transaction --flush-logs --all-databases > "$BackupDir/$FullBackupName"
                echo "end fullbackup"
elif [ $1 == "Incremental" ];then
        echo "IncrementalBcakup" >> $BackupDir/log
                echo "begin Incremental"
                mysqldump -uroot -p12345678 --flush-logs --all-databases
                echo "end Incremental"
fi

#复制增量日志到备份位置，该步骤需要在--flush-logs之后进行，避免--flush-logs之前仍然往日志文件写入，导致日志文件不完整
if [ ! -z "$IncrementalBinLog" ];then
        echo "backup binlog name is $IncrementalBinLog" >> $BackupDir/log
        cp $IncrementalBinLog $BackupDir
fi