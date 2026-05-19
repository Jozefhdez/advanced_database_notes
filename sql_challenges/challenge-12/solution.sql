-- Exercise
-- Add a new chart: Tasks completed per day (line chart). Hint: Filter WHERE status = 'completed' and group by TRUNC(completed_at).

-- query = """
-- SELECT TRUNC(completed_at) AS completion_date, COUNT(*) AS tasks_completed
-- FROM   tasks
-- WHERE  status = 'completed'
--   AND  completed_at IS NOT NULL
-- GROUP  BY TRUNC(completed_at)
-- ORDER  BY completion_date
--"""

-- df_completed = pd.read_sql(query, engine)
-- df_completed['completion_date'] = pd.to_datetime(df_completed['completion_date'])

-- fig = px.line(
--     df_completed,
--     x='completion_date',
--     y='tasks_completed',
--     title='Tasks Completed per Day',
--     markers=True
)

-- fig.update_xaxes(title_text='Date')
-- fig.update_yaxes(title_text='Tasks Completed', dtick=1)
-- fig.show()


-- ============================================================
-- Lesson 07: KPI Dashboards — Class Exercises
-- File: 06_exercises.sql
-- ============================================================

-- ============================================================
-- PART A: The KPI Contract (Conceptual)
-- ============================================================

-- ============================================================
-- EXERCISE 1: Define "Team Velocity"
-- ============================================================

-- 1. Business question: Which team completes the most work per person per day?
-- 2. Definition: completed tasks / team members / 19 days (May 1-19).
--    Joins: teams -> users -> tasks. LEFT JOIN so zero-task teams appear.
-- 3. Edge cases: teams with no completions return 0, not NULL (NULLIF on divisor).
-- 4. Unit: tasks per person per day (decimal).
-- 5. Misleading if: all tasks are weighted equally regardless of complexity.
--    Without story points, a trivial fix counts the same as a major feature.
--    Pro of per-person normalization: fair comparison across team sizes.
--    Con: ignores that some members may be part-time or on leave.

WITH velocity AS (
    SELECT
        t.name AS team_name,
        COUNT(DISTINCT u.id) AS member_count,
        COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) AS completed_tasks,
        ROUND(
            COUNT(CASE WHEN ts.status = 'completed' THEN 1 END)
            / NULLIF(COUNT(DISTINCT u.id), 0)
            / 19,
            3
        ) AS velocity_per_person_per_day
    FROM teams t
    LEFT JOIN users u ON u.team_id = t.id
    LEFT JOIN tasks ts ON ts.assigned_to = u.id
    GROUP BY t.id, t.name
),
avg_velocity AS (
    SELECT AVG(velocity_per_person_per_day) AS overall_avg FROM velocity
)
SELECT
    v.team_name,
    v.member_count,
    v.completed_tasks,
    v.velocity_per_person_per_day,
    CASE
        WHEN v.velocity_per_person_per_day < a.overall_avg THEN 'Below Average'
        ELSE 'At or Above Average'
    END AS velocity_flag
FROM   velocity v
CROSS  JOIN avg_velocity a
ORDER  BY v.velocity_per_person_per_day DESC;


-- ============================================================
-- EXERCISE 2: Define "On-Time Delivery Rate"
-- ============================================================

-- 1. Business question: What percentage of completed tasks were finished on time?
-- 2. Definition: on-time = TRUNC(completed_at) <= due_date.
--    Scope: only completed tasks with both completed_at and due_date set.
--    Tasks with no due_date are excluded; they cannot be measured.
-- 3. Edge cases: completed at 23:59 on due_date = on-time (TRUNC strips time).
--    Completed at 00:01 next day = late. NULL due_date rows are filtered out.
-- 4. Unit: percentage (0-100) and average lateness in hours for late tasks.
-- 5. Misleading if: teams set loose due dates on purpose to inflate the rate.

SELECT
    priority,
    COUNT(*) AS total_completed,
    COUNT(CASE WHEN TRUNC(completed_at) <= due_date THEN 1 END) AS on_time_count,
    ROUND(
        COUNT(CASE WHEN TRUNC(completed_at) <= due_date THEN 1 END)
        * 100.0 / NULLIF(COUNT(*), 0),
        1
    ) AS on_time_rate_pct,
    ROUND(AVG(
        CASE WHEN TRUNC(completed_at) > due_date THEN
            EXTRACT(DAY  FROM (completed_at - CAST(due_date AS TIMESTAMP))) * 24 +
            EXTRACT(HOUR FROM (completed_at - CAST(due_date AS TIMESTAMP)))
        END
    ), 1) AS avg_lateness_hours
FROM   tasks
WHERE  status = 'completed'
  AND  completed_at IS NOT NULL
  AND  due_date IS NOT NULL
GROUP  BY priority
ORDER  BY CASE priority
              WHEN 'critical' THEN 1
              WHEN 'high' THEN 2
              WHEN 'medium' THEN 3
              WHEN 'low' THEN 4
          END;


-- ============================================================
-- PART B: Improve the Class KPIs
-- ============================================================


-- ============================================================
-- EXERCISE 3: Improve "Tasks per Team" (KPI 2 from class)
-- ============================================================

SELECT
    t.name AS team_name,
    COUNT(ts.id) AS total_tasks,
    COUNT(CASE WHEN ts.status IN ('open','in_progress','blocked') THEN 1 END) AS active_tasks,
    ROUND(
        COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(CASE WHEN ts.status != 'cancelled' THEN 1 END), 0),
        1
    ) AS completion_rate_pct,
    CASE
        WHEN COUNT(CASE WHEN ts.status IN ('open','in_progress','blocked') THEN 1 END) > 10
            THEN 'Overloaded'
        WHEN COUNT(CASE WHEN ts.status IN ('open','in_progress','blocked') THEN 1 END) >= 5
            THEN 'Healthy'
        ELSE 'Underutilized'
    END AS health_score
FROM teams t
LEFT JOIN users u ON u.team_id = t.id
LEFT JOIN tasks ts ON ts.assigned_to = u.id
GROUP BY t.id, t.name
ORDER BY active_tasks DESC;


-- ============================================================
-- EXERCISE 4: Improve "Average Resolution Time" (KPI 5 from class)
-- ============================================================

-- Edge case: if sample_size = 1, the average equals that single data point.
-- The warning column flags it so readers know not to treat it as a trend.

SELECT
    priority,
    COUNT(*) AS sample_size,
    ROUND(AVG(
        EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
        EXTRACT(HOUR FROM (completed_at - created_at)) +
        EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
    ), 1) AS avg_resolution_hours,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY
        EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
        EXTRACT(HOUR FROM (completed_at - created_at)) +
        EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
    ), 1) AS median_resolution_hours,
    ROUND(MIN(
        EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
        EXTRACT(HOUR FROM (completed_at - created_at)) +
        EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
    ), 1) AS fastest_hours,
    ROUND(MAX(
        EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
        EXTRACT(HOUR FROM (completed_at - created_at)) +
        EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
    ), 1) AS slowest_hours,
    CASE priority
        WHEN 'critical' THEN 24
        WHEN 'high' THEN 72
        WHEN 'medium'THEN 168
        WHEN 'low' THEN 336
    END AS sla_target_hours,
    CASE
        WHEN ROUND(AVG(
            EXTRACT(DAY    FROM (completed_at - created_at)) * 24 +
            EXTRACT(HOUR   FROM (completed_at - created_at)) +
            EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
        ), 1) <= CASE priority
                     WHEN 'critical' THEN 24
                     WHEN 'high' THEN 72
                     WHEN 'medium' THEN 168
                     WHEN 'low' THEN 336
                 END
        THEN 'MET'
        ELSE 'MISSED'
    END AS sla_status,
    CASE WHEN COUNT(*) = 1 THEN 'Low confidence (n=1)' ELSE NULL END AS warning
FROM tasks
WHERE status = 'completed'
  AND completed_at IS NOT NULL
GROUP BY priority
ORDER BY CASE priority
              WHEN 'critical' THEN 1
              WHEN 'high' THEN 2
              WHEN 'medium' THEN 3
              WHEN 'low' THEN 4
          END;


-- ============================================================
-- EXERCISE 5: Improve "Overdue Tasks" (KPI 7 from class)
-- ============================================================

-- Part 1: detailed report
SELECT
    ts.title,
    u.full_name AS assignee,
    t.name AS team,
    ts.priority,
    ts.due_date,
    TRUNC(SYSDATE) - ts.due_date AS days_overdue,
    CASE
        WHEN ts.priority = 'critical' THEN 'CRITICAL'
        WHEN ts.priority = 'high' AND TRUNC(SYSDATE)-ts.due_date > 2 THEN 'HIGH'
        WHEN ts.priority = 'medium' AND TRUNC(SYSDATE)-ts.due_date > 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity
FROM tasks ts
JOIN users u ON u.id = ts.assigned_to
JOIN teams t ON t.id = u.team_id
WHERE ts.due_date  < TRUNC(SYSDATE)
  AND ts.status   NOT IN ('completed', 'cancelled')
  AND ts.due_date IS NOT NULL
ORDER BY
    CASE
        WHEN ts.priority = 'critical' THEN 1
        WHEN ts.priority = 'high'   AND TRUNC(SYSDATE)-ts.due_date > 2 THEN 2
        WHEN ts.priority = 'medium' AND TRUNC(SYSDATE)-ts.due_date > 5 THEN 3
        ELSE 4
    END,
    TRUNC(SYSDATE) - ts.due_date DESC;

-- Part 2: summary by severity using ROLLUP
SELECT
    CASE
        WHEN ts.priority = 'critical' THEN 'CRITICAL'
        WHEN ts.priority = 'high'   AND TRUNC(SYSDATE)-ts.due_date > 2 THEN 'HIGH'
        WHEN ts.priority = 'medium' AND TRUNC(SYSDATE)-ts.due_date > 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    COUNT(*) AS overdue_count,
    ROUND(AVG(TRUNC(SYSDATE) - ts.due_date), 1) AS avg_days_overdue
FROM tasks ts
WHERE ts.due_date < TRUNC(SYSDATE)
  AND ts.status NOT IN ('completed', 'cancelled')
  AND ts.due_date IS NOT NULL
GROUP  BY ROLLUP(
    CASE
        WHEN ts.priority = 'critical' THEN 'CRITICAL'
        WHEN ts.priority = 'high'   AND TRUNC(SYSDATE)-ts.due_date > 2 THEN 'HIGH'
        WHEN ts.priority = 'medium' AND TRUNC(SYSDATE)-ts.due_date > 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END
);


-- ============================================================
-- PART C: The "Bad KPI" Challenge
-- ============================================================

-- ============================================================
-- EXERCISE 6: Fix the "Productivity Score"
-- ============================================================

-- PROBLEM: It counts every task assigned to a user regardless of status.
-- Someone with 10 open unfinished tasks scores the same as someone who
-- completed 10. It rewards being assigned work, not delivering it.
-- It also ignores priority -- closing a critical bug should count more
-- than closing a low-priority docs ticket.
-- INNER JOIN hides users with no assignments entirely.

SELECT
    u.full_name,
    COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) AS completed_tasks,
    SUM(CASE
        WHEN ts.status = 'completed' AND ts.priority = 'critical' THEN 4
        WHEN ts.status = 'completed' AND ts.priority = 'high'     THEN 3
        WHEN ts.status = 'completed' AND ts.priority = 'medium'   THEN 2
        WHEN ts.status = 'completed' AND ts.priority = 'low'      THEN 1
        ELSE 0
    END) AS weighted_score,
    ROUND(
        SUM(CASE
            WHEN ts.status = 'completed' AND ts.priority = 'critical' THEN 4
            WHEN ts.status = 'completed' AND ts.priority = 'high' THEN 3
            WHEN ts.status = 'completed' AND ts.priority = 'medium' THEN 2
            WHEN ts.status = 'completed' AND ts.priority = 'low' THEN 1
            ELSE 0
        END)
        / NULLIF(TRUNC(SYSDATE) - TRUNC(MIN(ts.created_at)), 0),
        3
    ) AS weighted_score_per_day
FROM users u
LEFT JOIN tasks ts ON ts.assigned_to = u.id
GROUP BY u.id, u.full_name
ORDER BY weighted_score_per_day DESC NULLS LAST;


-- ============================================================
-- EXERCISE 7: Fix the "Team Efficiency"
-- ============================================================

-- PROBLEM: AVG(ts.id) averages the primary key integer, which is meaningless.
-- Task ID 50 is not worth more than task ID 5 -- it's just the insertion order.
-- INNER JOIN also hides teams that have no tasks assigned at all.

SELECT
    t.name AS team_name,
    COUNT(ts.id) AS total_tasks,
    COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) AS completed_tasks,
    ROUND(
        COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(ts.id), 0),
        1
    ) AS completion_ratio_pct
FROM teams t
LEFT JOIN users u ON u.team_id = t.id
LEFT JOIN tasks ts ON ts.assigned_to = u.id
GROUP BY t.id, t.name
ORDER BY completion_ratio_pct DESC NULLS LAST;


-- ============================================================
-- EXERCISE 8: Fix the "Urgency Index"
-- ============================================================

-- PROBLEM: priority is VARCHAR2 -- you cannot multiply a string by 10.
-- DUE_DATE is a DATE -- you cannot add it raw to a number like that.
-- Oracle throws ORA-01722 (invalid number) at runtime.
-- Even if it didn't, the result would be meaningless garbage.

SELECT
    title,
    priority,
    due_date,
    TRUNC(due_date) - TRUNC(SYSDATE) AS days_until_due,
    CASE priority
        WHEN 'critical' THEN 4
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 1
        ELSE 0
    END AS priority_weight,
    CASE priority
        WHEN 'critical' THEN 4
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 1
        ELSE 0
    END + NVL(TRUNC(due_date) - TRUNC(SYSDATE), 0) AS urgency_index
FROM tasks
WHERE status NOT IN ('completed', 'cancelled')
ORDER BY urgency_index DESC;