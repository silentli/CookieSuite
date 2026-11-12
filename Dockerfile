FROM dunglas/frankenphp:1.13.5-php8.3

WORKDIR /app

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN install-php-extensions @composer zip pdo_pgsql
COPY . .

RUN COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --no-dev --no-interaction --prefer-dist --optimize-autoloader
