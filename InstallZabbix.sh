#!/bin/bash
#Name InstallZabbix
#Create by li
#Use environment = centos 7.5
#
#
echo "========================================================================="
echo "=========                   1.定义变量及相关配置及位置               ======"
echo "========================================================================="
#通用
SELINUX_PATH=/etc/selinux/config
HOST_NAME='/etc/sysconfig/network'
#定义下载文件放置位置，可创建软件存放文件夹并进入
#mkdir -p /data/tools
TOOLS_PATH=/root
cd $TOOLS_PATH
#网络相关配置文件及位置
#获取本机IP地址
#IPADDR1=/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:" 
#IPADDR1=ip a show dev ens33|grep -w inet|awk '{print $2}'|awk -F '/' '{print $1}'
ETHCONF=/etc/sysconfig/network-scripts/ifcfg-ens33
HOSTS=/etc/hosts
HOSTNAME=`hostname`
DIR=/root/backup/`date +%Y%m%d`
NETMASK=255.255.255.0
DNS_PATH='/etc/resolv.conf'
sed -i 's/ONBOOT\=no/ONBOOT\=yes/g' ${ETHCONF}
systemctl restart network
IPADDR1=`ip a show dev ens33|grep -w inet|awk '{print $2}'|sed 's/\/.*//'`
#zabbix-server相关配置文件
ZABBIX_SERVER_PATH='/etc/zabbix/zabbix_server.conf'
ZABBIX_HTTPD_PATH='/etc/httpd/conf.d/zabbix.conf'
#数据库相关配置及位置
user1='root'
user2='zabbix'
password='123456'
echo "========================================================================="
echo "=========                   2.修改主机名与网络配置                   ======"
echo "========================================================================="
echo "........自动获取的ip是$IPADDR1 ..........."
read -p "Please insert ip address:" IPADDR
#
#修改主机名(简单粗暴)
#hostnamectl set-hostname Zabbix-Server
#或
function Change_hosts(){
if
   [ ! -d $DIR ];then
   mkdir -p $DIR
fi
  cp $HOSTS $DIR 
#  read -p "Please insert ip address": IPADDR 
# host=`echo $IPADDR|sed 's/\./-/g'`
  read -p "当前主机名为${HOSTNAME},是否修改(y/n):" yn
if [ "$yn" == "Y" ] || [ "$yn" == "y" ]; then
  read -p "请输入主机名：" hdp
  sed -i "2c HOSTNAME=${hdp}" ${HOST_NAME}
  hostnamectl set-hostname ${hdp}
  echo "$IPADDR $hdp">>$HOSTS
  cat $HOSTS |grep 127.0.0.1 |grep "$hdp"
else
  echo "....主机名未修改 .........." 
#fi
fi
}
Change_hosts
#
function Change_ip(){
#判断备份目录是否存在，中括号前后都有空格，！叹号在shell表示相反的意思# 
if
   [ ! -d $DIR ];then
   mkdir -p $DIR
fi
  echo "准备开始改变IP，在此之前备份原来配置"
  cp $ETHCONF $DIR
  grep "dhcp"  $ETHCONF
#如下$?用来判断上一次操作的状态，为0，表示上一次操作状态正确或者成功#   
if
  [ $? -eq 0 ];then
#read -p 交互输入变量IPADDR，注冒号后有空格，sed -i 修改配置文件#
#  read IPADDR
  sed -i 's/dhcp/static/g' $ETHCONF
#awk -F. 意思是以.号为分隔域，打印前三列#   
#.2 是我的网关的最后一个数字，例如192.168.0.2#
  echo -e "IPADDR=$IPADDR\nNETMASK=$NETMASK\nGATEWAY=`echo $IPADDR|awk -F. '{print $1"."$2"."$3}'`.2" >>$ETHCONF
  echo "This IP address Change success !"
else
  echo -n  "这个$ETHCONF已存在 ,请确保更改吗？(y/n)":
  read i
fi
if   
  [ "$i" == "y" -o "$i" == "yes" ];then
#  read -p "Please insert ip Address:" IPADDR
#awk -F. 意思是以.号为分隔域
count=(`echo $IPADDR|awk -F. '{print $1,$2,$3,$4}'`)
 #定义数组， ${#count[@]}代表获取变量值总个数#
A=${#count[@]}
 #while条件语句判断，个数是否正确，不正确循环提示输入，也可以用[0-9]来判断ip#
while
  [ "$A" -ne "4" ]
do
#  read -p "Please re Inster ip Address,example 192.168.0.11 ip": IPADDR
count=(`echo $IPADDR|awk -F. '{print $1,$2,$3,$4}'`)
A=${#count[@]}
done
 #sed -e 可以连续修改多个参数#
  sed -i -e 's/^IPADDR/#IPADDR/g' -e 's/^NETMASK/#NETMASK/g' -e 's/^GATEWAY/#GATEWAY/g' $ETHCONF
 #echo -e \n为连续追加内容，并自动换行#
  echo -e "IPADDR=$IPADDR\nNETMASK=$NETMASK\nGATEWAY=`echo $IPADDR|awk -F. '{print $1"."$2"."$3}'`.2" >>$ETHCONF
  echo "This IP address Change success !"
else
  echo "This $ETHCONF static exist,please exit"
#  exit $?
fi
}
Change_ip
systemctl restart network
NEW_IP=`ip a show dev ens33|grep -w inet|awk '{print $2}'|sed 's/\/.*//'`
DNS_IP=`echo $NEW_IP|awk -F. '{print $1"."$2"."$3}'`.2
cat >> $DNS_PATH << EOF
nameserver $DNS_IP
EOF
systemctl restart network
#
echo "========================================================================="
echo "=========                   3.关闭selinux和防火墙                   ======"
echo "========================================================================="
#关闭selinux
#临时关闭
setenforce 0
#永久关闭（重启后生效）
sed -i 's/SELINUX\=enforcing/SELINUX\=disabled/g' $SELINUX_PATH
#关闭防火墙
##临时关闭firewall
systemctl stop firewalld.service
#禁止firewall开机启动 
systemctl disable firewalld.service
# 
echo "========================================================================="
echo "=========                   4.安装相关组件                          ======"
echo "========================================================================="
echo "ETHCONF=$ETHCONF"
echo "HOSTS=$HOSTS"
echo "HOSTNAME=$HOSTNAME"
echo "获取本机IP地址=$NEW_IP"
#安装控件
yum update -y
yum install -y vim wget net-tools tree
echo "========================================================================="
echo "=========                   5.搭建LAMP环境                          ======"
echo "========================================================================="
#搭建LAMP环境
#安装所需软件仓库
yum install -y httpd mariadb-server mariadb php php-mysql php-gd libjpeg* php-ldap php-odbc php-pear php-xml php-xmlrpc php-mhash
rpm -qa httpd php mariadb
#编辑httpd
cat >> /etc/httpd/conf/httpd.conf << EOF
#修改为主机名
ServerName www.zabbixforli.com
#添加首页支持格式
DirectoryIndex index.html index.php
EOF
#
#
#
#修改时区
echo 'date.timezone = PRC' >> /etc/php.ini 
systemctl start httpd   #启动并加入开机自启动httpd
systemctl enable httpd
systemctl start mariadb  #启动并加入开机自启动mysqld
systemctl enable mariadb
ss -anplt | grep httpd   #查看httpd启动情况，80端口监控表示httpd已启动
ss -naplt | grep mysqld  #查看mysqld启动情况，3306端口监控表示mysqld已启动　
echo "========================================================================="
echo "=========                   6.初始化数据库                          ======"
echo "========================================================================="
#初始化数据库
#设置数据库root密码
#设置zabbix用户
#使用root账户登录数据库；
#有空用户名称占用导致本地无法登录远程可登录并删除空用户
mysqladmin -u "$user1" password "$password"
echo "CREATE DATABASE zabbix character set utf8 collate utf8_bin;" | mysql -u"$user1" -p"$password"
echo "GRANT all ON zabbix.* TO 'zabbix'@'%' IDENTIFIED BY '$password';" | mysql -u"$user1" -p"$password"
echo "drop user ''@localhost;" | mysql -u"$user1" -p"$password"
echo "drop user ''@$HOSTNAME;" | mysql -u"$user1" -p"$password"
echo "flush privileges;" | mysql -u"$user1" -p"$password"
#
echo "========================================================================="
echo "=========                   7.安装Zabbix-server及其相关             ======"
echo "========================================================================="
#
#安装Zabbix
#安装依赖包
yum -y install net-snmp net-snmp-devel curl curl-devel libxml2 libxml2-devel libevent-devel.x86_64 javacc.noarch  javacc-javadoc.noarch javacc-maven-plugin.noarch javacc* OpenIPMI iksemel-devel iksemel
#安装php支持zabbix组件
yum install php-bcmath php-mbstring php-devel php-common -y
#
#安装zabbix软件包
rpm -ivh http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm
#启用zabbix前端可选 rpms 的软件仓库
yum-config-manager --enable rhel-7-server-optional-rpms
#安装 Zabbix server/proxy/web（适用于 RHEL7，在 RHEL 6 上弃用）并使用 MySQL 数据库：
wget -c -t 0 http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-server-mysql-4.0.12-1.el7.x86_64.rpm
wget -c -t 0 http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-proxy-mysql-4.0.12-1.el7.x86_64.rpm
wget -c -t 0 http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-web-4.0.12-1.el7.noarch.rpm
wget -c -t 0 http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-web-mysql-4.0.12-1.el7.noarch.rpm
yum localinstall -y zabbix-server-mysql*
yum localinstall -y zabbix-proxy-mysql*
yum localinstall -y zabbix-web-4*
yum localinstall -y zabbix-web-mysql*
#或
#yum install zabbix-server-mysql -y
#yum install zabbix-proxy-mysql -y
#yum install zabbix-web zabbix-web-mysql -y
#
#
#注意：如果 Zabbix server 和 Zabbix proxy 安装在相同的主机，它们必须创建不同名字的数据库！ 
#使用 MySQL 来导入 Zabbix server 的初始数据库 schema 和数据
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -u"$user2" -p"$password" zabbix
#对于 Zabbix proxy，导入初始的数据库 schema：
#zcat /usr/share/doc/zabbix-proxy-mysql*/schema.sql.gz | mysql -uzabbix -p[password] zabbix
#为 Zabbix server/proxy 配置数据库
cat >> $ZABBIX_SERVER_PATH << EOF
DBHost=localhost
DBPassword=$password
EOF
#
#
#
#修改时区
sed -i 's/\# php_value date.timezone Europe\/Riga/php_value date.timezone Asia\/Shanghai/g' $ZABBIX_HTTPD_PATH
#设置开机启动并启动
systemctl enable zabbix-server
systemctl start zabbix-server
#
#
#
echo "========================================================================="
echo "=========                   8.安装Zabbix-agent                      ======"
echo "========================================================================="
#安装Zabbix-agent
wget -c -t 0 http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-agent-4.0.12-1.el7.x86_64.rpm
yum localinstall -y zabbix-agent*
#rpm -ivh zabbix-agent*
#或
#yum install -y zabbix-agent
#设置开机启动并启动
systemctl start zabbix-agent
systemctl enable zabbix-agent
systemctl restart httpd
systemctl restart mariadb
systemctl restart zabbix-server
#
echo "========================================================================="
echo "=========        30秒后，登陆http://$NEW_IP/zabbix完成安装           ======"
echo "=========        第一步：next step                                  ======"
echo "=========        第二步：next step                                  ======"
echo "=========        第三步：Database type  --  MySQL                   ======"
echo "=========              ：Database host  --  localhost(或127.0.0.1)  ======"
echo "=========              ：Database port  --  3306                    ======"
echo "=========              ：Database name  --  $user2                  ======"
echo "=========              ：User           --  $user2                  ======"
echo "=========              ：Passwors       --  123456                  ======"
echo "=========              ：Host           --  localhost(或127.0.0.1)  ======"
echo "=========              ：Port           --  10051                   ======"
echo "=========              ：Name           --  (可填项，任意值)         ======"
echo "=========                               Next step                   ======"
echo "=========        第四步：next step                                  ======"
echo "=========        第五步：Finsh                                      ======"
echo "=========        Username： Admin                                   ======"
echo "=========        Password： zabbix                                  ======"
echo "=========================================================================="
#重启
shutdown -t 30 -r
#reboot
