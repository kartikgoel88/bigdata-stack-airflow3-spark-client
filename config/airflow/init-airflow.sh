#!/bin/bash
set -e

# Use environment variables with defaults
POSTGRES_HOST=${AIRFLOW_POSTGRES_HOST:-airflow-postgres}
POSTGRES_USER=${AIRFLOW_POSTGRES_USER:-airflow}
POSTGRES_PASSWORD=${AIRFLOW_POSTGRES_PASSWORD:-airflow}
POSTGRES_DB=${AIRFLOW_POSTGRES_DB:-airflow}
AIRFLOW_ADMIN_USERNAME=${AIRFLOW_ADMIN_USERNAME:-admin}
AIRFLOW_ADMIN_PASSWORD=${AIRFLOW_ADMIN_PASSWORD:-admin}
AIRFLOW_ADMIN_EMAIL=${AIRFLOW_ADMIN_EMAIL:-admin@example.com}
AIRFLOW_ADMIN_FIRSTNAME=${AIRFLOW_ADMIN_FIRSTNAME:-Admin}
AIRFLOW_ADMIN_LASTNAME=${AIRFLOW_ADMIN_LASTNAME:-User}

echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c '\q' 2>/dev/null; do
  >&2 echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

>&2 echo "PostgreSQL is up - executing command"

# Disable database logging during initialization to avoid log table errors
export AIRFLOW__LOGGING__REMOTE_LOGGING=False
export AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID=""

echo "Initializing Airflow database..."
# Check if database is already initialized by checking for key tables
if PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 1 FROM information_schema.tables WHERE table_name='log'" 2>/dev/null | grep -q 1; then
    echo "Database appears to be initialized. Running migrations to ensure it's up to date..."
    # Run migrate to apply any pending migrations
    airflow db migrate || {
        echo "WARNING: Migration had issues, but continuing..."
    }
else
    echo "Database not initialized. Running initial migration..."
    # Airflow 3.x uses 'db migrate' instead of 'db init'
    airflow db migrate || {
        echo "ERROR: Database migration failed!"
        exit 1
    }
fi

# Verify key tables exist
echo "Verifying database schema..."
if ! PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 1 FROM information_schema.tables WHERE table_name='log'" 2>/dev/null | grep -q 1; then
    echo "ERROR: Required tables not found after migration. Retrying migration..."
    airflow db migrate || {
        echo "ERROR: Database migration failed on retry!"
        exit 1
    }
fi

echo "Creating Airflow admin user..."
airflow users create \
    --username ${AIRFLOW_ADMIN_USERNAME} \
    --firstname ${AIRFLOW_ADMIN_FIRSTNAME} \
    --lastname ${AIRFLOW_ADMIN_LASTNAME} \
    --role Admin \
    --email ${AIRFLOW_ADMIN_EMAIL} \
    --password ${AIRFLOW_ADMIN_PASSWORD} 2>/dev/null || echo "User already exists"

echo "Airflow initialization complete!"

