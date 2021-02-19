mongodb二进制文件安装脚本
使用方式./mongo.sh mongodb二进制文件压缩包

参数说明
MONGO_BASE_DIR为mongo的基础目录，包含bin、data、log、config等目录
MONGO_BIN为二进制执行文件路径，基础目录下的相对路径
DATA_DIR为数据文件目录，基础目录下的相对路径
LOG_DIR为日志文件目录，基础目录下的相对路径
PID_FILE_DIR为PID文件目录，基础目录下的相对路径
MONGO_PORT为配置的非标准端口，即不是27017
MONGO_CFG=为配置文件路径，基础目录下的相对路径
