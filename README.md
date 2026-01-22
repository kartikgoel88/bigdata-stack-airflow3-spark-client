# Big Data Stack - Airflow 3 with Spark Client

A containerized Apache Airflow 3 setup with minimal Spark client, designed to work with the big data stack on the same network.

## Architecture

This project provides:

- **Apache Airflow 3.0.2**: Workflow orchestration platform
  - API Server (Web UI)
  - DAG Processor
  - Scheduler
- **Minimal Spark Client**: Spark libraries and tools for submitting jobs to external Spark clusters
- **PostgreSQL**: Metadata database for Airflow

The project uses the same network (`bigdata-hadoop-network`) as the `bigdata-stack-java8` project, allowing Airflow to connect to Hadoop, Hive, and Spark services running in that stack.

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 1.29 or higher)
- At least 4GB of available RAM
- At least 5GB of free disk space
- Spark tarball in `downloads/` directory (see Setup section)

## Quick Start

1. **Clone or navigate to the project directory:**
   ```bash
   cd bigdata-stack-airflow3-spark-client
   ```

2. **Set up environment variables:**
   ```bash
   cp env.example .env
   # Edit .env if needed
   ```

3. **Download Spark (if not already present):**
   ```bash
   mkdir -p downloads
   cd downloads
   wget https://archive.apache.org/dist/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz
   mv spark-3.5.8-bin-hadoop3.tgz spark-3.5.8-bin-hadoop3.tar.gz
   cd ..
   ```

4. **Build and start all services:**
   ```bash
   docker-compose up -d --build
   ```

5. **Wait for services to be ready** (this may take a few minutes):
   ```bash
   docker-compose ps
   ```

## Service URLs

Once all services are running, you can access:

- **Airflow Web UI**: http://localhost:8082
  - Username: `admin`
  - Password: `admin`

## Network Integration

This project uses the same Docker network (`bigdata-hadoop-network`) as the `bigdata-stack-java8` project. This allows:

- Airflow DAGs to submit Spark jobs to Spark clusters in the big data stack
- Access to HDFS (Hadoop Distributed File System)
- Connection to Hive Metastore and HiveServer2
- Integration with YARN ResourceManager

To use this with the big data stack:

1. Start the `bigdata-stack-java8` stack first
2. Then start this Airflow stack
3. Both will be on the same network and can communicate

## Spark Client Usage

The Spark client included in this project is minimal - it contains:

- `spark-submit` for submitting Spark applications
- Spark libraries (jars)
- PySpark Python bindings
- Configuration files

You can use it in Airflow DAGs to submit jobs to external Spark clusters:

```python
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime

with DAG(
    'spark_job_example',
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
) as dag:
    spark_task = SparkSubmitOperator(
        task_id='spark_job',
        application='/path/to/your/spark/app.py',
        conn_id='spark_default',
        conf={
            'spark.master': 'spark://spark-master:7077',
        },
    )
```

## Configuration

### Airflow Configuration

Configuration files are located in `config/airflow/`:
- `airflow.cfg`: Main Airflow configuration file

### Spark Configuration

Configuration files are located in `config/spark/`:
- `spark-defaults.conf`: Default Spark client configuration

### Environment Variables

Key environment variables can be set in `.env`:
- `SPARK_VERSION`: Spark version (default: 3.5.8)
- `SPARK_HOME`: Spark installation directory (default: /opt/spark)
- `SPARK_MASTER`: Spark master URL (default: spark://spark-master:7077)
- `AIRFLOW_WEB_PORT`: Port for Airflow Web UI (default: 8082)

## Project Structure

```
bigdata-stack-airflow3-spark-client/
├── dockerfiles/
│   └── Dockerfile.airflow-spark # Airflow 3 image with Spark client
├── docker-compose.yml           # Service orchestration
├── config/
│   ├── airflow/                # Airflow configuration files
│   ├── spark/                  # Spark client configuration
│   └── postgres/               # PostgreSQL initialization scripts
├── downloads/                   # Spark tarball (download separately)
├── examples/                   # Example DAGs
├── scripts/                    # Utility scripts
├── env.example                # Environment variables template
└── README.md                  # This file
```

## Troubleshooting

### Check service logs

```bash
# View logs for a specific service
docker-compose logs -f airflow-api-server
docker-compose logs -f airflow-scheduler
docker-compose logs -f airflow-init
```

### Restart services

```bash
# Restart all services
docker-compose restart

# Restart a specific service
docker-compose restart airflow-api-server
```

### Reset everything

```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v

# Rebuild and start
docker-compose up -d --build
```

### Common Issues

1. **Port conflicts**: Make sure port 8082 (Airflow Web UI) and 5433 (Airflow PostgreSQL) are not in use
2. **Memory issues**: Increase Docker memory allocation in Docker Desktop settings
3. **Network issues**: Ensure the `bigdata-hadoop-network` network exists (created by bigdata-stack-java8)
4. **Spark connection errors**: Ensure Spark cluster is running and accessible at the configured master URL

## Versions

- **Airflow**: 3.0.2
- **Spark Client**: 3.5.8
- **PostgreSQL**: 13
- **Java**: 11

## License

This project is provided as-is for educational and development purposes.
