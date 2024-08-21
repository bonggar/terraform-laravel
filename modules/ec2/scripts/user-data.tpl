#!/usr/bin/env bash

INFRA_ENV="${infra_env}"
INFRA_ROLE="${infra_role}"

# >&2 echo "[$INFRA_ENV:$INFRA_ROLE] Setting up alphabet.io application"
# sudo -u alphabet bash -c "cd /home/alphabet && rm -rf alphabet.io && git clone ${git_url} alphabet.io"

# TODO: Get the application .env appropriate for this environment
#       From an S3 bucket or perhaps SSM Parameter Store
# >&2 echo "[$INFRA_ENV:$INFRA_ROLE] Installing application dependencies"
# sudo -u alphabet bash -c "cd /home/alphabet/alphabet.io && cp .env.example .env && composer install && php artisan key:generate"


if [[ "$INFRA_ROLE" == "core" ]]; then
    >&2 echo "[$INFRA_ENV:$INFRA_ROLE] Reloading PHP-FPM"

    # Reload php-fpm to clear Opcache
    systemctl reload php8.0-fpm
fi


if [[ "$INFRA_ROLE" == "admin" ]]; then
    >&2 echo "[$INFRA_ENV:$INFRA_ROLE] Preparing queue workers"

    # Turn off Nginx/PHP-FPM
    systemctl stop nginx
    systemctl stop php8.0-fpm
    systemctl disable nginx
    systemctl disable php8.0-fpm

    # Enable and Start supervisord
    systemctl enable supervisor
    systemctl start supervisor
fi