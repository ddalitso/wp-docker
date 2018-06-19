#!/bin/bash
set -e

# From https://wordpress.org/themes/
themes=()
if [[ ! -z "${WORDPRESS_THEMES}" ]]; then
    IFS=',' read -r -a themes <<< "${WORDPRESS_THEMES}"
fi
themes+=(twentyseventeen)

# From https://wordpress.org/plugins/
plugins=()
if [[ ! -z "${WORDPRESS_PLUGINS}" ]]; then
    IFS=',' read -r -a plugins <<< "${WORDPRESS_PLUGINS}"
fi

echo ""
echo "Install themes.."
if [ ! -d "/var/www/wp/wp-content/themes/$i" ]; then
    mkdir -p /var/www/wp/wp-content/themes/
fi
for i in "${themes[@]}"; do
    if [ ! -d "/var/www/wp/wp-content/themes/$i" ]; then
        echo -n "> $i.. "
        wget -q "https://downloads.wordpress.org/theme/$i.zip" -O theme.zip
        unzip -q theme.zip -d /var/www/wp/wp-content/themes/
        rm theme.zip
        echo "OK"
    else
        echo "> $i.. (already installed)"
    fi
done
echo "Themes installed"
echo ""
echo "Install plugins.."
if [ ! -d "/var/www/wp/wp-content/plugins/$i" ]; then
    mkdir -p /var/www/wp/wp-content/plugins/
fi
for i in "${plugins[@]}"; do
    if [ ! -d "/var/www/wp/wp-content/plugins/$i" ]; then
        echo -n "> $i.. "
        wget -q "https://downloads.wordpress.org/plugin/$i.zip" -O plugin.zip
        unzip -q plugin.zip -d /var/www/wp/wp-content/plugins/
        rm plugin.zip
        echo "OK"
    else
        echo "> $i.. (already installed)"
    fi
done
echo "Plugins installed"
echo ""

chown -R www-data:www-data /var/www/wp/wp-content/

echo -n "Configuring wordpress.. "
DB_NAME=$(if [[ ! -z "${DB_NAME}" ]]; then echo "${DB_NAME}"; else echo "wordpress"; fi)
DB_USER=$(if [[ ! -z "${DB_USER}" ]]; then echo "${DB_USER}"; else echo "root"; fi)
DB_PASSWORD=$(if [[ ! -z "${DB_PASSWORD}" ]]; then echo "${DB_PASSWORD}"; else echo "root-password"; fi)
DB_HOST=$(if [[ ! -z "${DB_HOST}" ]]; then echo "${DB_HOST}"; else echo "db"; fi)
DB_TABLE_PREFIX=$(if [[ ! -z "${DB_TABLE_PREFIX}" ]]; then echo "${DB_TABLE_PREFIX}"; else echo "wp_"; fi)
WP_DEBUG=$(if [[ ! -z "${WP_DEBUG}" && "${WP_DEBUG}" = "true" ]]; then echo true; else echo false; fi)

cat <<EOF > /var/www/wp/wp-config.php
<?php

define('DB_NAME', "$DB_NAME");
define('DB_USER', "$DB_USER");
define('DB_PASSWORD', "$DB_PASSWORD");
define('DB_HOST', "$DB_HOST");
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$(wget -q https://api.wordpress.org/secret-key/1.1/salt/ -O -)

\$table_prefix  = "$DB_TABLE_PREFIX";

define('WP_DEBUG', $WP_DEBUG);

define('FORCE_SSL_ADMIN', true);
if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
        \$_SERVER['HTTPS']='on';

if ( !defined('ABSPATH') )
        define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOF

echo "OK"

echo -n "Configuring mail sender.. "
HOSTNAME=$(hostname)

set +e
grep new_mail_from /var/www/wp/wp-includes/functions.php > /dev/null;
if [ $? -ne 0 ]; then

cat <<EOF >> /var/www/wp/wp-includes/functions.php

function new_mail_from($old) {
    return "wordpress@$HOSTNAME";
}
add_filter('wp_mail_from', 'new_mail_from');

EOF
else
    sed -e "s/return \"wordpress@.*/return \"wordpress@$DOMAIN\";/g" var/www/wp/wp-includes/functions.php
fi
set -e

echo "OK"

/usr/sbin/php-fpm7

exec "$@"
