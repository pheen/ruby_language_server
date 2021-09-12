# docker build -t elastic_ruby_server .
FROM ruby:3.0-alpine
LABEL maintainer="syright@gmail.com"

RUN apk add --no-cache openjdk11-jre-headless su-exec

ENV VERSION 7.9.3
ENV DOWNLOAD_URL "https://artifacts.elastic.co/downloads/elasticsearch"
ENV ES_TARBAL "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz"
ENV ES_TARBALL_ASC "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz.asc"
ENV EXPECTED_SHA_URL "${DOWNLOAD_URL}/elasticsearch-oss-${VERSION}-no-jdk-linux-x86_64.tar.gz.sha512"
ENV ES_TARBALL_SHA "679d02f2576aa04aefee6ab1b8922d20d9fc1606c2454b32b52e7377187435da50566c9000565df8496ae69d0882724fbf2877b8253bd6036c06367e854c55f6"
ENV GPG_KEY "46095ACC8548582C1A2699A9D27D666CD88E42B4"

RUN apk add --no-cache bash
RUN apk add --no-cache -t .build-deps wget ca-certificates gnupg openssl \
  && set -ex \
  && cd /tmp \
  && echo "===> Install Elasticsearch..." \
  && wget --progress=bar:force -O elasticsearch.tar.gz "$ES_TARBAL"; \
  if [ "$ES_TARBALL_SHA" ]; then \
  echo "$ES_TARBALL_SHA *elasticsearch.tar.gz" | sha512sum -c -; \
  fi; \
  if [ "$ES_TARBALL_ASC" ]; then \
  wget --progress=bar:force -O elasticsearch.tar.gz.asc "$ES_TARBALL_ASC"; \
  export GNUPGHOME="$(mktemp -d)"; \
  ( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEY" \
  || gpg --keyserver keyserver.pgp.com --recv-keys "$GPG_KEY" ); \
  gpg --batch --verify elasticsearch.tar.gz.asc elasticsearch.tar.gz; \
  rm -rf "$GNUPGHOME" elasticsearch.tar.gz.asc || true; \
  fi; \
  tar -xf elasticsearch.tar.gz \
  && ls -lah \
  && mv elasticsearch-$VERSION /usr/share/elasticsearch \
  && adduser -D -h /usr/share/elasticsearch elasticsearch \
  && echo "===> Creating Elasticsearch Paths..." \
  && for path in \
  /usr/share/elasticsearch/data \
  /usr/share/elasticsearch/logs \
  /usr/share/elasticsearch/config \
  /usr/share/elasticsearch/config/scripts \
  /usr/share/elasticsearch/tmp \
  /usr/share/elasticsearch/plugins \
  ; do \
  mkdir -p "$path"; \
  chown -R elasticsearch:elasticsearch "$path"; \
  done \
  && rm -rf /tmp/* /usr/share/elasticsearch/jdk \
  && apk del --purge .build-deps

# TODO: remove this (it removes X-Pack ML so it works on Alpine)
RUN rm -rf /usr/share/elasticsearch/modules/x-pack-ml/platform/linux-x86_64

# COPY config/elastic /usr/share/elasticsearch/config
# COPY config/logrotate /etc/logrotate.d/elasticsearch
# COPY elastic-entrypoint.sh /
# RUN chmod +x /elastic-entrypoint.sh
# COPY docker-healthcheck /usr/local/bin/

# WORKDIR /usr/share/elasticsearch

ENV JAVA_HOME /usr
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV ES_TMPDIR /usr/share/elasticsearch/tmp

VOLUME ["/usr/share/elasticsearch/data"]

# add new user
ARG USER=default
ENV HOME /home/$USER

RUN apk add sudo

RUN adduser -D default \
        && echo "default ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/default \
        && chmod 0440 /etc/sudoers.d/default

################################################################
################################################################

RUN gem update bundler

RUN apk update && apk upgrade
RUN apk add curl make g++ git

WORKDIR /app

ENV PROJECTS_ROOT /projects/
# ENV LOG_LEVEL DEBUG

COPY Gemfile* ./
COPY elastic_ruby_server.gemspec .
COPY lib/elastic_ruby_server/version.rb lib/elastic_ruby_server/version.rb

RUN bundle install -j 8

COPY . ./

USER default

RUN sudo chown -R default:elasticsearch /usr/share/elasticsearch/

COPY config/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY config/override.conf /etc/systemd/system/elasticsearch.service.d/override.conf
COPY config/limits.conf /etc/security/limits.conf

CMD "/app/exe/entry.sh"
