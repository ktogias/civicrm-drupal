#!/usr/bin/env bash

set -e

drush_required_vars=("DRUPAL_DB" "DRUPAL_DB_USER" "DRUPAL_DB_PASSWORD" "DRUPAL_ADMIN_USERNAME" "DRUPAL_ADMIN_PASSWORD" "DRUPAL_LOCALE" "DRUPAL_SITE_NAME")

# Define the required environment variables
cv_required_vars=("CMS_BASE_URL" "CIVICRM_DB" "CIVICRM_DB_USER" "CIVICRM_DB_PASSWORD" "CIVICRM_LANG")

function start_apache {
    apache2-foreground &
    APACHE_PID=$!
    wait $APACHE_PID
}

function clean_up {
    # Perform program exit housekeeping
    if [ -n "$APACHE_PID" ]; then
        kill "$APACHE_PID"
    fi
    exit
}

# Set trap for cleaning up on exit signals
trap clean_up SIGHUP SIGINT SIGTERM

skip_drush=false

for var in "${drush_required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Warning: $var is not set. Skipping Drush installation."
        skip_drush=true
    fi
done

if [ -f "/opt/drupal/web/sites/default/settings.php" ]; then
    echo "settings.php already exists. Skipping drush si..."
    skip_drush=true
fi

if [ "${skip_drush}" = false ]; then
    echo "Installing drush..."
    cd web
    composer --working-dir=/opt/drupal require drush/drush
    cd ..
    echo "
        \$databases['default']['default'] = array (
            'database' => '${DRUPAL_DB}',
            'username' => '${DRUPAL_DB_USER}',
            'password' => '${DRUPAL_DB_PASSWORD}',
            'prefix' => '',
            'host' => 'db',
            'port' => '3306',
            'isolation_level' => 'READ COMMITTED',
            'driver' => 'mysql',
            'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
            'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
        );
    " >> /opt/drupal/web/sites/default/default.settings.php
    echo "Running drush si..."
    drush si standard --db-url="mysqli://${DRUPAL_DB_USER}:${DRUPAL_DB_PASSWORD}@db/${DRUPAL_DB}" --account-name="${DRUPAL_ADMIN_USERNAME}" --account-pass="${DRUPAL_ADMIN_PASSWORD}" --locale="${DRUPAL_LOCALE}" --site-name="${DRUPAL_SITE_NAME}" -y
fi


skip_cv=false

# Check if environment variables are set
for var in "${cv_required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Warning: $var is not set. Skipping CiviCRM installation."
        skip_cv=true
    fi
done

if [ -f "/opt/drupal/web/sites/default/civicrm.settings.php" ]; then
    echo "civicrm.settings.php already exists. Skipping cv install..."
    skip_cv=true
fi

if [ "${skip_cv}" = false ]; then
    echo "Installing cv..."
    cd web
    composer config --working-dir=/opt/drupal --no-plugins extra.enable-patching true
    composer config --working-dir=/opt/drupal --no-plugins allow-plugins.cweagans/composer-patches true
    composer config --working-dir=/opt/drupal --no-plugins allow-plugins.civicrm/civicrm-asset-plugin true
    composer config --working-dir=/opt/drupal --no-plugins allow-plugins.civicrm/composer-downloads-plugin true
    composer config --working-dir=/opt/drupal --no-plugins allow-plugins.civicrm/composer-compile-plugin true
    composer config --working-dir=/opt/drupal extra.compile-mode all
    composer require --working-dir=/opt/drupal --ignore-platform-req=ext-intl -n civicrm/civicrm-core "^5" civicrm/civicrm-packages "^5" civicrm/civicrm-drupal-8 "^5" civicrm/cli-tools "^2023"
    cd ..
    yes | vendor/bin/cv core:install --cms-base-url="${CMS_BASE_URL}" --db="mysql://${CIVICRM_DB_USER}:${CIVICRM_DB_PASSWORD}@db:3306/${CIVICRM_DB}" --lang="${CIVICRM_LANG}"
    chown -R www-data:www-data web/sites/default/files/
fi

#Properly setup kcfinder
HTACCESS_FILE="web/.htaccess"
CIVICRM_SETTINGS_PATH="/opt/drupal/web/sites/default/civicrm.settings.php"
CIVICRM_SETTINGS_LINK="/opt/drupal/web/libraries/civicrm/civicrm.config.php"
if ! grep -q '"kcfinder/\*\*"' "/opt/drupal/composer.json"; then
    echo "Configuring composer extra.civicrm-asset ..."
    composer config --working-dir="/opt/drupal" --json extra.civicrm-asset '{"assets:packages":{"+include":["kcfinder/**"]}}'
    composer civicrm:publish
fi
if ! grep -q "RewriteCond %{REQUEST_URI} \!/libraries/civicrm/packages/kcfinder\.\*\\$" "$HTACCESS_FILE"; then
    echo "Adding kcfinder packages RewriteCond ..."
    sed -i '/RewriteRule .*autoload.* \[F\]/i \ \ RewriteCond %{REQUEST_URI} !/libraries/civicrm/packages/kcfinder.*\$' "$HTACCESS_FILE"
fi
if ! grep -q "RewriteCond %{REQUEST_URI} \!/libraries/civicrm/extern\.\*\\$" "$HTACCESS_FILE"; then
    echo "Adding extern RewriteCond ..."
    sed -i '/RewriteRule .*autoload.* \[F\]/i \ \ RewriteCond %{REQUEST_URI} !/libraries/civicrm/extern.*\$' "$HTACCESS_FILE"
fi
if [ ! -L "$CIVICRM_SETTINGS_LINK" ]; then
    ln -s "$CIVICRM_SETTINGS_PATH" "$CIVICRM_SETTINGS_LINK"
fi

# unset sensitive vars

unset DRUPAL_DB_USER DRUPAL_DB_PASSWORD DRUPAL_DB DRUPAL_ADMIN_USERNAME DRUPAL_ADMIN_PASSWORD CIVICRM_DB_USER CIVICRM_DB_PASSWORD CIVICRM_DB

# Start Apache in the background and wait for it
start_apache