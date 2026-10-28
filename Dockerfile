# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"
WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    libglu1-mesa \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Match the tested stable Flutter toolchain used by CI and local analysis.
ARG FLUTTER_VERSION=3.47.8
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /flutter
COPY . .

RUN flutter config --no-analytics
RUN flutter precache --web
# Render ne construit que la version Web : supprimer Android du contexte de
# build évite toute détection/initialisation Gradle dans l’environnement Render.
RUN rm -rf android && \
    flutter pub get && \
    flutter build web --release --base-href "/app/"

FROM nginx:1.27-alpine
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
