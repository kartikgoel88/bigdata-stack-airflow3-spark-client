#!/bin/bash
set -e

# Use environment variables with defaults
POSTGRES_USER=${POSTGRES_USER:-airflow}
AIRFLOW_DB=${AIRFLOW_POSTGRES_DB:-airflow}

echo "Creating Airflow database if it doesn't exist..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE ${AIRFLOW_DB};
    GRANT ALL PRIVILEGES ON DATABASE ${AIRFLOW_DB} TO $POSTGRES_USER;
EOSQL

echo "Airflow database initialization complete!"

