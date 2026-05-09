# Load Balancer — Node.js + Nginx + Docker

A system design project demonstrating how to set up a **weighted load balancer** using Nginx as a reverse proxy in front of multiple Node.js application instances running in Docker containers.

---

## Architecture

```
Client (Browser / curl)
        |
        v
  [ Nginx :80 ]          ← reverse proxy & load balancer
        |
   (weighted round-robin)
   /            \
node-app-1:3000  node-app-2:3000
  (weight=3)       (weight=1)
```

- **Nginx** listens on host port `80` and distributes traffic across Node.js instances.
- **node-app-1** receives 3 out of every 4 requests (weight=3).
- **node-app-2** receives 1 out of every 4 requests (weight=1).

---

## Project Structure

```
load-balancer/
├── app.js          # Express server
├── dockerfile      # Docker image for the Node.js app
├── nginx.conf      # Nginx load balancer configuration
├── package.json
└── .gitignore
```

---

## Node.js App

Built with **Express 5** (`app.js`). Responds to `GET /` with system info:

```json
{
  "message": "Hello World",
  "hostname": "<container-hostname>",
  "platform": "linux",
  "arch": "x64",
  "version": "...",
  "uptime": 123,
  "ip": "client-ip"
}
```

The `hostname` field changes per container, making it easy to verify which instance handled a request.

---

## Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

- Based on `node:20-alpine` for a minimal image size.
- App runs on port `3000` inside the container.

---

## Nginx Configuration

`nginx.conf` is placed in `/etc/nginx/conf.d/default.conf` inside the Nginx container.

```nginx
upstream node_apps {
    server node-app-1:3000 weight=3;
    server node-app-2:3000 weight=1;
}

server {
    listen 80;

    location / {
        proxy_pass http://node_apps;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

- Uses **weighted round-robin** load balancing.
- Forwards `Host`, `Upgrade`, and `Connection` headers for WebSocket compatibility.

---

## Setup & Running

### 1. Build the Node.js Docker image

```bash
docker build -t my-node-app .
```

### 2. Create a shared Docker network

```bash
docker network create internal
```

### 3. Start Node.js app instances

```bash
docker run -d --name node-app-1 --network internal my-node-app
docker run -d --name node-app-2 --network internal my-node-app
```

> Do **not** expose ports on the app containers — only Nginx needs to be public.

### 4. Start Nginx

```bash
docker run -d --name nginx --network internal -p 80:80 nginx
```

### 5. Apply the Nginx config

```bash
docker cp ./nginx.conf nginx:/etc/nginx/conf.d/default.conf
docker restart nginx
```

### 6. Test it

```bash
curl http://localhost
```

Hit it multiple times and watch the `hostname` field rotate between `node-app-1` and `node-app-2` according to the weights.

---

## Key Lessons / Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `localhost:3000` not reachable | Host port was mapped to `6000`, not `3000` | Use the mapped host port shown in `docker ps` |
| Browser shows "This site can't be reached" on port 6000 | Port 6000 is blocked by all major browsers (reserved for X11) | Use a non-blocked port like `8080` |
| Nginx container exits immediately after restart | Config syntax error (`proxy-cache-bypass` instead of `proxy_cache_bypass`) | Nginx directives use underscores, not hyphens |
| Nginx can't resolve `node-app-1` | Containers not on the same Docker network | Put all containers on the same named network |

---

## Adding More Instances

To scale out, add more containers and update `nginx.conf`:

```bash
docker run -d --name node-app-3 --network internal my-node-app
```

```nginx
upstream node_apps {
    server node-app-1:3000 weight=3;
    server node-app-2:3000 weight=1;
    server node-app-3:3000 weight=2;
}
```

Then re-apply the config:

```bash
docker cp ./nginx.conf nginx:/etc/nginx/conf.d/default.conf
docker exec nginx nginx -s reload
```
