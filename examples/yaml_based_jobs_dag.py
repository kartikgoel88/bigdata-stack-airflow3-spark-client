"""
Airflow DAG that reads job definitions from YAML file
Supports BashOperator, SparkSubmitOperator, and External Dependency Sensors with TaskGroups
Jobs can have 1-to-1 or many-to-1 dependencies (internal and external)
Spark jobs use dynamic task mapping
Runs 3 times a day
"""

import yaml
from pathlib import Path
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.sensors.filesystem import FileSensor
from airflow.providers.http.sensors.http import HttpSensor
from airflow.providers.common.sql.sensors.sql import SqlSensor
from airflow.utils.task_group import TaskGroup
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def load_jobs_config():
    """Load job configuration from YAML file"""
    dag_file_path = Path(__file__)
    dag_dir = dag_file_path.parent
    yaml_file = dag_dir / 'jobs_config.yaml'
    
    if not yaml_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {yaml_file}")
    
    with open(yaml_file, 'r') as f:
        config = yaml.safe_load(f)
    
    return config


def parse_start_date(date_str):
    """Parse start date string to datetime object"""
    try:
        return datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return datetime(2024, 1, 1)


def organize_jobs_into_groups(jobs: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """Organize jobs into logical TaskGroups"""
    groups = {
        'extraction_validation': [],
        'transformation': [],
        'spark_processing': [],
        'quality_loading': [],
        'external_dependencies': [],
    }
    
    for job in jobs:
        job_id = job.get('id', '')
        operator_type = job.get('operator', 'bash').lower()
        
        # Categorize jobs based on operator type first (external dependencies)
        if operator_type in ['external_task_sensor', 'file_sensor', 'http_sensor', 'sql_sensor']:
            groups['external_dependencies'].append(job)
        # Then categorize by ID patterns or operator type
        elif '001' in job_id or '002' in job_id:
            groups['extraction_validation'].append(job)
        elif '003' in job_id or '004' in job_id or '005' in job_id:
            groups['transformation'].append(job)
        elif operator_type == 'spark':
            groups['spark_processing'].append(job)
        else:
            groups['quality_loading'].append(job)
    
    return groups


# Load configuration
config = load_jobs_config()
jobs = config.get('jobs', [])
dag_config = config.get('dag_config', {})

# Extract DAG configuration
dag_id = dag_config.get('dag_id', 'yaml_based_jobs')
description = dag_config.get('description', 'DAG with jobs defined in YAML - TaskGroups with Dynamic Spark Mapping')
schedule_interval = dag_config.get('schedule', '0 */8 * * *')
start_date_str = dag_config.get('start_date', '2024-01-01')
start_date = parse_start_date(start_date_str)
catchup = dag_config.get('catchup', False)
tags = dag_config.get('tags', ['yaml-config', 'taskgroups', 'dynamic-mapping'])

# Organize jobs into groups
job_groups = organize_jobs_into_groups(jobs)

# Separate jobs by operator type
spark_jobs = [job for job in jobs if job.get('operator', '').lower() == 'spark']
bash_jobs = [job for job in jobs if job.get('operator', '').lower() == 'bash']
external_jobs = [job for job in jobs if job.get('operator', '').lower() in 
                 ['external_task_sensor', 'file_sensor', 'http_sensor', 'sql_sensor']]

# Create the DAG
with DAG(
    dag_id=dag_id,
    default_args=default_args,
    description=description,
    schedule_interval=schedule_interval,
    start_date=start_date,
    catchup=catchup,
    tags=tags,
) as dag:

    # Dictionary to store all tasks
    tasks: Dict[str, Any] = {}
    
    # ============================================================================
    # TaskGroup 1: Extraction & Validation
    # ============================================================================
    with TaskGroup(group_id='extraction_validation', tooltip='Data Extraction and Validation Jobs') as extraction_group:
        for job in job_groups['extraction_validation']:
            job_id = job.get('id')
            job_name = job.get('name', job_id)
            command = job.get('command', f'echo "Executing {job_name}"')
            
            tasks[job_id] = BashOperator(
                task_id=job_id,
                bash_command=command,
            )
    
    # ============================================================================
    # TaskGroup 2: Transformation
    # ============================================================================
    with TaskGroup(group_id='transformation', tooltip='Data Transformation Jobs') as transformation_group:
        for job in job_groups['transformation']:
            job_id = job.get('id')
            job_name = job.get('name', job_id)
            command = job.get('command', f'echo "Executing {job_name}"')
            
            tasks[job_id] = BashOperator(
                task_id=job_id,
                bash_command=command,
            )
    
    # ============================================================================
    # TaskGroup 3: Spark Processing (Dynamic Task Mapping)
    # ============================================================================
    with TaskGroup(group_id='spark_processing', tooltip='Spark Processing Jobs with Dynamic Mapping') as spark_group:
        # Dynamically create SparkSubmitOperator tasks from YAML configuration
        # This is dynamic task creation - tasks are generated from config at DAG parse time
        for job in spark_jobs:
            job_id = job.get('id')
            job_name = job.get('name', job_id)
            
            # Build Spark configuration
            spark_conf = {
                'spark.master': job.get('master', 'spark://spark-master:7077'),
            }
            if 'spark_config' in job:
                spark_conf.update(job['spark_config'])
            
            # Create SparkSubmitOperator dynamically from config
            tasks[job_id] = SparkSubmitOperator(
                task_id=job_id,
                application=job.get('application'),
                conn_id=job.get('conn_id', 'spark_default'),
                conf=spark_conf,
                name=job_name,
            )
        
        # Alternative: True dynamic task mapping using expand() with BashOperator
        # Uncomment below to use Airflow's expand() for runtime dynamic mapping
        # This creates mapped tasks that expand at runtime
        """
        if spark_jobs:
            # Prepare configurations for mapping
            spark_commands = []
            for job in spark_jobs:
                spark_conf = {'spark.master': job.get('master', 'spark://spark-master:7077')}
                if 'spark_config' in job:
                    spark_conf.update(job['spark_config'])
                
                conf_args = ' '.join([f"--conf {k}={v}" for k, v in spark_conf.items()])
                cmd = (
                    f"$SPARK_HOME/bin/spark-submit "
                    f"--master {job.get('master')} "
                    f"--name {job.get('name')} "
                    f"{conf_args} {job.get('application')}"
                )
                spark_commands.append(cmd)
            
            # Dynamic mapping with expand()
            base_spark = BashOperator.partial(task_id='spark_job_mapped')
            mapped_spark = base_spark.expand(bash_command=spark_commands)
        """
    
    # ============================================================================
    # TaskGroup 4: Quality & Loading
    # ============================================================================
    with TaskGroup(group_id='quality_loading', tooltip='Quality Checks and Data Loading Jobs') as quality_group:
        for job in job_groups['quality_loading']:
            job_id = job.get('id')
            job_name = job.get('name', job_id)
            command = job.get('command', f'echo "Executing {job_name}"')
            
            tasks[job_id] = BashOperator(
                task_id=job_id,
                bash_command=command,
            )
    
    # ============================================================================
    # TaskGroup 5: External Dependencies (Sensors)
    # ============================================================================
    with TaskGroup(group_id='external_dependencies', tooltip='External Dependency Sensors') as external_group:
        for job in external_jobs:
            job_id = job.get('id')
            job_name = job.get('name', job_id)
            operator_type = job.get('operator', '').lower()
            
            if operator_type == 'external_task_sensor':
                # ExternalTaskSensor - waits for a task in another DAG
                tasks[job_id] = ExternalTaskSensor(
                    task_id=job_id,
                    external_dag_id=job.get('external_dag_id'),
                    external_task_id=job.get('external_task_id'),
                    timeout=job.get('timeout', 3600),
                    poke_interval=job.get('poke_interval', 60),
                    mode='poke',  # or 'reschedule'
                )
            
            elif operator_type == 'file_sensor':
                # FileSensor - waits for a file to appear
                tasks[job_id] = FileSensor(
                    task_id=job_id,
                    filepath=job.get('filepath'),
                    fs_conn_id=job.get('fs_conn_id', 'fs_default'),
                    timeout=job.get('timeout', 3600),
                    poke_interval=job.get('poke_interval', 60),
                )
            
            elif operator_type == 'http_sensor':
                # HttpSensor - waits for HTTP endpoint to be available
                tasks[job_id] = HttpSensor(
                    task_id=job_id,
                    http_conn_id=job.get('http_conn_id'),
                    endpoint=job.get('endpoint', '/'),
                    timeout=job.get('timeout', 1800),
                    poke_interval=job.get('poke_interval', 30),
                    method='GET',
                )
            
            elif operator_type == 'sql_sensor':
                # SqlSensor - waits for SQL condition to be true
                tasks[job_id] = SqlSensor(
                    task_id=job_id,
                    conn_id=job.get('conn_id'),
                    sql=job.get('sql'),
                    timeout=job.get('timeout', 3600),
                    poke_interval=job.get('poke_interval', 60),
                )
    
    # ============================================================================
    # Set up dependencies between tasks and groups
    # ============================================================================
    for job in jobs:
        job_id = job.get('id')
        dependencies = job.get('dependencies', [])
        
        if job_id not in tasks:
            continue
        
        if dependencies:
            upstream_tasks = []
            for dep_id in dependencies:
                if dep_id in tasks:
                    upstream_tasks.append(tasks[dep_id])
                else:
                    raise ValueError(f"Dependency '{dep_id}' not found for job '{job_id}'")
            
            # Set dependencies
            if len(upstream_tasks) == 1:
                upstream_tasks[0] >> tasks[job_id]
            else:
                upstream_tasks >> tasks[job_id]
    
    # Note: TaskGroup dependencies are handled by individual task dependencies above
    # TaskGroups provide visual organization in the Airflow UI but don't enforce execution order
    # Individual task dependencies (set above) control the actual execution flow
    #
    # External Dependencies:
    # - ExternalTaskSensor: Waits for tasks in other DAGs to complete
    # - FileSensor: Waits for files to appear in storage (S3, HDFS, local filesystem)
    # - HttpSensor: Waits for HTTP endpoints to be available
    # - SqlSensor: Waits for SQL conditions to be met in databases
    # All external dependencies can be mixed with internal job dependencies

