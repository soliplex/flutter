# Build stage
FROM ubuntu:focal AS builder



RUN apt-get update && \
    apt-get install --no-install-recommends -y ca-certificates git curl wget unzip xz-utils && \
    rm -rf /var/lib/apt/lists/*



# download and install flutter
RUN export FLUTTER=flutter_linux_3.38.4-stable.tar.xz && \
    mkdir -p /opt &&  \
    cd /opt && \
    curl -L -o $FLUTTER https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$FLUTTER && \
    tar xf $FLUTTER && \
    rm $FLUTTER

# Copy Flutter project source code
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
COPY lib/ lib/
COPY web/ web/
COPY assets/ assets/
COPY packages/ packages/

# build flutter web for afsoc-rag
# --no-web-resources-cdn to support airgap
RUN export FLUTTER=/opt/flutter/bin/flutter && \
    git config --global --add safe.directory /opt/flutter && \
    $FLUTTER --disable-analytics && \
    $FLUTTER clean && \
    $FLUTTER pub get && \
    $FLUTTER build web --release --no-tree-shake-icons --no-web-resources-cdn \
      --dart-define=APP_NAME=soliplex

# Production stage with nginx

FROM nginx:alpine

# Install ping for network debugging and openssl for certificate generation
RUN apk add --no-cache iputils openssl

# Generate self-signed SSL certificate
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Copy built flutter web app to nginx html directory
COPY --from=builder /app/build/web /app/build/web

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

EXPOSE 9000 9443

CMD ["nginx", "-g", "daemon off;"]

