#!/usr/bin/env bash
set -Eeo pipefail

shopt -s expand_aliases
alias dsbulk='java -jar /usr/local/bin/dsbulk.jar'

if [ "${ASTRA_DB_HOST}" = "**None**" ]; then
  if [ "${ASTRA_DB_ID}" = "**None**" -a "${ASTRA_DB_REGION}" = "**None**" ]; then
    echo "You need to set the ASTRA_DB_ID, ASTRA_DB_REGION or ASTRA_DB_HOST environment variable.."
    exit 1
  else
    ASTRA_DB_HOST = $ASTRA_DB_ID-$ASTRA_DB_REGION.apps.astra.datastax.com
  fi
fi

if [ "${ASTRA_DB_KEYSPACE}" = "**None**" ]; then
  echo "You need to set the ASTRA_DB_KEYSPACE environment variable."
  exit 1
fi

if [ "${ASTRA_DB_USER}" = "**None**" ]; then
  echo "You need to set the ASTRA_DB_USER environment variable."
  exit 1
fi

if [ "${ASTRA_DB_PASSWORD}" = "**None**" ]; then
  echo "You need to set the ASTRA_DB_PASSWORD environment variable."
  exit 1
fi

if [ "${ASTRA_DB_SECURE_BUNDLE_FILE}" = "**None**" ]; then
  echo "You need to set the ASTRA_DB_SECURE_BUNDLE_FILE environment variable."
  exit 1
fi

if [ "${ASTRA_DB_BACKUP_FILE}" = "**None**" ]; then
  echo "You need to set the ASTRA_DB_BACKUP_FILE environment variable."
  exit 1
fi

if [ ! -f "${ASTRA_DB_BACKUP_FILE}" ]; then
  echo "ASTRA_DB_BACKUP_FILE does not exist $ASTRA_DB_BACKUP_FILE"
  exit 1
fi

# Initialize vars
BACKUP_TMP_DIR="${BACKUP_DIR}/temp/"

# Remove old temp. backups
rm -rf "${BACKUP_TMP_DIR}"
rm -rf "logs/*"

#Initialize dirs
mkdir -p "${BACKUP_TMP_DIR}"

echo "Processing restore for keyspace ${ASTRA_DB_KEYSPACE} to ${ASTRA_DB_ID} database ..."

#decompress backup
tar -zxvf $ASTRA_DB_BACKUP_FILE -C $BACKUP_TMP_DIR

# parse tables
ASTRA_DB_TABLES=$(cat ${BACKUP_TMP_DIR}/keyspace.json | jq -r '.data[].name');
ASTRA_DB_TABLES_COUNT=$(echo "$ASTRA_DB_TABLES" | wc -l)

echo "Found ${ASTRA_DB_TABLES_COUNT} tables in keyspace ${ASTRA_DB_KEYSPACE}"

echo "*******************************************************"
array=$(cat ${BACKUP_TMP_DIR}/keyspace.json | jq -c '.data[]')
for d in $array
do
  echo "* Start create table: $(echo $d | jq -r '.name')"
  #push table definitions
  curl -s -L -X POST \
      https://${ASTRA_DB_HOST}/api/rest/v2/schemas/keyspaces/${ASTRA_DB_KEYSPACE}/tables \
      -H 'content-type: application/json' \
      -H "Accept: application/json" \
      -H "x-cassandra-token: ${ASTRA_DB_PASSWORD}" \
      --data "$d"
done
echo "*******************************************************"

echo "*******************************************************"
#looping tables and save data as csv.gz
for TABLE in ${ASTRA_DB_TABLES}; do
  
  #check if table data exists
  if [ -f ${BACKUP_TMP_DIR}/${TABLE}.csv.gz ]; then

    echo "* Start load: ${TABLE}"

    # Load data from the gz file
    zcat "${BACKUP_TMP_DIR}/${TABLE}.csv.gz" | \
    dsbulk load $DSBULK_OPTS -h "${ASTRA_DB_HOST}" -u "${ASTRA_DB_USER}" -p "${ASTRA_DB_PASSWORD}" -b "${ASTRA_DB_SECURE_BUNDLE_FILE}" \
      --dsbulk.connector.csv.maxCharsPerColumn -1 -k "${ASTRA_DB_KEYSPACE}" -t "${TABLE}"
  else
    echo "* No table data found for ${TABLE}"
  fi
done
echo "*******************************************************"