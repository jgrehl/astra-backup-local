FROM eclipse-temurin

ARG GOCRONVER=v0.0.10
ARG DSBULKVER=1.11.0
ARG TARGETOS
ARG TARGETARCH

# FIX Debian cross build
ARG DEBIAN_FRONTEND=noninteractive
RUN set -x \
	&& ln -s /usr/bin/dpkg-split /usr/sbin/dpkg-split \
	&& ln -s /usr/bin/dpkg-deb /usr/sbin/dpkg-deb \
	&& ln -s /bin/tar /usr/sbin/tar \
	&& ln -s /bin/rm /usr/sbin/rm \
	&& ln -s /usr/bin/dpkg-split /usr/local/sbin/dpkg-split \
	&& ln -s /usr/bin/dpkg-deb /usr/local/sbin/dpkg-deb \
	&& ln -s /bin/tar /usr/local/sbin/tar \
	&& ln -s /bin/rm /usr/local/sbin/rm
#

RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates curl jq && apt-get clean && rm -rf /var/lib/apt/lists/* \
	&& curl --fail --retry 4 --retry-all-errors -o /usr/local/bin/go-cron.gz -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH.gz \
	&& gzip -vnd /usr/local/bin/go-cron.gz && chmod a+x /usr/local/bin/go-cron \
  && curl --fail --retry 4 --retry-all-errors -o /usr/local/bin/dsbulk.jar -L https://repo.maven.apache.org/maven2/com/datastax/oss/dsbulk-distribution/$DSBULKVER/dsbulk-distribution-$DSBULKVER.jar \
  && chmod a+x /usr/local/bin/dsbulk.jar

ENV ASTRA_DB_ID="**None**" \
    ASTRA_DB_REGION="**None**" \
    ASTRA_DB_HOST="**None**" \
    ASTRA_DB_SECURE_BUNDLE_FILE="**None**" \
    ASTRA_DB_KEYSPACE="**None**" \
    ASTRA_DB_USER="token" \
    ASTRA_DB_PASSWORD="**None**" \
    SCHEDULE="@daily" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".tgz" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    BACKUP_KEEP_MINS=1440 \
    HEALTHCHECK_PORT=8080 \
    WEBHOOK_URL="**None**" \
    WEBHOOK_EXTRA_ARGS=""

COPY hooks /hooks
COPY backup.sh /backup.sh

VOLUME /backups

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/go-cron -s \"$SCHEDULE\" -p \"$HEALTHCHECK_PORT\" -- /backup.sh"]

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1
