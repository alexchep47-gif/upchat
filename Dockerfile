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

# Match the Flutter toolchain used by the CI build.
RUN git clone --depth 1 --branch 3.24.5 https://github.com/flutter/flutter.git /flutter
COPY . .

RUN flutter config --no-analytics
RUN flutter pub get
RUN flutter build web --release --base-href "/app/"

FROM nginx:1.27-alpine
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
