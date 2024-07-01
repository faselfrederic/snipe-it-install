#!/bin/bash

db_root_pass=password123
db_user_pass=password123

app_url=http://192.168.11.110
app_timezone=CET
db_database=snipeit
db_username=snipeit


# Check if script is executed as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root";
  exit
fi

# Updating repository information before installing
apt update -y

# Installing all dependencies
apt install -y \
nginx \
mariadb-server \
php-bcmath \
php-common \
php-ctype \
php-curl \
php-fileinfo \
php-fpm \
php-gd \
php-iconv \
php-intl \
php-mbstring \
php-mysql \
php-soap \
php-xml \
php-xsl \
php-zip \
git

# Install composer
apt install -y composer 


cat << EOF | mysql_secure_installation

y
y
$mysql_db_pass
$mysql_db_pass
y
y
y
y
EOF

mysql -e "CREATE DATABASE snipeit;"
mysql -e "GRANT ALL ON snipeit.* TO snipeit@localhost identified by '$db_user_pass';"
mysql -e "FLUSH PRIVILEGES;"

cd /var/www/html
git clone https://github.com/snipe/snipe-it
cd snipe-it
cp .env.example .env

sed -i "s\APP_URL=null\APP_URL=$app_url\g" .env
sed -i "s\APP_TIMEZONE='UTC'\APP_TIMEZONE='CET'\g" .env
sed -i "s\DB_DATABASE=null\DB_DATABASE=$db_database\g" .env
sed -i "s\DB_USERNAME=null\DB_USERNAME=$db_username\g" .env
sed -i "s\DB_PASSWORD=null\DB_PASSWORD=$db_user_pass\g" .env

chown -R www-data: /var/www/html/snipe-it
chmod -R 755 /var/www/html/snipe-it

# cat << EOF | composer update --no-plugins --no-scripts

# EOF

cat << EOF | composer install --no-dev --prefer-source --no-plugins --no-scripts

EOF

php artisan key:generate --force

php_sock=$(ls /var/run/php/php8*.sock)

cat << EOF > /etc/nginx/conf.d/snipeit.conf
server {
        listen 80;
        server_name snipeit.example.com;
        root /var/www/html/snipe-it/public;
        
        index index.php;
                
        location / {
                try_files $uri $uri/ /index.php?$query_string;

        }
        
        location ~ \.php$ {
include fastcgi.conf;
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:$php_sock;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        }

}
EOF

sed -i 's\try_files  / /index.php?;\try_files $uri $uri/ /index.php?$query_string;\g' /etc/nginx/conf.d/snipeit.conf
sed -i 's\fastcgi_param SCRIPT_FILENAME ;\fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\g' /etc/nginx/conf.d/snipeit.conf

sed -i 's\# server_names_hash_bucket_size 64;\server_names_hash_bucket_size 64;\g' /etc/nginx/nginx.conf

rm /etc/nginx/sites-enabled/default

systemctl restart nginx