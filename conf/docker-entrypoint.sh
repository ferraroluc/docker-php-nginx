#!/bin/bash

php-fpm -F &
nginx -g 'daemon off;'