#!/bin/bash
echo deb http://nginx.org/packages/ubuntu/ trusty nginx >> /etc/apt/sources.list
echo deb-src http://nginx.org/packages/ubuntu/ trusty nginx >> /etc/apt/sources.list
wget http://nginx.org/keys/nginx_signing.key && apt-key add nginx_signing.key && apt-get update && apt-get install nginx
