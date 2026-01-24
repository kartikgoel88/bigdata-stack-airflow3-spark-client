# Complex 1000 Jobs Airflow Project

This project contains a comprehensive Airflow DAG setup with **1000 jobs** demonstrating various workflow patterns and scheduling requirements.

## Overview

The project consists of **5 separate DAGs** that together contain 1000 tasks, each demonstrating different patterns:

1. **complex_jobs_daily** - 400 tasks (Daily schedule)
2. **complex_jobs_5x_daily** - 200 tasks (5 times per day)
3. **complex_jobs_weekly** - 150 tasks (Every 7 days)
4. **complex_jobs_manual** - 150 tasks (Time-triggered/Manual)
5. **complex_jobs_additional** - 100 tasks (Every 6 hours)

**Total: 1000 tasks**

## DAG Details

### 1. complex_jobs_daily (400 tasks)
**Schedule:** `0 0 * * *` (Daily at midnight)

**Task Groups:**
- **Linear Chain (50 tasks):** Tasks with direct sequential dependencies
  - `daily_linear_000` → `daily_linear_001` → ... → `daily_linear_049`
  
- **Parallel Groups (100 tasks):** 10 groups of 10 tasks each running in parallel
  - Each group has no internal dependencies (all run simultaneously)
  - Groups: `daily_parallel_group0_task00-09` through `daily_parallel_group9_task00-09`
  
- **Multiple Dependencies (100 tasks):** Tasks depending on 2-3 previous tasks
  - `daily_multi_dep_000-004`: Entry points (no dependencies)
  - `daily_multi_dep_005-099`: Each depends on 2-3 randomly selected previous tasks
  
- **Mixed Pattern (150 tasks):** 15 sections combining linear and parallel
  - Each section: 1 first task → 9 parallel tasks
  - Sections: `daily_mixed_section0-14`

### 2. complex_jobs_5x_daily (200 tasks)
**Schedule:** `0 */5 * * *` (Every 5 hours = 5 times per day: 00:00, 05:00, 10:00, 15:00, 20:00)

**Task Groups:**
- **Linear Chain (20 tasks):** Sequential dependencies
  - `5x_daily_task_000` → `5x_daily_task_001` → ... → `5x_daily_task_019`
  
- **Parallel Groups (80 tasks):** 8 groups of 10 tasks
  - Each group's first task depends on previous group
  - Remaining 9 tasks in each group run in parallel, depending on group's first task
  
- **Multiple Dependencies (100 tasks):** Complex dependency graph
  - Tasks 100-199 depend on 1-3 randomly selected previous tasks

### 3. complex_jobs_weekly (150 tasks)
**Schedule:** `0 0 * * 0` (Every Sunday at midnight - every 7 days)

**Task Groups:**
- **Linear Chain (30 tasks):** Sequential execution
  - `weekly_task_000` → `weekly_task_001` → ... → `weekly_task_029`
  
- **Parallel Groups (60 tasks):** 6 groups of 10 tasks
  - Sequential groups with parallel execution within each group
  
- **Multiple Dependencies (60 tasks):** Tasks depending on 2-4 previous tasks
  - Complex dependency graph for tasks 90-149

### 4. complex_jobs_manual (150 tasks)
**Schedule:** `None` (Manual/Time-triggered only)

**Task Groups:**
- **Entry Points (10 tasks):** Starting tasks with no dependencies
  - `manual_task_000-009`
  
- **Linear Chains (40 tasks):** 10 chains of 4 tasks each
  - Each chain starts from one entry point
  - Tasks 10-49
  
- **Parallel Groups (50 tasks):** 5 groups of 10 tasks
  - Sequential groups with internal parallel execution
  
- **Complex Dependencies (50 tasks):** Tasks 100-149
  - Each depends on 2-5 randomly selected previous tasks

### 5. complex_jobs_additional (100 tasks)
**Schedule:** `0 */6 * * *` (Every 6 hours)

**Task Patterns:**
- **Entry Points (5 tasks):** `additional_task_000-004`
- **Fan-out (20 tasks):** Each entry point spawns 4 tasks (5 × 4 = 20)
- **Fan-in (25 tasks):** Multiple tasks converge into single tasks
- **Diamond Pattern (25 tasks):** Split → Parallel branches → Merge
- **Final Complex (25 tasks):** Mixed dependencies

## Dependency Patterns Demonstrated

### 1. Direct Dependencies (Linear Chains)
Tasks that directly depend on the previous task in sequence.
```
Task_A → Task_B → Task_C → Task_D
```

### 2. Parallel Execution
Tasks that can run simultaneously with no dependencies between them.
```
Task_A → [Task_B, Task_C, Task_D]  (B, C, D run in parallel)
```

### 3. Multiple Dependencies
Tasks that depend on multiple previous tasks (fan-in pattern).
```
[Task_A, Task_B, Task_C] → Task_D  (D waits for A, B, and C)
```

### 4. Mixed Patterns
Combinations of linear and parallel execution.
```
Task_A → [Task_B, Task_C] → Task_D → [Task_E, Task_F]
```

## Scheduling Patterns

1. **Daily:** Runs once per day at midnight
2. **5x Daily:** Runs 5 times per day (every 4 hours)
3. **Weekly (7 days):** Runs every Sunday (every 7 days)
4. **Time-triggered:** Manual trigger only (on-demand)
5. **Every 6 hours:** Additional scheduled jobs

## Usage

1. **Copy the DAG file to your Airflow DAGs directory:**
   ```bash
   cp examples/complex_1000_jobs_dag.py /path/to/airflow/dags/
   ```

2. **The DAGs will appear in Airflow UI:**
   - Navigate to Airflow Web UI
   - You should see 5 new DAGs listed
   - Each DAG can be enabled/disabled independently

3. **Monitor execution:**
   - Use Airflow UI to view DAG runs
   - Check task dependencies in Graph View
   - Monitor parallel execution in Tree View

## Task Execution

Each task performs a simple operation:
- **BashOperator tasks:** Execute echo command and sleep for 1 second
- **PythonOperator tasks:** Print execution message and simulate work

You can customize the task operations to perform actual work:
- Spark job submissions
- Data processing
- ETL operations
- API calls
- etc.

## Customization

To customize tasks for your use case:

1. **Replace BashOperator commands:**
   ```python
   BashOperator(
       task_id='your_task',
       bash_command='your-actual-command-here',
   )
   ```

2. **Replace PythonOperator callables:**
   ```python
   def your_task_function():
       # Your actual logic here
       pass
   
   PythonOperator(
       task_id='your_task',
       python_callable=your_task_function,
   )
   ```

3. **Add Spark jobs:**
   ```python
   from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
   
   SparkSubmitOperator(
       task_id='spark_job',
       application='/path/to/spark/app.py',
       conn_id='spark_default',
   )
   ```

## Notes

- All DAGs use `catchup=False` to prevent backfilling
- Tasks have retry configuration (1 retry with 5-minute delay)
- Random dependencies in some groups ensure varied execution patterns
- The project demonstrates real-world complexity with mixed patterns

## Verification

To verify the task count:
- Check Airflow UI: Each DAG should show the correct number of tasks
- Use Airflow CLI: `airflow dags list` to see all DAGs
- Graph View: Visualize the dependency structure

Total task count breakdown:
- DAG 1: 400 tasks
- DAG 2: 200 tasks
- DAG 3: 150 tasks
- DAG 4: 150 tasks
- DAG 5: 100 tasks
- **Total: 1000 tasks** ✓

