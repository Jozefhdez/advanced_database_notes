# Lesson 08: Exercise — Assignment History

A support ticketing system. Tickets get reassigned between agents. You need
to track who was assigned when the ticket was created vs when it was resolved.

---

## Step 1 — Source Tables (OLTP)

Create two tables:

**`tickets`** — current state of each ticket. Needs:
- ticket_id, title, status, priority, created_at, resolved_at, assigned_to

**`ticket_assignments`** — history of who was assigned when. Needs:
- assignment_id, ticket_id, assigned_to, assigned_by, valid_from, valid_to

```sql
CREATE TABLE tickets (
    ticket_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR2(200) NOT NULL,
    status VARCHAR2(20) DEFAULT 'open' NOT NULL,
    priority VARCHAR2(10) DEFAULT 'medium' NOT NULL,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    assigned_to NUMBER NOT NULL
);

CREATE TABLE ticket_assignments (
    assignment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id NUMBER NOT NULL REFERENCES tickets(ticket_id),
    assigned_to NUMBER NOT NULL,
    assigned_by NUMBER,
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP
);
```

---

## Step 2 — Sample Data

Insert at least 5 tickets. Make sure at least one gets reassigned (different
person in `ticket_assignments` than the current `assigned_to` in `tickets`).

```sql
INSERT INTO tickets (title, status, priority, assigned_to)
VALUES ('Login issue', 'open', 'high', 1);

INSERT INTO tickets (title, status, priority, assigned_to)
VALUES ('Payment failed', 'open', 'critical', 2);

INSERT INTO tickets (title, status, priority, assigned_to)
VALUES ('Password reset', 'resolved', 'medium', 3);

INSERT INTO tickets (title, status, priority, assigned_to)
VALUES ('Bug in dashboard', 'open', 'medium', 1);

INSERT INTO tickets (title, status, priority, assigned_to)
VALUES ('Slow report loading', 'resolved', 'high', 2);

COMMIT;
```

---

## Step 3 — Trigger

Write a trigger on `tickets` that:
- On INSERT or UPDATE of `assigned_to`, logs the change to `ticket_assignments`
- Closes the previous active assignment (sets its `valid_to`)
- Inserts a new row with `valid_from = now()` and `valid_to = NULL`

```sql
CREATE OR REPLACE TRIGGER trg_ticket_assignment_log
AFTER INSERT OR UPDATE OF assigned_to ON tickets
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            :NEW.created_at,
            NULL
        );

    ELSIF UPDATING THEN
        UPDATE ticket_assignments
        SET valid_to = SYSTIMESTAMP
        WHERE ticket_id = :OLD.ticket_id
          AND valid_to IS NULL;

        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            SYSTIMESTAMP,
            NULL
        );
    END IF;
END;
/
```

**Test it:** Reassign a ticket, then query `ticket_assignments` to confirm
both the old and new assignment are recorded.

---

## Step 4 — Data Warehouse Tables (Star Schema)

Create two tables:

**`dim_agent`** — agent details. Needs: agent_key, agent_name, team

**`fact_ticket_daily`** — daily counts per agent/status/priority. Needs:
date_key, agent_key, status, priority, tickets_created, tickets_resolved

```sql
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fact_ticket_daily'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dim_agent'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE TABLE dim_agent (
    agent_key NUMBER PRIMARY KEY,
    agent_name VARCHAR2(100) NOT NULL,
    team VARCHAR2(50) NOT NULL
);

CREATE TABLE fact_ticket_daily (
    date_key NUMBER NOT NULL,
    agent_key NUMBER NOT NULL REFERENCES dim_agent(agent_key),
    status VARCHAR2(20) NOT NULL,
    priority VARCHAR2(10) NOT NULL,
    tickets_created NUMBER DEFAULT 0,
    tickets_resolved NUMBER DEFAULT 0
);
```

---

## Step 5 — Populate dim_agent

Insert 3-4 agents with their teams.

```sql
INSERT INTO dim_agent VALUES (1, 'Alice Chen', 'Support');
INSERT INTO dim_agent VALUES (2, 'Bob Martinez', 'Billing');
INSERT INTO dim_agent VALUES (3, 'Carol Smith', 'Technical');
INSERT INTO dim_agent VALUES (4, 'Dave Kim', 'Support');

COMMIT;
```

---

## Step 6 — ETL Logic (Colab)

In your Colab notebook, write pandas code that:
1. Extracts `tickets` and `ticket_assignments` from FreeSQL
2. For each ticket, finds who was assigned at `created_at` using:
   `valid_from <= created_at AND (valid_to IS NULL OR valid_to > created_at)`
3. Same for `resolved_at`
4. Groups by date, agent, status, priority and counts
5. Inserts into `fact_ticket_daily`

```python
import pandas as pd
import oracledb

conn = oracledb.connect(
    user="",
    password="",
    dsn=""
)

tickets = pd.read_sql("""
    SELECT ticket_id, title, status, priority, created_at, resolved_at, assigned_to
    FROM tickets
""", conn)

assignments = pd.read_sql("""
    SELECT ticket_id, assigned_to, valid_from, valid_to
    FROM ticket_assignments
""", conn)

def find_agent(ticket_id, event_time):
    if pd.isna(event_time):
        return None

    rows = assignments[
        (assignments["TICKET_ID"] == ticket_id) &
        (assignments["VALID_FROM"] <= event_time) &
        (
            assignments["VALID_TO"].isna() |
            (assignments["VALID_TO"] > event_time)
        )
    ]

    if rows.empty:
        return None

    return rows.iloc[0]["ASSIGNED_TO"]

created_rows = []

for _, row in tickets.iterrows():
    created_agent = find_agent(row["TICKET_ID"], row["CREATED_AT"])

    created_rows.append({
        "date_key": int(row["CREATED_AT"].strftime("%Y%m%d")),
        "agent_key": created_agent,
        "status": row["STATUS"],
        "priority": row["PRIORITY"],
        "tickets_created": 1,
        "tickets_resolved": 0
    })

resolved_rows = []

for _, row in tickets.dropna(subset=["RESOLVED_AT"]).iterrows():
    resolved_agent = find_agent(row["TICKET_ID"], row["RESOLVED_AT"])

    resolved_rows.append({
        "date_key": int(row["RESOLVED_AT"].strftime("%Y%m%d")),
        "agent_key": resolved_agent,
        "status": row["STATUS"],
        "priority": row["PRIORITY"],
        "tickets_created": 0,
        "tickets_resolved": 1
    })

fact = pd.DataFrame(created_rows + resolved_rows)

fact = fact.groupby(
    ["date_key", "agent_key", "status", "priority"],
    as_index=False
).sum()

cursor = conn.cursor()

cursor.execute("DELETE FROM fact_ticket_daily")

for _, row in fact.iterrows():
    cursor.execute("""
        INSERT INTO fact_ticket_daily (
            date_key,
            agent_key,
            status,
            priority,
            tickets_created,
            tickets_resolved
        )
        VALUES (:1, :2, :3, :4, :5, :6)
    """, (
        int(row["date_key"]),
        int(row["agent_key"]),
        row["status"],
        row["priority"],
        int(row["tickets_created"]),
        int(row["tickets_resolved"])
    ))

conn.commit()
cursor.close()
conn.close()
```

---

## Step 7 — Verify

Write a query joining `fact_ticket_daily` and `dim_agent` to show tickets
created and resolved per agent per day. The reassigned ticket should show
the original agent for creation and the new agent for resolution.

```sql
SELECT
    f.date_key,
    a.agent_name,
    a.team,
    f.status,
    f.priority,
    f.tickets_created,
    f.tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent a
    ON a.agent_key = f.agent_key
ORDER BY
    f.date_key,
    a.agent_name,
    f.status,
    f.priority;
```