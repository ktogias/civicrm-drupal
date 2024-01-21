FROM drupal:10
#FROM drupal:9.3.22-php7.4

RUN apt update && apt install -y libicu-dev && apt clean

RUN docker-php-ext-configure intl && \
    docker-php-ext-install mysqli intl && \
    docker-php-ext-enable mysqli intl

RUN composer config --global use-parent-dir true

WORKDIR /opt/drupal
RUN composer require drush/drush

RUN mkdir -p web/sites/default/files/translations

RUN mkdir -p web/sites/default/files/civicrm/l10n/el_GR/LC_MESSAGES
RUN curl -Lss -o web/sites/default/files/civicrm/l10n/el_GR/LC_MESSAGES/civicrm.mo https://download.civicrm.org/civicrm-l10n-core/mo/el_GR/civicrm.mo

RUN chown -R www-data:www-data web/sites/default/files

RUN mkdir -p vendor/civicrm/cli-tools/extern
RUN curl -LsS https://download.civicrm.org/cv/cv.phar -o vendor/civicrm/cli-tools/extern/cv.phar

RUN export CIVICRM_L10N_BASEDIR=/opt/drupal/web/sites/default/files/civicrm/l10n

COPY target /

CMD ["/init.sh"]

RUN echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini;
RUN echo 'date.timezone = ${TZ}' >> /usr/local/etc/php/conf.d/docker-php-timezone.ini;