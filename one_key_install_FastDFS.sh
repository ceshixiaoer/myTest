#!/bin/bash

echo -e "\033[32m ==============================start install FastDFS============================== \033[0m"

# 软件所在目录
software_path="/opt/download/"
# FastDFS 相关base path（以“/”结尾）
fastDFS_base_path="/opt/qiuxiao/"

# 判断是否支持git命令，不支持则安装
git --version || yum install -y git

# 判断/opt/download/目录是否存在，不存在则创建
if [ ! -d ${software_path} ] ;then
	mkdir -p ${software_path}
fi
# 判断/opt/qiuxiao/目录是否存在，不存在则创建
if [ ! -d ${fastDFS_base_path} ] ;then
	mkdir -p ${fastDFS_base_path}
fi

cd ${software_path}
# 下载软件包
#git clone https://gitee.com/crazyjim/FastDFS_dependency_software.git ${software_path}
wget https://github.com/happyfish100/libfastcommon/archive/V1.0.39.tar.gz
wget https://github.com/happyfish100/fastdfs/archive/V5.11.tar.gz

# 获取本机IP
local_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`

# 进入软件所在目录
cd ${software_path}

# 安装依赖
yum install -y gcc
yum install -y gcc-c++

# ----------------安装libfastcommon start----------------
# 解压libfastcommon-master.zip
unzip  V1.0.39.tar.gz

# 编译libfastcommon
cd libfastcommon-1.0.39
./make.sh || exit 1

# 安装
./make.sh install || exit 1

# 创建软链接
ln -s /usr/lib64/libfastcommon.so /usr/local/lib/libfastcommon.so
ln -s /usr/lib64/libfastcommon.so /usr/lib/libfastcommon.so
ln -s /usr/lib64/libfdfsclient.so /usr/local/lib/libfdfsclient.so
ln -s /usr/lib64/libfdfsclient.so /usr/lib/libfdfsclient.so
# ----------------安装libfastcommon end----------------

# ----------------安装FastDFS start----------------
# 解压FastDFS安装包
cd ..
tar -zxvf  V5.11.tar.gz

# 编译
cd fastdfs-5.11/
./make.sh || exit 1

#安装
./make.sh install || exit 1
# ----------------安装FastDFS end----------------

# ----------------配置Tracker服务 start----------------
cd /etc/fdfs/

# 拷贝文件
cp client.conf.sample client.conf
cp storage.conf.sample storage.conf
cp tracker.conf.sample tracker.conf
# http.conf和mime.types到/etc/fdfs下
cp ${software_path}"FastDFS/conf/http.conf" /etc/fdfs/
cp ${software_path}"/FastDFS/conf/mime.types" /etc/fdfs/

# 判断fastdfs_tracker目录是否存在，不存在则创建
if [ ! -d ${fastDFS_base_path}"fastdfs_tracker" ] ;then
	mkdir -p ${fastDFS_base_path}"fastdfs_tracker"
fi

# 修改tracker.conf配置
# 配置base_path=${fastDFS_base_path}fastdfs_tracker，端口参数不改变
sed -i "s|base_path=/home/yuqing/fastdfs|base_path=${fastDFS_base_path}fastdfs_tracker|g" tracker.conf

# ----------------配置Tracker服务 end----------------

# ----------------配置Storage服务 start----------------
# 判断fastdfs_storage_log目录是否存在，不存在则创建
if [ ! -d ${fastDFS_base_path}"fastdfs_storage_log" ] ;then
	mkdir -p ${fastDFS_base_path}"fastdfs_storage_log"
fi
# 判断fastdfs_storage_data目录是否存在，不存在则创建
if [ ! -d ${fastDFS_base_path}"fastdfs_storage_data" ] ;then
	mkdir -p ${fastDFS_base_path}"fastdfs_storage_data"
fi

# 修改storage.conf配置
# 配置base_path=${fastDFS_base_path}fastdfs_storage_log
sed -i "s|base_path=/home/yuqing/fastdfs|base_path=${fastDFS_base_path}fastdfs_storage_log|g" storage.conf

# 配置store_path0=${fastDFS_base_path}fastdfs_storage_data
sed -i "s|store_path0=/home/yuqing/fastdfs|store_path0=${fastDFS_base_path}fastdfs_storage_data|g" storage.conf

# 配置tracker_server属性
sed -i "s|tracker_server=192.168.209.121:22122|tracker_server=${local_ip}:22122|g" storage.conf

# ----------------配置Storage服务 end----------------

# ----------------修改client.conf start----------------
sed -i "s|base_path=/home/yuqing/fastdfs|base_path=${fastDFS_base_path}fastdfs_tracker|g" client.conf
sed -i "s|tracker_server=192.168.0.197:22122|tracker_server=${local_ip}:22122|g" client.conf
# ----------------修改client.conf end----------------

echo -e "\033[32m ==============================install Nginx Start============================== \033[0m"

# ----------------安装和配置nginx start----------------
# 安装依赖
yum install -y pcre pcre-devel
yum install -y zlib zlib-devel
yum install -y openssl openssl-devel

# 拷贝fastdfs-nginx-module模块包到/usr/local下
cp ${software_path}"fastdfs-nginx-module_v1.16.tar.gz" /usr/local/
# 解压nginx
cd ${software_path}
tar -zxvf nginx-1.8.0.tar.gz
# 解压fastdfs-nginx-module
cd /usr/local/
tar -zxvf fastdfs-nginx-module_v1.16.tar.gz
rm -f fastdfs-nginx-module_v1.16.tar.gz

# 编辑vim /usr/local/fastdfs-nginx-module/src/config
cd /usr/local/fastdfs-nginx-module/src/
sed -i "s|CORE_INCS=\"\$CORE_INCS /usr/local/include/fastdfs /usr/local/include/fastcommon/\"|CORE_INCS=\"\$CORE_INCS /usr/include/fastdfs /usr/include/fastcommon/\"|g" config

# nginx加入fastdfs-nginx-module模块
cd ${software_path}"nginx-1.8.0"
./configure --prefix=/usr/local/nginx --add-module=/usr/local/fastdfs-nginx-module/src/

# 编译安装nginx
make || exit 1
make install || exit 1

# 配置nginx.conf
cd /usr/local/nginx/conf/
sed -i "/^.*\#error_page.*$/i\        location \/group1\/M00 {" nginx.conf
sed -i "/^.*\#error_page.*$/i\            root ${fastDFS_base_path}fastdfs_storage_data\/data;" nginx.conf
sed -i "/^.*\#error_page.*$/i\            ngx_fastdfs_module;" nginx.conf
sed -i "/^.*\#error_page.*$/i\        }" nginx.conf

# 复制fastdfs-nginx-module模块的配置文件mod_fastdfs.conf到/etc/fdfs下
cp /usr/local/fastdfs-nginx-module/src/mod_fastdfs.conf /etc/fdfs/

# 判断fastdfs_storage_info目录是否存在，不存在则创建
if [ ! -d ${fastDFS_base_path}"fastdfs_storage_info" ] ;then
	mkdir -p ${fastDFS_base_path}"fastdfs_storage_info"
fi

# 编辑文件mod_fastdfs.conf
cd /etc/fdfs/
sed -i "s|base_path=/tmp|base_path=${fastDFS_base_path}fastdfs_storage_info|g" mod_fastdfs.conf
sed -i "s|tracker_server=tracker:22122|tracker_server=${local_ip}:22122|g" mod_fastdfs.conf
sed -i "s|url_have_group_name = false|url_have_group_name = true|g" mod_fastdfs.conf
sed -i "s|store_path0=/home/yuqing/fastdfs|store_path0=${fastDFS_base_path}fastdfs_storage_data|g" mod_fastdfs.conf
sed -i "s|group_count = 0|group_count = 1|g" mod_fastdfs.conf
sed -i "s|\#\[group1\]|\[group1\]|g" mod_fastdfs.conf
sed -i "s|\#group_name=group1|group_name=group1|g" mod_fastdfs.conf
# 只放开group1和group2之间的配置
sed -i "/\[group1\]/,/\#\[group2\]/s/\#storage_server_port=23000/storage_server_port=23000/" mod_fastdfs.conf
sed -i "/\[group1\]/,/\#\[group2\]/s/\#store_path_count=2/store_path_count=1/" mod_fastdfs.conf
# 因前面已经替换过store_path0=/home/yuqing/fastdfs，此处仅放开#即可
sed -i "/\[group1\]/,/\#\[group2\]/s/\#store_path0=/store_path0=/" mod_fastdfs.conf

# 建立软链接
ln -s ${fastDFS_base_path}"fastdfs_storage_data/data" ${fastDFS_base_path}"fastdfs_storage_data/data/M00"

# 放开80端口
/sbin/iptables -I INPUT -p tcp --dport 80 -j ACCEPT
/etc/rc.d/init.d/iptables save
/etc/init.d/iptables restart
# ----------------安装和配置nginx end----------------

# 启动tracker
/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf start
# 启动Storage服务
/usr/bin/fdfs_storaged /etc/fdfs/storage.conf restart
# 启动nginx
/usr/local/nginx/sbin/nginx

echo -e "\033[32m ==============================install FastDFS successfully============================== \033[0m"
