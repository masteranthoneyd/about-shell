#!/bin/bash
# jdk onekey installation
echo "#----------------------
# Welcome to jdk onekey installation
# Create by Yangbingdong =.=
# Version 1.0
#----------------------"
sleep 1
cd /usr/local/
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u111-b14/jdk-8u111-linux-x64.tar.gz
tar -zxvf jdk-8u111-linux-x64.tar.gz
ln -s jdk1.8.0_111 jdk
touch /etc/profile.d/jdk.sh
echo 'export JAVA_HOME=/usr/local/jdk' >> /etc/profile.d/jdk.sh
echo 'PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/jdk.sh
source /etc/profile.d/jdk.sh
echo "################### jdk install completely"
sleep 1
echo "java verion:"
java -version
