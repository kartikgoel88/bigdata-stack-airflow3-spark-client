# YAML-Based Jobs DAG

This DAG reads job definitions from a YAML configuration file and dynamically creates Airflow tasks with support for both Bash and Spark operators.

## Features

- ✅ **10 jobs** defined in YAML configuration
- ✅ **1-to-1 dependencies**: Jobs that depend on a single previous job
- ✅ **Many-to-1 dependencies**: Jobs that depend on multiple previous jobs
- ✅ **BashOperator support**: For shell commands and scripts
- ✅ **SparkSubmitOperator support**: For Spark job submissions
- ✅ **Runs 3 times a day**: Scheduled every 8 hours (00:00, 08:00, 16:00)

## Files

- `yaml_based_jobs_dag.py` - Main DAG file that reads YAML configuration
- `jobs_config.yaml` - YAML configuration file with job definitions

## Job Dependency Structure

The 10 jobs are organized as follows:

```
job_001 (Entry point)
    ├── job_002 (1-to-1)
    │   ├── job_004 (1-to-1)
    │   └── job_006 (many-to-1: job_002 + job_003)
    └── job_003 (1-to-1, parallel with job_002)
        ├── job_005 (1-to-1)
        └── job_006 (many-to-1: job_002 + job_003)
            └── job_007 (many-to-1: job_004 + job_005)
                └── job_008 (many-to-1: job_006 + job_007)
                    ├── job_009 (1-to-1)
                    └── job_010 (many-to-1: job_008 + job_009)
```

### Dependency Patterns

1. **1-to-1 Dependencies:**
   - `job_001` → `job_002`
   - `job_002` → `job_004`
   - `job_003` → `job_005`
   - `job_008` → `job_009`

2. **Many-to-1 Dependencies:**
   - `job_006` depends on: `job_002` AND `job_003`
   - `job_007` depends on: `job_004` AND `job_005`
   - `job_008` depends on: `job_006` AND `job_007`
   - `job_010` depends on: `job_008` AND `job_009`

## YAML Configuration Format

### Job Definition

Each job in the YAML file has the following structure:

```yaml
jobs:
  - id: job_001                    # Unique job identifier (required)
    name: "Job Display Name"       # Human-readable name (optional)
    operator: "bash"               # Operator type: "bash" or "spark" (required)
    command: "echo 'command'"      # Bash command (required for bash operator)
    dependencies: []                # List of job IDs this job depends on
```

### Bash Operator Job

```yaml
- id: job_001
  name: "Data Extraction Job"
  operator: "bash"
  command: "echo 'Extracting data' && sleep 2"
  dependencies: []
```

### Spark Operator Job

```yaml
- id: job_006
  name: "Data Aggregation Job"
  operator: "spark"
  application: "/path/to/spark/aggregation.py"
  master: "spark://spark-master:7077"
  conn_id: "spark_default"         # Optional: Spark connection ID
  spark_config:                     # Optional: Additional Spark config
    spark.executor.memory: "2g"
    spark.executor.cores: "2"
  dependencies:
    - job_002
    - job_003
```

### DAG Configuration

```yaml
dag_config:
  dag_id: "yaml_based_jobs"
  description: "DAG description"
  schedule: "0 */8 * * *"          # Cron expression (3x daily)
  start_date: "2024-01-01"         # YYYY-MM-DD format
  catchup: false
  tags:
    - "yaml-config"
    - "3x-daily"
```

## Schedule

The DAG runs **3 times per day** at:
- **00:00** (Midnight)
- **08:00** (8 AM)
- **16:00** (4 PM)

Schedule is defined in the YAML file: `0 */8 * * *` (every 8 hours)

## Usage

### 1. Copy Files to Airflow DAGs Directory

```bash
# Copy both files to your Airflow DAGs directory
cp examples/yaml_based_jobs_dag.py /path/to/airflow/dags/
cp examples/jobs_config.yaml /path/to/airflow/dags/
```

**Important:** Both files must be in the same directory!

### 2. Customize Jobs

Edit `jobs_config.yaml` to customize:
- Job commands (for BashOperator)
- Spark application paths (for SparkSubmitOperator)
- Dependencies
- Schedule

### 3. Verify in Airflow UI

1. Open Airflow Web UI
2. Navigate to DAGs list
3. Find `yaml_based_jobs` DAG
4. Enable the DAG
5. View the Graph to see job dependencies

## Customization Examples

### Adding a New Job

Add to `jobs_config.yaml`:

```yaml
jobs:
  # ... existing jobs ...
  
  - id: job_011
    name: "New Processing Job"
    operator: "bash"
    command: "python /path/to/script.py"
    dependencies:
      - job_010
```

### Changing Schedule

To run 4 times a day (every 6 hours):

```yaml
dag_config:
  schedule: "0 */6 * * *"  # 00:00, 06:00, 12:00, 18:00
```

### Using Spark with Custom Config

```yaml
- id: spark_job
  name: "Custom Spark Job"
  operator: "spark"
  application: "/path/to/app.py"
  master: "spark://spark-master:7077"
  conn_id: "spark_default"
  spark_config:
    spark.executor.memory: "4g"
    spark.executor.cores: "4"
    spark.driver.memory: "2g"
  dependencies:
    - job_001
```

## Requirements

- **PyYAML**: Required for YAML parsing
  ```bash
  pip install pyyaml
  ```

- **Apache Airflow**: Version 2.x or 3.x

- **Spark Provider** (for Spark jobs):
  ```bash
  pip install apache-airflow-providers-apache-spark
  ```

## Troubleshooting

### YAML File Not Found

**Error:** `FileNotFoundError: Configuration file not found`

**Solution:** Ensure `jobs_config.yaml` is in the same directory as `yaml_based_jobs_dag.py`

### Missing Dependency

**Error:** `ValueError: Dependency 'job_XXX' not found`

**Solution:** Check that all job IDs in `dependencies` list exist in the jobs list

### Spark Connection Error

**Error:** Spark job fails to connect

**Solution:** 
1. Verify Spark connection ID exists in Airflow connections
2. Check Spark master URL is correct
3. Ensure Spark cluster is accessible

### Invalid YAML Syntax

**Error:** YAML parsing errors

**Solution:** Validate YAML syntax using:
```bash
python -c "import yaml; yaml.safe_load(open('jobs_config.yaml'))"
```

## Job Execution Flow

When the DAG runs:

1. **job_001** starts (no dependencies)
2. **job_002** and **job_003** run in parallel (both depend on job_001)
3. **job_004** runs after job_002 completes
4. **job_005** runs after job_003 completes
5. **job_006** waits for both job_002 AND job_003 (many-to-1)
6. **job_007** waits for both job_004 AND job_005 (many-to-1)
7. **job_008** waits for both job_006 AND job_007 (many-to-1)
8. **job_009** runs after job_008 completes
9. **job_010** waits for both job_008 AND job_009 (many-to-1)

## Example Output

In Airflow Graph View, you'll see:
- Linear chains for 1-to-1 dependencies
- Converging paths for many-to-1 dependencies
- Parallel branches where jobs can run simultaneously

## Notes

- All jobs are created dynamically from YAML
- Dependencies are validated at DAG parsing time
- Both BashOperator and SparkSubmitOperator are supported
- The DAG automatically handles 1-to-1 and many-to-1 dependencies
- Schedule can be customized in the YAML file

