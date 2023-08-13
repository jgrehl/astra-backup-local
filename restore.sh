BACKUP_DIR="backup"
ASTRA_DB_HOST="**None**"
ASTRA_DB_KEYSPACE="**None**"
ASTRA_DB_USER="token"
ASTRA_DB_PASSWORD="**None**"
ASTRA_DB_SECURE_BUNDLE_FILE="**None**"

#!/usr/bin/env bash
set -Eeo pipefail

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

# Initialize vars
BACKUP_TMP_DIR="${BACKUP_DIR}/temp/"

# Remove old temp. backups
rm -rf "${BACKUP_TMP_DIR}"
rm -rf "logs/*"

#Initialize dirs
mkdir -p "${BACKUP_TMP_DIR}"

echo "Processing restore for keyspace ${ASTRA_DB_KEYSPACE} to ${ASTRA_DB_ID} database ..."

ASTRA_DB_TABLES=$(cat ${BACKUP_TMP_DIR}/keyspace.json | jq -r '.data[].name');
ASTRA_DB_TABLES_COUNT=$(echo "$ASTRA_DB_TABLES" | wc -l)

echo "Found ${ASTRA_DB_TABLES_COUNT} tables in keyspace ${ASTRA_DB_KEYSPACE}"

#looping tables and save data as csv.gz
for TABLE in ${ASTRA_DB_TABLES}; do

  echo "*******************************************************"
  echo "* Start load: ${TABLE}                              *"
  echo "*******************************************************"
  # Get the size of the gz file
  FILE_SIZE=$(stat -c %s "${BACKUP_TMP_DIR}/${TABLE}.csv.gz")

  # Check if the file size is greater than 20 bytes
  if [ "$FILE_SIZE" -gt 20 ]; then
    # Load data from the gz file
    zcat "${BACKUP_DIR}/${TABLE}.csv.gz" | \
    dsbulk load -h "${ASTRA_DB_HOST}" -u "${ASTRA_DB_USER}" -p "${ASTRA_DB_PASSWORD}" -b "${ASTRA_DB_SECURE_BUNDLE_FILE}" \
      --dsbulk.connector.csv.maxCharsPerColumn -1 -k "${ASTRA_DB_KEYSPACE}" -t "${TABLE}"
  else
    echo "File size is not greater than 20 bytes. Skipping data loading."
  fi
    
done

rm -rf ${BACKUP_TMP_DIR}