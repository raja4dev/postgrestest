#!/usr/bin/env bash
#
# Env: - at least ONE of the follow MUST be set
#
#   DLBP_LIST        - a space-separated list of DLBP schemas, if to be created
#   DAP_LIST         - a space-separated list of DAP schemas, if to be created
#   DAC_LIST         - a space-separated list of DAC schemas, if to be created
#   STEWARD_SCHEMA   - name of Steward schema, if to be created
#   WEBCLIENT_SCHEMA - name of webclient schema, if to be created
#   MYAM_SCHEMA      - name of myam session schema, if to be created
#
# For each schema in the above list, optional USER and PASSWORD can supplied in the form of {SCHEMA}_USER and {SCHEMA}_PASSWORD
# the default values are {schema}admin and "password" respectively if not set.
#
# eg. if DLBP_LIST="mybank1 mybank2", then MYBANK1_USER and MYBANK1_PASSWORD can be set in the environment to supply
#     admin user and password for mybank1 schema.
#

#
# genCreateSchemaSql generate SQL statements for creating a new schema
#
genCreateSchemaSql() {
    local schema_name=$1
    cat << END_SQL
-- create $schema_name schema
        DROP SCHEMA IF EXISTS $schema_name CASCADE;
        CREATE SCHEMA $schema_name;
END_SQL

}

#
# genCreateUserSql generates SQL statements for creating an admin user for a given schema
#
genCreateUserSql() {
    local schema=$1
    local user=${2:-${schema}admin}
    local password=${3:-password}

    cat << END_SQL

-- create $schema
DROP USER IF EXISTS ${user};
CREATE USER $user WITH PASSWORD '${password}' LOGIN;
ALTER SCHEMA ${schema} OWNER TO ${user};

GRANT ALL PRIVILEGES ON SCHEMA ${schema} TO ${user};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${schema} TO ${user};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ${schema} TO ${user};

ALTER ROLE ${user} SET search_path = ${schema}, "\$user";

END_SQL

}


#
# --------- main ---------------------
#

all_schemas="${DLBP_LIST} ${DAP_LIST} ${DAC_LIST} ${STEWARD_SCHEMA} ${WEBCLIENT_SCHEMA} ${MYAM_SCHEMA}"

if [ -z "$(echo ${all_schemas} | tr -d ' ')" ] ; then
    echo at least one of these environment variables must be set: DLBP_LIST, DAP_LIST, DAC_LIST, STEWARD_SCHEMA, WEBCLIENT_SCHEMA, MYAM_SCHEMA
    exit 1
fi

# clear database on container restart
# this is to ensure setup-postgres.sql is run every time to pick up new changes
#
# WARNING: DO NOT do this beyond DEV environment where data must be retained across restarts
echo "Starting Postgres fresh. removing existing db data in $$PGDATA ..."
rm -rf $$PGDATA/**

echo "Generating postgres DDL ..."

setup_file=/docker-entrypoint-initdb.d/setup-postgres.sql
echo > $setup_file

# create schemas
for schema in ${all_schemas}; do
    echo "Creating schema $schema"
    genCreateSchemaSql $schema >> $setup_file
done

# create user and grand all permissions
for schema in ${all_schemas}; do

    #
    # derive the optional variable names for {SCHEMA}_USER and {SCHEMA}_PASSWORD
    #
    schema_uppercase=$(echo $schema | tr '[:lower:]' '[:upper:]')
    eval "schema_user=\$${schema_uppercase}_USER"
    eval "schema_password=\$${schema_uppercase}_PASSWORD"

    genCreateUserSql $schema "$schema_user" "$schema_password" >> $setup_file
done

docker-entrypoint.sh postgres

