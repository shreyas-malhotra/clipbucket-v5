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

DOMAIN_NAME="clipbucket.local"

# Apache configuration
VHOST_PATH="/etc/apache2/sites-available/001-clipbucket.conf"
a2enconf php${PHP_VERSION}-fpm 2>&1 > /dev/null
a2enmod rewrite proxy_fcgi 2>&1 > /dev/null
cat << 'EOF' > ${VHOST_PATH}
<VirtualHost *:80>
    ServerName DOMAINNAME
    DocumentRoot INSTALLPATH

    <Directory INSTALLPATH>
        Options Indexes FollowSymLinks
        AllowOverride all
        Order allow,deny
        allow from all
    </Directory>

    <FilesMatch .php$>
        SetHandler "proxy:unix:/run/php/phpPHPVERSION-fpm.sock|fcgi://localhost"
    </FilesMatch>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
a2ensite 001-clipbucket > /dev/null
cat << 'EOF' >> /etc/apache2/apache2.conf

<Directory SERVERROOT>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
</Directory>
EOF

sed -i "s/SERVERROOT/${SERVER_ROOT//\//\\/}/g" /etc/apache2/apache2.conf
systemctl restart apache2 > /dev/null


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
