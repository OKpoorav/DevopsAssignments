#!/bin/bash
docker rm -f s08-frontend s08-backend s08-database
docker network rm s08-frontend-net s08-backend-net s08-db-net
