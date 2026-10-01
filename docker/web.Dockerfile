# Image autonome Flutter Web. Pas de dépendance à une image tierce non maintenue.
FROM ubuntu:24.04 AS flutter-base
ARG FLUTTER_VERSION=3.47.5
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    PUB_CACHE=/root/.pub-cache
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fSL --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o /tmp/flutter.tar.xz \
    && mkdir -p /opt \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter \
    && flutter config --enable-web \
    && flutter precache --web
WORKDIR /workspace
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib ./lib
COPY assets ./assets
COPY web ./web

FROM flutter-base AS development
EXPOSE 8080
# Web debug : le navigateur du PC voit le backend via localhost:3000.
CMD ["sh", "-c", "flutter pub get && flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000"]

FROM flutter-base AS web-build
ARG API_BASE_URL=/api
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:stable-alpine AS production
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-build /workspace/build/web /usr/share/nginx/html
EXPOSE 80
