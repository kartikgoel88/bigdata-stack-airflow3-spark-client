"""
Complex Airflow DAG with 1000 jobs demonstrating various patterns:
- Direct dependencies (linear chains)
- Parallel execution
- Multiple dependencies (tasks depending on multiple tasks)
- Time-triggered schedules
- Jobs running every 7 days
- Jobs running 5 times a day
"""

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import random

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def generate_task_function(task_id):
    """Generate a Python function for a task"""
    def task_function():
        print(f"Executing task {task_id}")
        # Simulate some work
        import time
        time.sleep(random.uniform(0.1, 0.5))
        return f"Task {task_id} completed successfully"
    return task_function


# ============================================================================
# DAG 1: Daily scheduled DAG with complex dependencies (400 tasks)
# ============================================================================
with DAG(
    'complex_jobs_daily',
    default_args=default_args,
    description='Daily scheduled DAG with 400 jobs - complex dependencies',
    schedule_interval='0 0 * * *',  # Daily at midnight
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['daily', 'complex', '400-jobs'],
) as dag_daily:

    tasks = {}
    
    # Group 1: Linear dependency chain (50 tasks)
    # Tasks that directly depend on the previous one
    for i in range(50):
        task_id = f'daily_linear_{i:03d}'
        if i == 0:
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
        else:
            prev_task_id = f'daily_linear_{i-1:03d}'
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            tasks[prev_task_id] >> tasks[task_id]
    
    # Group 2: Parallel execution groups (100 tasks)
    # 10 groups of 10 parallel tasks each
    for group in range(10):
        group_tasks = []
        for task_num in range(10):
            task_id = f'daily_parallel_group{group}_task{task_num:02d}'
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            group_tasks.append(tasks[task_id])
        # All tasks in a group run in parallel (no dependencies between them)
    
    # Group 3: Multiple dependencies (100 tasks)
    # Tasks that depend on multiple previous tasks
    for i in range(100):
        task_id = f'daily_multi_dep_{i:03d}'
        if i < 5:
            # First 5 tasks have no dependencies
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
        else:
            # Each task depends on 2-3 previous tasks
            num_deps = random.randint(2, 3)
            dep_indices = random.sample(range(max(0, i-10), i), min(num_deps, i))
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            # Set dependencies
            for dep_idx in dep_indices:
                dep_task_id = f'daily_multi_dep_{dep_idx:03d}'
                if dep_task_id in tasks:
                    tasks[dep_task_id] >> tasks[task_id]
    
    # Group 4: Mixed pattern (150 tasks)
    # Combination of linear and parallel patterns
    for section in range(15):
        section_start = section * 10
        # First task in each section
        first_task_id = f'daily_mixed_section{section}_task00'
        tasks[first_task_id] = BashOperator(
            task_id=first_task_id,
            bash_command=f'echo "Executing {first_task_id}" && sleep 1',
        )
        
        # Remaining 9 tasks in parallel, all depending on first task
        for task_num in range(1, 10):
            task_id = f'daily_mixed_section{section}_task{task_num:02d}'
            tasks[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            tasks[first_task_id] >> tasks[task_id]


# ============================================================================
# DAG 2: Jobs running 5 times a day (200 tasks)
# ============================================================================
with DAG(
    'complex_jobs_5x_daily',
    default_args=default_args,
    description='DAG with 200 jobs running 5 times a day',
    schedule_interval='0 */5 * * *',  # Every 5 hours = 5 times a day (0, 5, 10, 15, 20)
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['5x-daily', '200-jobs'],
) as dag_5x_daily:

    tasks_5x = {}
    
    # Create 200 tasks with various dependency patterns
    for i in range(200):
        task_id = f'5x_daily_task_{i:03d}'
        
        if i == 0:
            # First task
            tasks_5x[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
        elif i < 20:
            # First 20 tasks form a linear chain
            prev_task_id = f'5x_daily_task_{i-1:03d}'
            tasks_5x[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            tasks_5x[prev_task_id] >> tasks_5x[task_id]
        elif i < 100:
            # Tasks 20-99: Parallel groups
            group = (i - 20) // 10
            task_num = (i - 20) % 10
            if task_num == 0:
                # First task in group depends on last task of previous group or linear chain
                tasks_5x[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                if group == 0:
                    # First group depends on last linear task
                    prev_task_id = '5x_daily_task_019'
                    if prev_task_id in tasks_5x:
                        tasks_5x[prev_task_id] >> tasks_5x[task_id]
                else:
                    # Subsequent groups depend on last task of previous group
                    prev_group_last = 20 + (group - 1) * 10 + 9
                    prev_task_id = f'5x_daily_task_{prev_group_last:03d}'
                    if prev_task_id in tasks_5x:
                        tasks_5x[prev_task_id] >> tasks_5x[task_id]
            else:
                # Parallel tasks in group - all depend on first task of group
                tasks_5x[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                group_first_id = f'5x_daily_task_{20 + group * 10:03d}'
                if group_first_id in tasks_5x:
                    tasks_5x[group_first_id] >> tasks_5x[task_id]
        else:
            # Tasks 100-199: Multiple dependencies
            num_deps = random.randint(1, 3)
            dep_indices = random.sample(range(max(0, i-15), i), min(num_deps, i))
            tasks_5x[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            for dep_idx in dep_indices:
                dep_task_id = f'5x_daily_task_{dep_idx:03d}'
                if dep_task_id in tasks_5x:
                    tasks_5x[dep_task_id] >> tasks_5x[task_id]


# ============================================================================
# DAG 3: Jobs running every 7 days (150 tasks)
# ============================================================================
with DAG(
    'complex_jobs_weekly',
    default_args=default_args,
    description='DAG with 150 jobs running every 7 days',
    schedule_interval='0 0 * * 0',  # Every Sunday at midnight (weekly)
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['weekly', '7-days', '150-jobs'],
) as dag_weekly:

    tasks_weekly = {}
    
    # Create 150 tasks
    for i in range(150):
        task_id = f'weekly_task_{i:03d}'
        
        if i == 0:
            tasks_weekly[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
        elif i < 30:
            # Linear chain for first 30 tasks
            prev_task_id = f'weekly_task_{i-1:03d}'
            tasks_weekly[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            tasks_weekly[prev_task_id] >> tasks_weekly[task_id]
        elif i < 90:
            # Parallel execution groups
            group = (i - 30) // 10
            task_num = (i - 30) % 10
            if task_num == 0:
                # First task in group
                tasks_weekly[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                if group == 0:
                    # First group depends on last linear task
                    prev_task_id = 'weekly_task_029'
                    if prev_task_id in tasks_weekly:
                        tasks_weekly[prev_task_id] >> tasks_weekly[task_id]
                else:
                    # Subsequent groups depend on last task of previous group
                    prev_group_last = 30 + (group - 1) * 10 + 9
                    prev_task_id = f'weekly_task_{prev_group_last:03d}'
                    if prev_task_id in tasks_weekly:
                        tasks_weekly[prev_task_id] >> tasks_weekly[task_id]
            else:
                # Parallel tasks in group - all depend on first task of group
                tasks_weekly[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                group_first_id = f'weekly_task_{30 + group * 10:03d}'
                if group_first_id in tasks_weekly:
                    tasks_weekly[group_first_id] >> tasks_weekly[task_id]
        else:
            # Multiple dependencies pattern
            num_deps = random.randint(2, 4)
            dep_indices = random.sample(range(max(0, i-20), i), min(num_deps, i))
            tasks_weekly[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            for dep_idx in dep_indices:
                dep_task_id = f'weekly_task_{dep_idx:03d}'
                if dep_task_id in tasks_weekly:
                    tasks_weekly[dep_task_id] >> tasks_weekly[task_id]


# ============================================================================
# DAG 4: Time-triggered jobs (manual/on-demand) (150 tasks)
# ============================================================================
with DAG(
    'complex_jobs_manual',
    default_args=default_args,
    description='DAG with 150 time-triggered/manual jobs',
    schedule_interval=None,  # Manual trigger only
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['manual', 'time-triggered', '150-jobs'],
) as dag_manual:

    tasks_manual = {}
    
    # Create 150 tasks with complex dependency graph
    for i in range(150):
        task_id = f'manual_task_{i:03d}'
        
        if i < 10:
            # First 10 tasks: starting points
            tasks_manual[task_id] = PythonOperator(
                task_id=task_id,
                python_callable=generate_task_function(task_id),
            )
        elif i < 50:
            # Tasks 10-49: Linear chains from starting points
            source_idx = (i - 10) % 10
            source_task_id = f'manual_task_{source_idx:03d}'
            tasks_manual[task_id] = PythonOperator(
                task_id=task_id,
                python_callable=generate_task_function(task_id),
            )
            if source_task_id in tasks_manual:
                tasks_manual[source_task_id] >> tasks_manual[task_id]
        elif i < 100:
            # Tasks 50-99: Parallel execution groups
            group = (i - 50) // 10
            group_start = 50 + group * 10
            task_num = (i - 50) % 10
            if task_num == 0:
                # First task in group depends on previous group's last task
                tasks_manual[task_id] = PythonOperator(
                    task_id=task_id,
                    python_callable=generate_task_function(task_id),
                )
                if group == 0:
                    # First group depends on last task from linear chains
                    prev_task_id = 'manual_task_049'
                    if prev_task_id in tasks_manual:
                        tasks_manual[prev_task_id] >> tasks_manual[task_id]
                else:
                    # Subsequent groups depend on last task of previous group
                    prev_group_last = 50 + (group - 1) * 10 + 9
                    prev_task_id = f'manual_task_{prev_group_last:03d}'
                    if prev_task_id in tasks_manual:
                        tasks_manual[prev_task_id] >> tasks_manual[task_id]
            else:
                # Parallel tasks in group - all depend on first task of group
                tasks_manual[task_id] = PythonOperator(
                    task_id=task_id,
                    python_callable=generate_task_function(task_id),
                )
                group_first_id = f'manual_task_{group_start:03d}'
                if group_first_id in tasks_manual:
                    tasks_manual[group_first_id] >> tasks_manual[task_id]
        else:
            # Tasks 100-149: Complex multiple dependencies
            num_deps = random.randint(2, 5)
            dep_indices = random.sample(range(max(0, i-25), i), min(num_deps, i))
            tasks_manual[task_id] = PythonOperator(
                task_id=task_id,
                python_callable=generate_task_function(task_id),
            )
            for dep_idx in dep_indices:
                dep_task_id = f'manual_task_{dep_idx:03d}'
                if dep_task_id in tasks_manual:
                    tasks_manual[dep_task_id] >> tasks_manual[task_id]


# ============================================================================
# DAG 5: Additional complex patterns (100 tasks)
# ============================================================================
with DAG(
    'complex_jobs_additional',
    default_args=default_args,
    description='Additional DAG with 100 jobs - mixed patterns',
    schedule_interval='0 */6 * * *',  # Every 6 hours
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['additional', 'mixed', '100-jobs'],
) as dag_additional:

    tasks_additional = {}
    
    # Create 100 tasks with mixed patterns
    for i in range(100):
        task_id = f'additional_task_{i:03d}'
        
        if i < 5:
            # Entry points
            tasks_additional[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
        elif i < 25:
            # Fan-out: each entry point spawns 4 tasks
            entry_point = (i - 5) // 4
            entry_task_id = f'additional_task_{entry_point:03d}'
            tasks_additional[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            if entry_task_id in tasks_additional:
                tasks_additional[entry_task_id] >> tasks_additional[task_id]
        elif i < 50:
            # Fan-in: multiple tasks converge
            num_sources = random.randint(2, 4)
            source_indices = random.sample(range(5, 25), min(num_sources, 20))
            tasks_additional[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            for src_idx in source_indices:
                src_task_id = f'additional_task_{src_idx:03d}'
                if src_task_id in tasks_additional:
                    tasks_additional[src_task_id] >> tasks_additional[task_id]
        elif i < 75:
            # Diamond pattern: split and merge
            if i == 50:
                # Split point
                tasks_additional[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                # Connect to previous task
                prev_task_id = f'additional_task_{i-1:03d}'
                if prev_task_id in tasks_additional:
                    tasks_additional[prev_task_id] >> tasks_additional[task_id]
            elif i < 65:
                # Parallel branch
                branch_start = 50
                tasks_additional[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                branch_start_id = f'additional_task_{branch_start:03d}'
                if branch_start_id in tasks_additional:
                    tasks_additional[branch_start_id] >> tasks_additional[task_id]
            else:
                # Merge point
                tasks_additional[task_id] = BashOperator(
                    task_id=task_id,
                    bash_command=f'echo "Executing {task_id}" && sleep 1',
                )
                # Connect to multiple previous tasks
                for prev_idx in range(60, 65):
                    prev_task_id = f'additional_task_{prev_idx:03d}'
                    if prev_task_id in tasks_additional:
                        tasks_additional[prev_task_id] >> tasks_additional[task_id]
        else:
            # Final tasks: complex dependencies
            num_deps = random.randint(1, 3)
            dep_indices = random.sample(range(max(0, i-20), i), min(num_deps, i))
            tasks_additional[task_id] = BashOperator(
                task_id=task_id,
                bash_command=f'echo "Executing {task_id}" && sleep 1',
            )
            for dep_idx in dep_indices:
                dep_task_id = f'additional_task_{dep_idx:03d}'
                if dep_task_id in tasks_additional:
                    tasks_additional[dep_task_id] >> tasks_additional[task_id]

