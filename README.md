# Docker Container with Nginx and PHP-FPM

Laravel PHP application in a single container with PHP-FPM and Nginx using a non-root user.

## Software versions

-   Debian: Bullseye
-   PHP: 8.3.3
-   Composer: 2.7.1

## Prepare database

```bash
sqlite3 Hello.db
php artisan migrate
```

## Start service

```bash
php artisan serve
```

Test: http://localhost:8000/hello

## Docker

```bash
# Build DEV
docker build --target dev -t hello .
# Or build PROD
docker build --target prod -t hello .
# Run
docker run -p 3000:80 --name hello hello:latest
```

Test: http://localhost:3000/hello
