# Build from repo root: docker build -f apps/countdown_server/Dockerfile .
FROM dart:stable AS build

WORKDIR /app

# Copy monorepo path dependencies first, then server package.
COPY packages/countdown_core packages/countdown_core
COPY apps/countdown_server apps/countdown_server

WORKDIR /app/apps/countdown_server
RUN dart pub get
RUN mkdir -p /app/bin && dart compile exe bin/server.dart -o /app/bin/server

# Build minimal serving image from AOT-compiled `/server`
# and the pre-built AOT-runtime in the `/runtime/` directory of the base image.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

EXPOSE 8080
CMD ["/app/bin/server"]
