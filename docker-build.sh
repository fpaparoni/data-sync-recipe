#!/bin/bash
docker build -t fpaparoni/composer-tools:2.0.1 docker/composer/
docker push fpaparoni/composer-tools:2.0.1

docker build -t fpaparoni/postgres-redis-sync:1.0.2 docker/custom-components/postgres-redis-sync
docker push fpaparoni/postgres-redis-sync:1.0.2