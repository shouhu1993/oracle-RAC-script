#!/bin/bash
#参考链接https://dev.mysql.com/doc/refman/5.6/en/innodb-table-import.html
#存放需要导入数据文件的目录
DB_DIR=
#需要创建的数据库名称
DB_NAME=
DB_CHARACTER_SET=
#MySQL的datadir路径
MYSQL_DATA_DIR=
#MySQL的root密码
MYSQL_PASSWORD=

#删除存在的sql文件
if [ -f create_table_ddl.sql ];then
	rm -rf create_table_ddl.sql
fi
if [ -f discard_table.sql ];then
    rm -rf discard_table.sql
fi
if [ -f import_table.sql ];then
    rm -rf import_table.sql
fi
if [ -z DB_CHARACTER_SET ];then
	DB_CHARACTER_SET=utf8
fi

#创建必要的数据库
echo "CREATE DATABASE $DB_NAME CHARACTER SET $DB_CHARACTER_SET;" > create_table_ddl.sql
#提取创建表的DDL语句
mysqlfrm --diagnostic $DB_DIR >> create_table_ddl.sql
#根据数据目录，获取库下面的所有表名称，生成导入数据文件的sql语句（先DISCARD后IMPORT）
TB_NAME=$(find $DB_DIR -name "*.frm" -exec /usr/bin/basename -s .frm {} \;)
for TABLE in $TB_NAME
do
	echo "ALTER TABLE $DB_NAME.$TABLE DISCARD TABLESPACE;" >> discard_table.sql
	echo "ALTER TABLE $DB_NAME.$TABLE IMPORT TABLESPACE;" >> import_table.sql
done
mysql -uroot -p$MYSQL_PASSWORD < create_table_ddl.sql
mysql -uroot -p$MYSQL_PASSWORD < discard_table.sql
cp $DB_DIR/*.ibd $MYSQL_DATA_DIR/$DB_NAME
chown mysql:mysql $MYSQL_DATA_DIR/$DB_NAME/*.ibd
mysql -uroot -p$MYSQL_PASSWORD < import_table.sql
