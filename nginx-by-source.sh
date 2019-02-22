#!/bin/bash
VERSION="1.12.0"
DOWNLOAD_PATH="/usr/local/src"

# Install dependence
apt-get update
apt-get upgrade
apt-get install -y build-essential libtool openssl git unzip 

# Install pcre lib
cd $DOWNLOAD_PATH && wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.gz && tar -zxf pcre-8.40.tar.gz && cd pcre-8.40 
./configure && make && make install

# Install zlib
cd $DOWNLOAD_PATH && wget http://zlib.net/zlib-1.2.11.tar.gz && tar -zxf zlib-1.2.11.tar.gz && cd zlib-1.2.11 
./configure && make && make install

# Download and extract nginx
cd $DOWNLOAD_PATH && wget "http://nginx.org/download/nginx-$VERSION.tar.gz"&& tar -zxf "nginx-$VERSION.tar.gz"

# Delete downloads
rm -- *.tar.gz

cd "nginx-$VERSION"

#wget -O nginx-ct.zip -c https://github.com/grahamedgecombe/nginx-ct/archive/v1.2.0.zip
#unzip nginx-ct.zip

./configure \
--with-pcre=../pcre-8.40 \
--with-zlib=../zlib-1.2.11 \
--with-debug \
--with-pcre-jit \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-threads \
--with-stream \
--with-stream_ssl_module \
--with-http_slice_module \
--with-mail \
--with-mail_ssl_module \
--with-file-aio \
--with-http_v2_module 
#--sbin-path=/usr/sbin/nginx \
#--conf-path=/etc/nginx/nginx.conf \
#--add-module=./nginx-ct-1.2.0
make && make install
#touch /etc/profile.d/nginx.sh
#echo PATH=$PATH:/usr/local/nginx/sbin >> /etc/profile.d/nginx.sh
#echo export PATH >> /etc/profile.d/nginx.sh
#source /etc/profile.d/nginx.sh
