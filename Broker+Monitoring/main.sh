#!/bin/bash

docker-compose up -d
sleep 10  

xdg-open http://localhost:3000/d/RABBITMQ/rabbitmq-overview || open http://localhost:3000
