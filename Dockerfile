#
# Dockerfile for reader
#

FROM node:14 as build-web

ARG REPO=https://github.com/hectorqin/reader.git

WORKDIR /app
RUN set -ex \
    && git clone --shallow-submodules --recurse-submodules $REPO . \
    && git checkout $(git tag | sort -V | tail -1)

WORKDIR /app/web
RUN set -ex \
    && npm install && npm run build \
    && mv ./dist ../src/main/resources/web

FROM ibm-semeru-runtimes:open-11-jdk as build-env

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NOWARNINGS=yes

ENV GRADLE_HOME /opt/gradle
RUN set -o errexit -o nounset \
    && echo "Adding gradle user and group" \
    && groupadd --system --gid 1000 gradle \
    && useradd --system --gid gradle --uid 1000 --shell /bin/bash --create-home gradle \
    && mkdir /home/gradle/.gradle \
    && chown --recursive gradle:gradle /home/gradle \
    \
    && echo "Symlinking root Gradle cache to gradle Gradle cache" \
    && ln --symbolic /home/gradle/.gradle /root/.gradle

WORKDIR /home/gradle
RUN set -o errexit -o nounset \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        unzip \
        wget \
        \
        bzr \
        git \
        git-lfs \
        mercurial \
        openssh-client \
        subversion \
    && rm --recursive --force /var/lib/apt/lists/* \
    \
    && echo "Testing VCSes" \
    && which bzr \
    && which git \
    && which git-lfs \
    && which hg \
    && which svn

ENV GRADLE_VERSION 6.9.3
ARG GRADLE_DOWNLOAD_SHA256=dcf350b8ae1aa192fc299aed6efc77b43825d4fedb224c94118ae7faf5fb035d
RUN set -o errexit -o nounset \
    && echo "Downloading Gradle" \
    && wget --no-verbose --output-document=gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    \
    && echo "Checking download hash" \
    && echo "${GRADLE_DOWNLOAD_SHA256} *gradle.zip" | sha256sum --check - \
    \
    && echo "Installing Gradle" \
    && unzip gradle.zip \
    && rm gradle.zip \
    && mv "gradle-${GRADLE_VERSION}" "${GRADLE_HOME}/" \
    && ln --symbolic "${GRADLE_HOME}/bin/gradle" /usr/bin/gradle \
    \
    && echo "Testing Gradle installation" \
    && gradle --version

COPY --from=build-web /app /app

WORKDIR /app
RUN set -ex \
    && rm src/main/java/com/htmake/reader/ReaderUIApplication.kt \
#   && gradle check --warning-mode all \
    && gradle -b cli.gradle assemble --info \
    && mv ./build/libs/*.jar ./build/libs/reader.jar

FROM ibm-semeru-runtimes:open-11-jre
COPY --from=build-env /app/build/libs/reader.jar /app/bin/reader.jar

RUN set -ex \
    && apt-get update && apt-get install -y \
       tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["java","-jar","/app/bin/reader.jar" ]
