#!/usr/bin/env bash
set -Eeo pipefail

shopt -s expand_aliases
alias dsbulk='java -jar /usr/local/bin/dsbulk.jar'

HOOKS_DIR="/hooks"
if [ -d "${HOOKS_DIR}" ]; then
  on_error(){
    run-parts -a "error" "${HOOKS_DIR}"
  }
  trap 'on_error' ERR
fi

if [ "${ASTRA_DB_HOST}" = "**None**" ]; then
  if [ "${ASTRA_DB_ID}" = "**None**" -a "${ASTRA_DB_REGION}" = "**None**" ]; then
    echo "You need to set the $ASTRA_DB_ID, $ASTRA_DB_REGION or ASTRA_DB_HOST environment variable.."
    exit 1
  else
    ASTRA_DB_HOST="${ASTRA_DB_ID}-${ASTRA_DB_REGION}.apps.astra.datastax.com"
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

KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

# Initialize vars
BACKUP_TMP_DIR="${BACKUP_DIR}/temp/"

# Remove old temp. backups
rm -rf "${BACKUP_TMP_DIR}"
rm -rf "logs/*"

#Initialize dirs
mkdir -p "${BACKUP_TMP_DIR}" "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Initialize filename vers
LAST_FILENAME="${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
DAILY_FILENAME="${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-`date +%Y%m%d`${BACKUP_SUFFIX}"
WEEKLY_FILENAME="${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-`date +%G%V`${BACKUP_SUFFIX}"
MONTHY_FILENAME="${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-`date +%Y%m`${BACKUP_SUFFIX}"
FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"

echo "Creating backup for keyspace ${ASTRA_DB_KEYSPACE} from  ${ASTRA_DB_ID} database ..."

# Load table definitions from keypsace
curl -s -L -X GET \
    https://${ASTRA_DB_HOST}/api/rest/v2/schemas/keyspaces/${ASTRA_DB_KEYSPACE}/tables \
    -H 'content-type: application/json' \
    -H "x-cassandra-token: ${ASTRA_DB_PASSWORD}" \
    -o ${BACKUP_TMP_DIR}/keyspace.json

ASTRA_DB_TABLES=$(cat ${BACKUP_TMP_DIR}/keyspace.json | jq -r '.data[].name');
ASTRA_DB_TABLES_COUNT=$(echo "$ASTRA_DB_TABLES" | wc -l)

echo "Found ${ASTRA_DB_TABLES_COUNT} tables in keyspace ${ASTRA_DB_KEYSPACE}"

#looping tables and save data as csv.gz
for TABLE in ${ASTRA_DB_TABLES}; do

  echo "Checking row count for table ${TABLE}"
  count=$(dsbulk count -k ${ASTRA_DB_KEYSPACE} -h ${ASTRA_DB_HOST} -u ${ASTRA_DB_USER} -p ${ASTRA_DB_PASSWORD} -b ${ASTRA_DB_SECURE_BUNDLE_FILE} -t ${TABLE});

  if [ "$count" -eq 0 ]; then
    echo "No rows in ${TABLE}"
  else
    echo "*******************************************************"
    echo "* Start unload: ${TABLE}                              *"
    echo "*******************************************************"
    dsbulk unload -h ${ASTRA_DB_HOST} -u ${ASTRA_DB_USER} -p ${ASTRA_DB_PASSWORD} -b ${ASTRA_DB_SECURE_BUNDLE_FILE} \
      -k ${ASTRA_DB_KEYSPACE} -t ${TABLE} \
      | gzip > ${BACKUP_DIR}/temp/${TABLE}.csv.gz
    
    
    #echo "*******************************************************"
    #echo "* Start load: ${TABLE}                              *"
    #echo "*******************************************************"
    # Get the size of the gz file
    #FILE_SIZE=$(stat -c %s "${BACKUP_DIR}/${TABLE}.csv.gz")

    # Check if the file size is greater than 20 bytes
    #if [ "$FILE_SIZE" -gt 20 ]; then
      # Load data from the gz file
      #zcat "${BACKUP_DIR}/${TABLE}.csv.gz" | \
      #dsbulk load -h "${ASTRA_DB_HOST}" -u "${ASTRA_DB_USER}" -p "${ASTRA_DB_PASSWORD}" -b "${ASTRA_DB_SECURE_BUNDLE_FILE}" \
      #  --dsbulk.connector.csv.maxCharsPerColumn -1 -k "${ASTRA_DB_KEYSPACE}" -t "${TABLE}"
    #else
      #echo "File size is not greater than 20 bytes. Skipping data loading."
    #fi
  fi
done

# Compress backup
tar -czvf "${FILE}" -C "${BACKUP_TMP_DIR}" .
rm -rf ${BACKUP_TMP_DIR}

#Copy (hardlink) for each entry
if [ -d "${FILE}" ]; then
  DFILENEW="${DFILE}-new"
  WFILENEW="${WFILE}-new"
  MFILENEW="${MFILE}-new"
  rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
  mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
  ln -f "${FILE}/"* "${DFILENEW}/"
  ln -f "${FILE}/"* "${WFILENEW}/"
  ln -f "${FILE}/"* "${MFILENEW}/"
  rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
  echo "Replacing daily backup ${DFILE} folder this last backup..."
  mv "${DFILENEW}" "${DFILE}"
  echo "Replacing weekly backup ${WFILE} folder this last backup..."
  mv "${WFILENEW}" "${WFILE}"
  echo "Replacing monthly backup ${MFILE} folder this last backup..."
  mv "${MFILENEW}" "${MFILE}"
else
  echo "Replacing daily backup ${DFILE} file this last backup..."
  ln -vf "${FILE}" "${DFILE}"
  echo "Replacing weekly backup ${WFILE} file this last backup..."
  ln -vf "${FILE}" "${WFILE}"
  echo "Replacing monthly backup ${MFILE} file this last backup..."
  ln -vf "${FILE}" "${MFILE}"
fi

# Update latest symlinks
echo "Point last backup file to this last backup..."
ln -svf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-latest${BACKUP_SUFFIX}"
echo "Point latest daily backup to this last backup..."
ln -svf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-latest${BACKUP_SUFFIX}"
echo "Point latest weekly backup to this last backup..."
ln -svf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-latest${BACKUP_SUFFIX}"
echo "Point latest monthly backup to this last backup..."
ln -svf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-latest${BACKUP_SUFFIX}"
#Clean old files
echo "Cleaning older files for keyspace ${ASTRA_DB_KEYSPACE} from ${ASTRA_DB_ID} database ..."
find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${ASTRA_DB_ID}-${ASTRA_DB_KEYSPACE}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'

echo "Astra Database keyspace backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi
