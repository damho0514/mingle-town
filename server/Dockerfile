# Build from the repo root so the shared protocol package is in context:
#   docker build -f server/Dockerfile -t mingle-town-server .
FROM dart:stable AS build
WORKDIR /src
COPY packages/mingle_protocol/pubspec.yaml packages/mingle_protocol/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN cd server && dart pub get
COPY packages/mingle_protocol packages/mingle_protocol
COPY server server
RUN cd server && dart pub get --offline && dart compile exe bin/server.dart -o /out/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
