FROM php:8.3.3-fpm-bullseye AS base

## Install Composer
COPY --from=composer:2.7.1 /usr/bin/composer /usr/bin/composer

## Install Debian packages
RUN apt update && apt install -y \
    libsqlite3-dev \
    nginx \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

## Install PHP extensions
# RUN pecl install ...

# RUN docker-php-ext-configure ...

RUN docker-php-ext-install \
    pdo_sqlite

# RUN docker-php-ext-enable ...

## Create non-root user
ARG APP_USER="app"
RUN addgroup --gid 3000 --system ${APP_USER}
RUN adduser --uid 3000 --system --disabled-login --disabled-password --gid 3000 ${APP_USER}

## Copy site
WORKDIR /var/www/html
COPY . .
RUN chown -R ${APP_USER}:${APP_USER} /var/www/html \
    && find /var/www/html -type d -exec chmod 0755 {} \; \
    && find /var/www/html -type f -exec chmod 0644 {} \;

## Configure FPM
RUN mv server/php-fpm.conf $PHP_INI_DIR-fpm.d/zz-docker.conf \
    && mkdir /run/php \
    && chown -R ${APP_USER}:${APP_USER} /run/php

# Configure Nginx
RUN mv server/nginx-site.conf /etc/nginx/sites-available/default \
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
    && mv server/docker-entrypoint.sh /docker-entrypoint.d/ \
    && chmod +x /docker-entrypoint.d/docker-entrypoint.sh 

EXPOSE 80

###### DEV ######
FROM base AS dev

ENV APP_ENV="dev"

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini" \
    && mv server/php-ini-dev.conf $PHP_INI_DIR/conf.d/docker-php-replace-development.ini

# Composer install
USER ${APP_USER}
RUN composer install --no-interaction --prefer-dist

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]

###### PROD ######
FROM base AS prod

ENV APP_ENV="prod"

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && mv server/php-ini-prod.conf $PHP_INI_DIR/conf.d/docker-php-replace-production.ini

# Composer install
USER ${APP_USER}
RUN composer install --no-cache --no-interaction --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]