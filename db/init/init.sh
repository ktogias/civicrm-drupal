#!/bin/bash

set -e

echo "** Creating drupal DB and users"

mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" --execute \
"
    CREATE USER '${DRUPAL_DB_USER}'@'%' IDENTIFIED BY '${DRUPAL_DB_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS ${DRUPAL_DB};
    GRANT ALL PRIVILEGES ON ${DRUPAL_DB}.* TO '${DRUPAL_DB_USER}'@'%';
"

echo "** Creating civicrm DB and users"

mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" --execute \
"
    CREATE USER '${CIVICRM_DB_USER}'@'%' IDENTIFIED BY '${CIVICRM_DB_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS ${CIVICRM_DB};
    GRANT ALL PRIVILEGES ON ${CIVICRM_DB}.* TO '${CIVICRM_DB_USER}'@'%';
"

echo "** Unsetting sensitive env vars"
unset DRUPAL_DB_USER DRUPAL_DB_PASSWORD DRUPAL_DB CIVICRM_DB_PASSWORD CIVICRM_DB_USER CIVICRM_DB_PASSWORD CIVICRM_DB


echo "** Finished creating DBs and users"
