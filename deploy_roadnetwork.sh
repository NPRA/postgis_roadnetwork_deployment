#!/bin/sh
# scripts needs to run from the folder where this script is located

DOWNLOAD_PATH="/download"
UNZIP_PATH="/unzip"
WORKING_DIRECTORY="$(PWD)"


####### Variables need to be set for your local environment #######
DATABASE_NAME="-- database name --"
DATABASE_URL="-- database url --"
DATABASE_PORT="-- database port, without quotes --"
DATABASE_LOGIN="-- database login username --"
DATABASE_PASSWORD="-- database login password --"
###################################################################

DOWNLOAD_URL='https://nedlasting.geonorge.no/api/order'
DOWNLOAD_PAYLOAD='{"email":"","usageGroup":"stat","softwareClient":"Kartkatalogen","softwareClientVersion":"15.7.2599","orderLines":[{"metadataUuid":"8d0f9066-34f9-4423-be12-8e8523089313","areas":[{"code":"0000","name":"Hele landet","type":"landsdekkende"}],"projections":[{"code":"25833","name":"EUREF89 UTM sone 33, 2d","codespace":"http://www.opengis.net/def/crs/EPSG/0/25833"}],"formats":[{"code":"","name":"SpatiaLite ","type":""}],"usagePurpose":["forskning"]}]}' 

PSQL_SETUPT_SCRIPT="/setup_db.sql"
PSQL_OPTIMIZE_SCRIPT="/optimize_db.sql"
PSQL_TEST_SCRIPT="/test_query.sql"
PSQL_FUNCTIONS_SCRIPT="/create_routing_functions.sql"

export PGPASSWORD=$DATABASE_PASSWORD

# Messages as the script is starting
echo "Deploymentscripts for RoadNetwork"
echo "Running from path: ${WORKING_DIRECTORY}"

# create folders if they don't exist
mkdir -p "${WORKING_DIRECTORY}${DOWNLOAD_PATH}"
mkdir -p "${WORKING_DIRECTORY}${UNZIP_PATH}"

# download a file using curl
resp=$(curl --location "${DOWNLOAD_URL}" --header 'Content-Type: application/json' --header 'Cookie: _culture=no' --data "${DOWNLOAD_PAYLOAD}")
downloadUrl=$(jq -r '.files[].downloadUrl' <<< "$resp")
filename=$(jq -r '.files[].name' <<< "$resp")
echo "Downloading file: ${filename} from ${downloadUrl}"
curl --location "${downloadUrl}" --header 'Cookie: _culture=no' --output "${WORKING_DIRECTORY}${DOWNLOAD_PATH}/${filename}" 

# unzip the file
echo "Unzipping file: ${WORKING_DIRECTORY}${DOWNLOAD_PATH=}/${filename}"
unzip -o "${WORKING_DIRECTORY}${DOWNLOAD_PATH=}/${filename}" -d "${WORKING_DIRECTORY}/${UNZIP_PATH}"

# Set up necessary database requirements
echo "Setting up database"
createdb -h $DATABASE_URL -p $DATABASE_PORT -U $DATABASE_LOGIN -O $DATABASE_LOGIN $DATABASE_NAME
psql -h $DATABASE_URL -p $DATABASE_PORT -U $DATABASE_LOGIN -d $DATABASE_NAME -a -f "${WORKING_DIRECTORY}${PSQL_SETUPT_SCRIPT}"

# populate the POSTGRESQL database with SQLite data
# needs ogr2ogr installed
# get the zip file
zip_filename=$(ls -t $WORKING_DIRECTORY$UNZIP_PATH | head -n1)
echo "Databas filename: $zip_filename"

ogr2ogr -f "PostgreSQL" \
    PG:"host=${DATABASE_URL} port=${DATABASE_PORT} dbname=${DATABASE_NAME} user=${DATABASE_LOGIN} password=${DATABASE_PASSWORD}" \
    $WORKING_DIRECTORY$UNZIP_PATH/$zip_filename \
    -a_srs EPSG:25833 \
    --config PG_USE_COPY YES \
    -overwrite -progress

# Create clusters and additional indexes
echo "Optimizing database"
psql -h $DATABASE_URL -p $DATABASE_PORT -U $DATABASE_LOGIN -d $DATABASE_NAME -a -f "${WORKING_DIRECTORY}${PSQL_OPTIMIZE_SCRIPT}"
echo "Create then necessary functions"
psql -h $DATABASE_URL -p $DATABASE_PORT -U $DATABASE_LOGIN -d $DATABASE_NAME -a -f "${WORKING_DIRECTORY}${PSQL_FUNCTIONS_SCRIPT}"
#echo "Test the database to see if everything is working"
#psql -h $DATABASE_URL -p $DATABASE_PORT -U $DATABASE_LOGIN -d $DATABASE_NAME -a -f "${WORKING_DIRECTORY}${PSQ_TEST_SCRIPT}"

echo "Tidying up after setup, deleting temporary files and folders"
rm -rf "${WORKING_DIRECTORY}${DOWNLOAD_PATH}"
rm -rf "${WORKING_DIRECTORY}${UNZIP_PATH}"
