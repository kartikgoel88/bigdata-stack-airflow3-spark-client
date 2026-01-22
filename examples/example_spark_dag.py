"""
Example Airflow DAG demonstrating Spark job submission
This DAG shows how to submit Spark jobs from Airflow using the Spark client
"""

from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
with DAG(
    'example_spark_job',
    default_args=default_args,
    description='Example DAG for Spark job submission',
    schedule_interval=None,  # Manual trigger only
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['example', 'spark'],
) as dag:

    # Task 1: Check Spark connection
    check_spark = BashOperator(
        task_id='check_spark_connection',
        bash_command='$SPARK_HOME/bin/spark-submit --version',
    )

    # Task 2: Example Spark job (using spark-submit)
    # Note: This is a placeholder - replace with your actual Spark application
    spark_job = BashOperator(
        task_id='run_spark_job',
        bash_command="""
        $SPARK_HOME/bin/spark-submit \
            --master spark://spark-master:7077 \
            --class org.apache.spark.examples.SparkPi \
            $SPARK_HOME/examples/jars/spark-examples_*.jar \
            10
        """,
    )

    # Task 3: PySpark example
    pyspark_job = BashOperator(
        task_id='run_pyspark_job',
        bash_command="""
        $SPARK_HOME/bin/spark-submit \
            --master spark://spark-master:7077 \
            --executor-memory 1g \
            --executor-cores 2 \
            << 'EOF'
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("AirflowPySparkExample") \
    .getOrCreate()

# Your Spark code here
df = spark.range(10)
print(f"Count: {df.count()}")

spark.stop()
EOF
        """,
    )

    # Define task dependencies
    check_spark >> spark_job >> pyspark_job

