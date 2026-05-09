#!/bin/bash

# 1. Build the Node.js Docker image
docker build -t my-node-app .

# 2. Create a shared Docker network
docker network create internal

# 3. Start Node.js app instances
docker run -d --name node-app-1 --network internal my-node-app
docker run -d --name node-app-2 --network internal my-node-app

# 4. Start Nginx
docker run -d --name nginx --network internal -p 80:80 nginx

# 5. Apply the Nginx config
docker cp ./nginx.conf nginx:/etc/nginx/conf.d/default.conf
docker restart nginx

# 6. Test the load balancer
curl http://localhost

# --- Useful commands ---

# Check running containers
docker ps

# View logs
docker logs node-app-1
docker logs node-app-2
docker logs nginx

# Shell into nginx container
docker exec -it nginx bash

# Reload nginx config without downtime
docker exec nginx nginx -s reload

# Stop and remove everything
docker stop nginx node-app-1 node-app-2
docker rm nginx node-app-1 node-app-2
docker network rm internal
