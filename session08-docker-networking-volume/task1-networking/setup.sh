#!/bin/bash
# Session 08 - Task 1: 3 containers, 3 networks, backend attached to 2 networks.
set -e
docker network create s08-frontend-net   # frontend <-> backend
docker network create s08-backend-net    # backend  <-> database
docker network create s08-db-net         # database-only private network

docker run -d --name s08-database --network s08-backend-net \
  -e MYSQL_ROOT_PASSWORD=rootpass -e MYSQL_DATABASE=appdb mysql:8.4
docker network connect s08-db-net s08-database

docker run -d --name s08-backend --network s08-frontend-net nginx:alpine
docker network connect s08-backend-net s08-backend          # backend is now on 2 networks

docker run -d --name s08-frontend --network s08-frontend-net nginx:alpine

# connectivity tests
docker exec s08-frontend ping -c 2 s08-backend               # works  (shared frontend-net)
docker exec s08-backend  nc -zv -w 3 s08-database 3306       # works  (shared backend-net)
docker exec s08-frontend nc -zv -w 3 s08-database 3306 || true  # fails (no shared network)
