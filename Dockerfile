###### BASE ######
FROM php:7.4-fpm-bullseye AS base

# Install Debian packages
RUN apt update && apt install -y \
    ... \
    nginx

# Install Wkhtmltopdf
RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb -P ~\ 
    && dpkg -i ~/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && apt -f install

# Install Composer
COPY --from=composer:2.2.23 /usr/bin/composer /usr/bin/composer

# Install PHP extensions
RUN pecl install \
    ...

RUN docker-php-ext-configure \
    ... --enable-... --with-...

RUN docker-php-ext-install \
    ...

RUN docker-php-ext-enable \
    ...

# Create non-root user
ARG APP_USER="app"
RUN addgroup --gid 3000 --system ${APP_USER}
RUN adduser --uid 3000 --system --disabled-login --disabled-password --gid 3000 ${APP_USER}

# Copy site
WORKDIR /var/www/project
COPY . .
RUN chown -R ${APP_USER}:${APP_USER} /var/www/project \
    && find /var/www/project -type d -exec chmod 0755 {} \; \
    && find /var/www/project -type f -exec chmod 0644 {} \;

# Configure FPM
RUN mv conf/php-fpm.conf $PHP_INI_DIR-fpm.d/zz-docker.conf \
    && mkdir /run/php \
    && chown -R ${APP_USER}:${APP_USER} /run/php

# Configure Nginx
RUN mv conf/nginx-site-dev.conf /etc/nginx/sites-available/default \
    && mkdir -p /var/cache/nginx \
    && touch /run/nginx.pid \
    && chown -R ${APP_USER}:${APP_USER} \
        /var/cache/nginx \
        /var/log/nginx \
        /var/lib/nginx \
        /run/nginx.pid \
        /etc/nginx

## Configure entrypoint
RUN mkdir /docker-entrypoint.d \
    && mv conf/docker-entrypoint.sh /docker-entrypoint.d/ \
    && chmod +x /docker-entrypoint.d/docker-entrypoint.sh 

# Make database migration
RUN php migration...

EXPOSE 80

###### DEV ######
FROM base AS dev

# Variables
ENV APP_ENV="dev"

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini" \
    && mv conf/php-ini-dev.conf $PHP_INI_DIR/conf.d/docker-php-replace-development.ini

# Configure debug
RUN echo "xdebug...." >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Composer install
USER ${APP_USER}
RUN composer install --no-interaction --prefer-dist

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]

###### PROD ######
FROM base AS prod

# Variables
ENV APP_ENV=prod

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && mv conf/php-ini-prod.conf $PHP_INI_DIR/conf.d/docker-php-replace-production.ini

# Composer install
USER ${APP_USER}
RUN composer install --no-cache --no-interaction --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]