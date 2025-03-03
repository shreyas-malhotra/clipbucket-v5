#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Build script must be run as root"
    exit
fi

clear

OS="UBUNTU2404"
PHP_VERSION="8.3"

# Updating the system
apt update > /dev/null 2>&1
apt dist-upgrade -y > /dev/null 2>&1

# Installing Nginx
HTTP_SERVER="NGINX"
apt install nginx-full --yes > /dev/null 2>&1

# Installing PHP and other dependencies
apt install php${PHP_VERSION}-fpm mariadb-server git php${PHP_VERSION}-curl ffmpeg php${PHP_VERSION}-mysqli php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-gd sendmail mediainfo --yes > /dev/null 2>&1

# PHP-FPM configuration
sed -i "s/max_execution_time = 30/max_execution_time = 7200/g" /etc/php/${PHP_VERSION}/fpm/php.ini
systemctl restart php${PHP_VERSION}-fpm

# Installing ClipBucket
SERVER_ROOT="/srv/http/"
INSTALL_PATH="${SERVER_ROOT}clipbucket/"
mkdir -p ${INSTALL_PATH}
git clone https://github.com/shreyas-malhotra/clipbucket-v5.git ${INSTALL_PATH} > /dev/null 2>&1
git config --global core.fileMode false
git config --global --add safe.directory ${INSTALL_PATH}

# Updating access permissions
chown www-data: -R ${INSTALL_PATH}
chmod 755 -R ${INSTALL_PATH}

# Hardcoding DOMAIN_NAME to be used for the ClipBucket Installation
DOMAIN_NAME="clipbucket.local"

# Configuring Nginx Vhost
VHOST_PATH="/etc/nginx/sites-available/001-clipbucket"
rm -f /etc/nginx/sites-enabled/default
cat << 'EOF' > ${VHOST_PATH}
server {
    listen 80;
    server_name DOMAINNAME;

    root INSTALLPATH;
    index index.php;

    client_max_body_size 2M;

    proxy_connect_timeout 7200s;
    proxy_send_timeout 7200s;
    proxy_read_timeout 7200s;
    fastcgi_send_timeout 7200s;
    fastcgi_read_timeout 7200s;

    fastcgi_buffers 16 32k;
    fastcgi_buffer_size 64k;
    fastcgi_busy_buffers_size 64k;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;

    # set expiration of assets to MAX for caching
    location ~* \.(ico|css|js)(\?[0-9]+)?$ {
        expires max;
        log_not_found off;
    }

    location ~* \.php$ {
        fastcgi_pass unix:/var/run/php/phpPHPVERSION-fpm.sock;
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location / {
        if ($query_string ~ "mosConfig_[a-zA-Z_]{1,21}(=|\%3D)"){
            rewrite ^/([^.]*)/?$ /index.php last;
        }
        rewrite ^/(.*)_v([0-9]+) /watch_video.php?v=$2&$query_string last;
        rewrite ^/([a-zA-Z0-9-]+)/?$ /view_channel.php?uid=$1&seo_diret=yes last;
    }

    error_page 404 /404;
    error_page 403 /403;
    location /403 {
        try_files $uri /403.php;
    }
    location /404 {
        try_files $uri /404.php;
    }

    location /includes/ {
        return 302 /404;
    }

    location /changelog/ {
        return 302 /404;
    }

    location /video/ {
        rewrite ^/video/(.*)/(.*) /watch_video.php?v=$1&$query_string last;
        rewrite ^/video/([0-9]+)_(.*) /watch_video.php?v=$1&$query_string last;
    }

    location /videos/ {
        rewrite ^/videos/(.*)/(.*)/(.*)/(.*)/(.*) /videos.php?cat=$1&sort=$3&time=$4&page=$5&seo_cat_name=$2 last;
        rewrite ^/videos/([0-9]+) /videos.php?page=$1 last;
        rewrite ^/videos/?$ /videos.php?$query_string last;
    }

    location /channels/ {
        rewrite ^/channels/(.*)/(.*)/(.*)/(.*)/(.*) /channels.php?cat=$1&sort=$3&time=$4&page=$5&seo_cat_name=$2 last;
        rewrite ^/channels/([0-9]+) /channels.php?page=$1 last;
        rewrite ^/channels/?$ /channels.php last;
    }

    location /members/ {
        rewrite ^/members/?$ /channels.php last;
    }

    location /users/ {
        rewrite ^/users/?$ /channels.php last;
    }

    location /user/ {
        rewrite ^/user/(.*) /view_channel.php?user=$1 last;
    }

    location /channel/ {
        rewrite ^/channel/(.*) /view_channel.php?user=$1 last;
    }

    location /my_account {
        rewrite ^/my_account /myaccount.php last;
    }

    location /page/ {
        rewrite ^/page/([0-9]+)/(.*) /view_page.php?pid=$1 last;
    }

    location /search/ {
        rewrite ^/search/result/?$ /search_result.php last;
    }

    location /upload {
        rewrite ^/upload/?$ /upload.php last;
    }

    location /contact/ {
        rewrite ^/contact/?$ /contact.php last;
    }

    location /categories/ {
        rewrite ^/categories/?$ /categories.php last;
    }

    location /collections/ {
        rewrite ^/collections/(.*)/(.*)/(.*)/(.*)/(.*) /collections.php?cat=$1&sort=$3&time=$4&page=$5&seo_cat_name=$2 last;
        rewrite ^/collections/([0-9]+) /collections.php?page=$1 last;
        rewrite ^/collections/?$ /collections.php last;
    }

    location /photos/ {
        rewrite ^/photos/(.*)/(.*)/(.*)/(.*)/(.*) /photos.php?cat=$1&sort=$3&time=$4&page=$5&seo_cat_name=$2 last;
        rewrite ^/photos/([0-9]+) /photos.php?page=$1 last;
        rewrite ^/photos/?$ /photos.php last;
    }

    location /collection/ {
        rewrite ^/collection/(.*)/(.*)/(.*) /view_collection.php?cid=$1&type=$2&page=$3 last;
    }

    location /item/ {
        rewrite ^/item/(.*)/(.*)/(.*)/(.*) /view_item.php?item=$3&type=$1&collection=$2 last;
    }

    location /photo_upload {
        rewrite ^/photo_upload/(.*) /photo_upload.php?collection=$1 last;
        rewrite ^/photo_upload/?$ /photo_upload.php last;
    }

    location = /sitemap.xml {
        rewrite ^(.*)$ /sitemap.php last;
    }

    location /signup {
        rewrite ^/signup/?$ /signup.php last;
    }

    location /rss/ {
        rewrite ^/rss/([a-zA-Z0-9].+)$ /rss.php?mode=$1&$query_string last;
    }

    location /list/ {
        rewrite ^/list/([0-9]+)/(.*)?$ /view_playlist.php?list_id=$1 last;
    }

    location ~ /rss$ {
        try_files $uri /rss.php;
    }
}
EOF

ln -s ${VHOST_PATH} /etc/nginx/sites-enabled/;

sed -i "s/DOMAINNAME/${DOMAIN_NAME}/g" ${VHOST_PATH}
sed -i "s/PHPVERSION/${PHP_VERSION}/g" ${VHOST_PATH}
sed -i "s/INSTALLPATH/${INSTALL_PATH//\//\\/}upload/g" ${VHOST_PATH}

systemctl restart nginx > /dev/null

# Database configuration
mysql -uroot -e "CREATE DATABASE clipbucket;"
DB_PASS="clipbucket"
mysql -uroot -e "CREATE USER 'clipbucket'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON clipbucket.* TO 'clipbucket'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -uroot -e "FLUSH PRIVILEGES;"

# Printing credentials and DB information required for web configuration
echo "- Database address : localhost"
echo "- Database name : clipbucket"
echo "- Database user : clipbucket"
echo "- Database password : ${DB_PASS}"
echo "- Install directory : ${INSTALL_PATH}"
echo "- Website URL : http://${DOMAIN_NAME}"
