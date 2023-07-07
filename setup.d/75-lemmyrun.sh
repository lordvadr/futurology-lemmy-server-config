#!/usr/bin/env bash

. "$(dirname "$(realpath "${0}")")/library.sh" || { >&2 echo "FATAL: Could not instantiate function library."; exit 1; }

[ "$(whoami)" == "root" ] && { cp "${0}" "$(dirname "$(realpath "${0}")")/library.sh" ~lemmyrun/ && exec su - lemmyrun -c "./${0}"; }

mkdir -p ~/volumes/postgresql
mkdir -p ~/volumes/pictrs

chmod 777 ~/volumes/postgresql || true
chmod 777 ~/volumes/pictrs

# Pictrs
export PICTRS_OPENTELEMETRY_URL=http://otel:4137
export PICTRS__API_KEY=API_KEY
export RUST_LOG=debug
export RUST_BACKTRACE=full
export PICTRS__MEDIA__VIDEO_CODEC=vp9
export PICTRS__MEDIA__GIF__MAX_WIDTH=256
export PICTRS__MEDIA__GIF__MAX_HEIGHT=256
export PICTRS__MEDIA__GIF__MAX_AREA=65536
export PICTRS__MEDIA__GIF__MAX_FRAME_COUNT=400

# Postgres
export POSTGRES_USER=lemmy
export POSTGRES_PASSWORD=lemmy
export POSTGRES_DB=lemmy

# Lemmy
export LEMMY_CONFIG_LOCATION=/app/config/config.hjson
export LEMMY_DATABASE_URL=postgres://lemmy:lemmy@localhost:5432/lemmy

# Lemmy UI
# this needs to match the hostname defined in the lemmy service
export LEMMY_UI_LEMMY_INTERNAL_HOST=lemmy:8536
# set the outside hostname here
export LEMMY_UI_LEMMY_EXTERNAL_HOST=localhost:1236
export LEMMY_HTTPS=false
export LEMMY_UI_DEBUG=true

cat > nginx.conf << EOF
worker_processes 1;
events {
    worker_connections 1024;
}
http {
    upstream lemmy {
        # this needs to map to the lemmy (server) docker service hostname
        server "localhost:8536";
    }   
    upstream lemmy-ui {
        # this needs to map to the lemmy-ui docker service hostname
        server "localhost:1234";
    }   

    server {
        # this is the port inside docker, not the public one yet
        listen 8081;
        #listen 8536;
        # change if needed, this is facing the public web
        server_name futurology.social;
        server_tokens off;

        gzip on; 
        gzip_types text/css application/javascript image/svg+xml;
        gzip_vary on; 

        # Upload limit, relevant for pictrs
        client_max_body_size 20M;

        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        # frontend general requests
        location / { 
            # distinguish between ui requests and backend
            # don't change lemmy-ui or lemmy here, they refer to the upstream definitions on top
            set \$proxpass "http://lemmy-ui";

            if (\$http_accept = "application/activity+json") {
              set \$proxpass "http://lemmy";
            }
            if (\$http_accept = "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"") {
              set \$proxpass "http://lemmy";
            }
            if (\$request_method = POST) {
              set \$proxpass "http://lemmy";
            }
            proxy_pass \$proxpass;

            rewrite ^(.+)/+\$ \$1 permanent;
            # Send actual client IP upstream
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        # backend
        location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
            proxy_pass "http://lemmy";
            # proxy common stuff
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";

            # Send actual client IP upstream
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF

cat > lemmy-config.hjson << EOF 
{
  hostname: futurology.social
}
EOF

podman pod exists lemmy && podman pod rm lemmy --force
podman pod create -p 0.0.0.0:8080:8081 lemmy || { >&2 echo "Fatal, cannot create lemmy pod."; exit 1; }

podman run --pod lemmy -d -v ./nginx.conf:/etc/nginx/nginx.conf:ro,Z docker.io/lordvadr/nginx:1-alpine
       podman run --pod lemmy --rm -d -v ./volumes/postgresql:/var/lib/postgresql/data:Z \
                docker.io/library/postgres:15.3-alpine3.18 \
                postgres -c session_preload_libraries=auto_explain -c auto_explain.log_min_duration=5ms \
                -c auto_explain.log_analyze=true -c track_activity_query_size=1048576

podman run --pod lemmy -d --restart=always -v ./lemmy-config.hjson:/app/config/config.hjson:ro,Z docker.io/lordvadr/lemmy:0.18.0-rc.6

podman run --pod lemmy -d docker.io/lordvadr/lemmy-ui:0.18.1-rc.11

podman run --pod lemmy -d -v ./volumes/pictrs:/mnt:Z docker.io/lordvadr/pictrs:0.4.0-beta.19
