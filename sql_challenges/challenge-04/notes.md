# Notes

Aggregation functions work great in certain cases, but some times we lose information due to them.

Window functions keep the rows, with a window function:

```sql
SELECT 
    name,
    salary,
    AVG(salary) OVER () AS avg_salary
FROM employees;
```

Now every employee still has their own row. The average is calculated across the whole table, but it’s attached to each row. Nothing disappears.

## Partition

```sql
AVG(salary) OVER (PARTITION BY department)
```

Calculates per department, keeps every row.

## Order

```sql
SUM(salary) OVER (ORDER BY hire_date)
```

Creates running totals.

## Frame control

``` sql 
SUM(salary) OVER (
  ORDER BY hire_date
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```
Defines exactly which rows are included in the window, I think of it like sliding window.


# ROW_NUMBER()
Gives a unique number to each row.
No ties.

```sql
ROW_NUMBER() OVER (ORDER BY salary DESC)
```

# RANK()
Same rank for ties.
Skips numbers after ties.
Example ranks: 1, 2, 2, 4.

# DENSE_RANK()
Same rank for ties.
No gaps.
Example ranks: 1, 2, 2, 3.