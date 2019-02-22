#!/bin/bash
echo "#----------------------------------
# Welcome to Onekey Ngrok installation
# Create by Yangbingdong! =.=
# Operating System:Ubuntu
# Version:1.0
#----------------------------------"
sleep 1
read -p "Pleace enter your domain: " domain
NGROK_DOMAIN=${domain}
apt-get update
apt-get -y install build-essential mercurial git
wget https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.8.1.linux-amd64.tar.gz
touch /etc/profile.d/go.sh
mkdir $HOME/go
echo 'export GOROOT=/usr/local/go' >> /etc/profile.d/go.sh
echo 'export GOPATH=$HOME/go' >> /etc/profile.d/go.sh
echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> /etc/profile.d/go.sh
source /etc/profile.d/go.sh
cd /usr/local/src/
git clone https://github.com/tutumcloud/ngrok.git ngrok
export GOPATH=/usr/local/src/ngrok/
cd ngrok
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$NGROK_DOMAIN" -days 5000 -out rootCA.pem
openssl genrsa -out device.key 2048
openssl req -new -key device.key -subj "/CN=$NGROK_DOMAIN" -out device.csr
openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000
cp rootCA.pem assets/client/tls/ngrokroot.crt
cp device.crt assets/server/tls/snakeoil.crt 
cp device.key assets/server/tls/snakeoil.key
GOOS=linux GOARCH=386
make release-server release-client
echo "Install ngrok successful"
