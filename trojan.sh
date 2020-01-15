#!/bin/bash

#copy from https://github.com/atrandys/trojan/blob/master/trojan_mult.sh

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

if ! cat /etc/issue | grep -Eqi "ubuntu"; then
red "==============="
red " 仅支持Ubuntu"
red "==============="
exit
fi

your_domain=$1
green "输入的VPS域名为: $your_domain"

trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16)

function install_trojan(){
Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
fi
if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
    red "============================================================="
    red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
    red "============================================================="
    exit 1
fi

if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
red "======================"
red "仅支持Ubuntu16以上版本"
red "======================"
exit
fi
if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
red "======================"
red "仅支持Ubuntu16以上版本"
red "======================"
exit
fi
systemctl stop ufw
systemctl disable ufw
apt update

# 校验域名
apt install -y curl
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [[ $real_addr != $local_addr ]] ; then
	red "=========================================="
	red "       域名解析错误"
	red "=========================================="
	sleep 1s
        exit
else
	green "=========================================="
	green "       域名解析正常，开始安装trojan"
	green "=========================================="
	sleep 1s
fi

## 安装依赖
apt install -y xz-utils wget apt-transport-https gnupg2 dnsutils lsb-release python-pil resolvconf ntpdate systemd dbus ca-certificates locales zip python3-qrcode
## 安装 Nginx
echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
apt update && apt install -y nginx openssl

cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF

## 安装 Trojan
bash -c "$(wget -O- https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
systemctl daemon-reload

#设置伪装站
rm -rf /usr/share/nginx/html/*
cd /usr/share/nginx/html/
wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip
unzip web.zip
systemctl enable nginx && systemctl start nginx

#申请https证书
cd ~
mkdir /usr/src/trojan-cert
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --upgrade --auto-upgrade
~/.acme.sh/acme.sh  --issue  -d $your_domain  --nginx
~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
--key-file   /usr/src/trojan-cert/private.key \
--fullchain-file /usr/src/trojan-cert/fullchain.cer

if [ ! -s /usr/src/trojan-cert/fullchain.cer ] ; then
red "================================"
red "https证书没有申请成果，本次安装失败"
red "================================"
exit
fi

# 重新配置Nginx
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  auto; #worker数量必须和CPU核心数量一样，选择auto可以自动设置
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
    use epoll; #使用异步架构，一个线程可以服务许多客户
    multi_accept on; #同时接受尽可能多的连接
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    aio threads; #使用异步i/o,避免因为i/o问题导致Nginx阻塞
    charset UTF-8; #使用UTF-8避免中文乱码问题
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    tcp_nopush     on; #将http headers一起发送，而非一个个分开发送
    tcp_nodelay on; #不要缓存数据，尽可能快速发送
    server_tokens off; #不发送Nginx版本号，提高安全性

    keepalive_timeout  60;
    client_max_body_size 20m;
    gzip  on;
    gzip_vary          on;
    gzip_comp_level    6;
    gzip_buffers       16 8k;
    gzip_min_length    1000;
    gzip_proxied       any;
    gzip_disable       "msie6";
    gzip_http_version  1.0;
    gzip_types         text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;
    
    server {
        add_header X-Content-Type-Options "nosniff" always; #禁止浏览器内容探测
        add_header X-XSS-Protection "1; mode=block" always; #启用XSS防跨站攻击保护
        add_header Referrer-Policy "no-referrer";
        listen       127.0.0.1:80 default_server;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
    server {
        listen       127.0.0.1:80;
        server_name  $local_addr;
        
        return 301 https://$your_domain$request_uri;
    }
    server {
        listen       0.0.0.0:80;
        listen [::]:80;
        server_name _;
 
        return 301 https://$your_domain$request_uri;
    }

}
EOF
nginx -s reload
systemctl restart nginx

# Trojan客户端配置文件
mkdir /usr/src/trojan-cli
cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-cli/fullchain.cer
cat > /usr/src/trojan-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "0.0.0.0",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": true,
        "fast_open": true,
        "fast_open_qlen": 20
    }
}
EOF
wget https://github.com/trojan-gfw/trojan-url/raw/master/trojan-url.py -q
chmod +x trojan-url.py
./trojan-url.py -q -i /usr/src/trojan-cli/config.json -o /usr/src/trojan-cli/trojan-qrcode.png

# Trojan 服务端配置
rm -rf /usr/local/etc/trojan/config.json
cat > /usr/local/etc/trojan/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "::",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 2,
    "ssl": {
        "cert": "/usr/src/trojan-cert/fullchain.cer",
        "key": "/usr/src/trojan-cert/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": true,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": true,
        "fast_open": true,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

# 打包客户端配置文件
cd /usr/src/trojan-cli/
zip -q -r trojan-cli.zip ./*
mkdir /usr/share/nginx/html/${trojan_path}
mv /usr/src/trojan-cli/trojan-cli.zip /usr/share/nginx/html/${trojan_path}/
cp /usr/src/trojan-cli/trojan-qrcode.png /usr/share/nginx/html/${trojan_path}/


# 启动 Trojan
systemctl start trojan && systemctl enable trojan	
}

timesync(){
  timedatectl set-timezone Asia/Hong_Kong
  timedatectl set-ntp on
  ntpdate -qu 1.hk.pool.ntp.org
}

tcp_fast_open(){
  echo "net.ipv4.tcp_fastopen = 3" | tee -a /etc/sysctl.conf
  echo "3" | tee /proc/sys/net/ipv4/tcp_fastopen
}


install_trojan
timesync
tcp_fast_open
green "======================================================================"
green "Trojan已安装完成, 并且已开启BBR PLUS, 网络参数已优化"
green "请使用以下链接下载trojan客户端配置文件"
blue "https://${your_domain}/$trojan_path/trojan-cli.zip"
green "下面是分享链接"
blue "trojan://${trojan_passwd}@${your_domain}:443"
green "下面是Trojan-GFW 二维码(QR code)链接"
blue "https://${your_domain}/$trojan_path/trojan-qrcode.png"
green "网络优化请执行: wget -N --no-check-certificate 'https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh' && chmod +x tcp.sh && ./tcp.sh"
green "======================================================================"
