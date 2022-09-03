#!/bin/bash
#
# Env: - at least ONE of the follow MUST be set
#
#   DLBP_LIST        - a space-separated list of DLBP schemas, if to be created
#   DAP_LIST         - a space-separated list of DAP schemas, if to be created
#   DAC_LIST         - a space-separated list of DAC schemas, if to be created
#   STEWARD_SCHEMA   - name of Steward schema, if to be created
#   WEBCLIENT_SCHEMA - name of webclient schema, if to be created
#
# For each schema in the above list, optional USER and PASSWORD can supplied in the form of {SCHEMA}_USER and {SCHEMA}_PASSWORD
# the default values are {schema}admin and "password" respectively if not set.
#
# eg. if DLBP_LIST="mybank1 mybank2", then MYBANK1_USER and MYBANK1_PASSWORD can be set in the environment to supply
#     admin user and password for mybank1 schema.
#

#
# getPostgresUrl generate postgres url from schema and user
#
getPostgresUrl() {
  local schema=$1
  #
  # derive the optional variable names for {SCHEMA}_USER and {SCHEMA}_PASSWORD
  #
  schema_uppercase=$(echo $schema | tr '[:lower:]' '[:upper:]')
  eval "schema_user=\$${schema_uppercase}_USER"
  eval "schema_password=\$${schema_uppercase}_PASSWORD"
  local user=${schema_user:-${schema}admin}
  local password=${schema_password:-password}
  echo "postgres://${user}:${password}@${POSTGRES_URL}/${POSTGRES_DB}?sslmode=disable&search_path=${schema}"
}

# setup golang-migrate
echo "setup golang-migrate"
# install curl
type curl || apk add curl || yum install -y curl || apt-get install -y curl
# download and unzip golang-migrate
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.15.2/migrate.linux-amd64.tar.gz | tar xvz

if [ $? -ne 0 ]; then 
  tar xvz /tmp/db-setup/migrate.linux-amd64.tar.gz
fi

# migrate steward db
if [ ! -z "${STEWARD_SCHEMA}" ]; then
  echo "--- create steward schema: $STEWARD_SCHEMA ---"
  ./migrate -database $(getPostgresUrl ${STEWARD_SCHEMA}) -path /tmp/ddl/steward up
fi

# migrate web client db
if [ ! -z "${WEBCLIENT_SCHEMA}" ]; then
  echo "--- create webclient schema: $WEBCLIENT_SCHEMA ---"
  ./migrate -database $(getPostgresUrl ${WEBCLIENT_SCHEMA}) -path /tmp/wc-ddl up
fi

# create member tables
for schema in ${DAC_LIST}; do
  echo "--- create DAC schema: $schema ---"
  ./migrate -database $(getPostgresUrl $schema) -path /tmp/ddl/dac up
done
for schema in ${DAP_LIST}; do
  echo "--- create DAP schema: $schema ---"
  ./migrate -database $(getPostgresUrl $schema) -path /tmp/ddl/dap up
done
for schema in ${DLBP_LIST}; do
  echo "--- create DLBP schema: $schema ---"
  ./migrate -database $(getPostgresUrl $schema) -path /tmp/ddl/dlbp up
done
