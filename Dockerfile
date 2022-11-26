#
# Dockerfile for reader
#

FROM alpine as source

ARG URL=https://api.github.com/repos/hectorqin/reader/releases/latest

WORKDIR /root

RUN set -ex \
    && apk add --update --no-cache curl \
    && wget -O reader.jar $(curl -s $URL | grep browser_download_url | egrep -o "https.+\.jar")

FROM ibm-semeru-runtimes:open-17-jre
COPY --from=source /root/reader.jar /app/bin/reader.jar

RUN set -ex \
    && apt-get update && apt-get install -y \
       tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["java","-jar","/app/bin/reader.jar" ]
