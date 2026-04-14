--  — Indexes: Setup
-- Creates the patient_visits table and populates 100,000 rows
-- Run this once before the other scripts
-- Oracle 23ai / freesql.com
-- ============================================================

-- Drop if exists (safe to re-run)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE patient_visits';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Create the table
CREATE TABLE patient_visits (
    visit_id     NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id   NUMBER         NOT NULL,
    site_id      NUMBER         NOT NULL,
    visit_date   DATE           NOT NULL,
    status       VARCHAR2(20)   NOT NULL,   -- 'scheduled', 'completed', 'cancelled'
    diagnosis    VARCHAR2(100),
    amount_usd   NUMBER(10,2)
);

-- Insert 100,000 rows using a single INSERT with CONNECT BY
-- patient_id: 1–10,000 (high cardinality — good for indexing)
-- site_id: 1–5 (low cardinality — bad for indexing)
-- status: 3 values (very low cardinality)
INSERT INTO patient_visits (patient_id, site_id, visit_date, status, diagnosis, amount_usd)
SELECT
    TRUNC(DBMS_RANDOM.VALUE(1, 10001))           AS patient_id,
    TRUNC(DBMS_RANDOM.VALUE(1, 6))               AS site_id,
    SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 730))  AS visit_date,
    CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
        WHEN 1 THEN 'scheduled'
        WHEN 2 THEN 'completed'
        ELSE        'cancelled'
    END                                          AS status,
    CASE TRUNC(DBMS_RANDOM.VALUE(1, 6))
        WHEN 1 THEN 'Hypertension'
        WHEN 2 THEN 'Diabetes'
        WHEN 3 THEN 'Routine checkup'
        WHEN 4 THEN 'Fracture'
        ELSE        'Respiratory infection'
    END                                          AS diagnosis,
    ROUND(DBMS_RANDOM.VALUE(50, 500), 2)         AS amount_usd
FROM dual
CONNECT BY LEVEL <= 50000;

COMMIT;

-- Collect stats so Oracle's optimizer has accurate information
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'PATIENT_VISITS',
        cascade => TRUE
    );
END;
/

-- Verify the data
SELECT COUNT(*) AS total_rows FROM patient_visits;
SELECT status, COUNT(*) AS cnt FROM patient_visits GROUP BY status ORDER BY status;
SELECT MIN(patient_id), MAX(patient_id), COUNT(DISTINCT patient_id) AS unique_patients
FROM patient_visits;

 

 

 

-- ============================================================
-- Lesson 03 — Indexes: Class Exercises
-- Work through these before looking at the hints
-- ============================================================

-- ============================================================
-- Exercise 1 — Find the slow query
--
-- Run this query. Look at the execution plan.
-- Is Oracle using an index? Should it?
-- ============================================================

SELECT * FROM patient_visits WHERE site_id = 3;

-- Questions:
-- a) What scan type do you see? Why? Full Table scan
-- b) site_id has values 1–5. Is this high or low cardinality? Low cardinality, only 5 distinct values across 100000 rows means each value appears ~20000 times
-- c) Would adding an index on site_id help? Why or why not? No, it wouldn't help, with only 5 distinct values each site_id matches ~20% of the table, which is still massive

-- ============================================================
-- Exercise 2 — Create an index and see if it helps
--
-- Create an index on visit_date.
-- Then run the range query below and check the plan.
-- ============================================================

-- Step 1: Create it
-- (write the CREATE INDEX statement here)
CREATE INDEX idx_pv_visit_date ON patient_visits(visit_date);

-- Step 2: Gather stats
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

-- Step 3: Run the range query and check the plan
SELECT * FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 7000 AND SYSDATE;

-- Questions:
-- a) Does Oracle use the index for this range? No, it performs a Full Table scan
-- b) Change the range to the last 7 days. Does the plan change? No, it performs the same plan
-- c) Change to the last 700 days. What happens? It still performs a full table scan because the table is not that big
-- d) Why does the range size affect whether Oracle uses the index? Because if there cardinality its low the amount of records would be big, so the query optimizer decides to perform a full table scan.


-- ============================================================
-- Exercise 3 — Composite index
--
-- You often query by both patient_id AND visit_date together:
--   WHERE patient_id = 1234 AND visit_date > SYSDATE - 90
--
-- Two options:
--   Option A: Two separate indexes (one per column)
--   Option B: One composite index (patient_id, visit_date)
--
-- Create the composite index and test the query.
-- ============================================================

CREATE INDEX idx_pv_patient_date ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

SELECT * FROM patient_visits
WHERE patient_id = 1234
  AND visit_date > SYSDATE - 90;

SELECT * FROM patient_visits
WHERE visit_date > SYSDATE - 90;

-- Questions:
-- a) Does the plan use the composite index? yes, patient_id is selective (~10 rows or so), and visit_date narrow it further
-- b) Now try querying ONLY on visit_date (no patient_id).
--    Does the composite index get used? Why not? No, querying only on visit_date skips the patient_id column, so oracle can't use the index, it would have to scan the entire index anyway
-- c) What's the rule about column order in composite indexes? oracle can only enter a composite index from the left. It can use: (patient_id alone and patient_id + visit_date) but it cant use visit_date alone


SELECT * FROM patient_visits WHERE patient_id = 1234;

-- Trailing column only (index cannot be used from the middle):
SELECT * FROM patient_visits WHERE visit_date > SYSDATE - 90;

-- ============================================================
-- Exercise 4 — Function that breaks an index
--
-- There IS an index on patient_id (from lesson 03).
-- Predict what happens when you wrap the column in a function.
-- ============================================================

-- This query CAN use the index:
SELECT * FROM patient_visits WHERE patient_id = 5432;
-- This one cannot — why?
SELECT * FROM patient_visits WHERE TO_CHAR(patient_id) = '5432';

-- Questions:
-- a) What scan type did the second query use? Full table scan
-- b) Why does wrapping a column in a function break index use? the index stores the raw patient_id values (numbers), when wrap it in to_char(), rracle has to evaluate that function for every row before it can compare
-- c) How would you rewrite the second query to allow index use? CREATE INDEX idx_pv_patient_char ON patient_visits(TO_CHAR(patient_id));


-- ============================================================
-- Exercise 5 — Discussion: real-world scenarios
--
-- For each scenario below, decide:
--   a) Would you add an index?
--   b) On which column(s)?
--   c) Any concerns?
-- ============================================================

-- Scenario A:
-- A reporting table gets loaded once per night (batch ETL).
-- During the day, analysts run SELECT queries by date range.
-- The table has 50 million rows.
-- → Index on date? Yes/No, why?
-- Yes, index on date
-- Batch loads happen at night so the index rebuild cost is acceptable
-- Concern: if date ranges are very wide (years), full scan may still win


-- Scenario B:
-- An OLTP orders table gets 10,000 inserts per minute.
-- Support staff look up orders by customer_id or order_status.
-- order_status has 4 values: pending, processing, shipped, cancelled.
-- → What indexes would you add?
-- Index on customer_id only
-- order_status has 4 values, low cardinality so a regular index wont help
-- Concern: 10,000 inserts/minute means every index adds write overhead


-- Scenario C:
-- A patient table has an email column (unique per patient).
-- There are 5 million patients.
-- The app frequently does: WHERE email = 'user@example.com'
-- → What kind of index would be best here?
-- Unique index on email
-- 5M rows, one exact match so every value is distinct (best use case for index)

-- ============================================================
-- Cleanup — remove indexes created in these exercises
-- ============================================================
DROP INDEX idx_pv_patient_date;
-- If you created an index on visit_date in Exercise 2, drop it here:
DROP INDEX idx_pv_visit_date;