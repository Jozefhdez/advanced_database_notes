# Notes

# Lesson Exercises

---

# Exercise 1 — Model Design (10 min)

## Scenario

Your task system needs a `comments` table.

Each comment belongs to:
- one task
- one user

---

## Task

Create a new Colab cell and write the `Comment` model.

### Required Fields

- `id`
- `task_id`
- `user_id`
- `content`
- `created_at`

---

## Questions

1. What relationships should `Comment` have? Comment should have a many-to-one to Task and many-to-one to User.
2. Should `Task` have a `comments` relationship? Yes, Task should have comments so you can do task.comments without querying manually.
3. What should happen to comments when a task is deleted? Comments should be deleted when the task is deleted

---

# Exercise 2 — Migration Creation (10 min)

## Scenario

You added the `Comment` model.

Now generate a migration programmatically.

---

## Task

Run:

```python
command.revision(
    alembic_cfg,
    autogenerate=True,
    message="add comments table"
)
```

---

## Then Inspect the Migration

```python
import glob

migration_files = sorted(
    glob.glob('/content/project/alembic/versions/*.py')
)

for f in migration_files:
    print(f)
```

---

## Open the Generated Migration

```python
latest = migration_files[-1]

with open(latest) as f:
    print(f.read())
```

---

## Questions

1. What does `upgrade()` do? upgrade() creates the comments table with all its columns and FK constraints.
2. What does `downgrade()` do? downgrade() drops the comments table entirely.
3. What happens if you downgrade this migration? The table and all comment rows get permanently deleted from the DB.

---

## Bonus

Add a CHECK constraint so `content != ''`

---

# Exercise 3 — CRUD Challenge (10 min)

## Scenario

Write a script that:

1. Creates a team called `"DevOps"`
2. Creates a user `"diana_ops"`
3. Creates 3 tasks with different priorities
4. Prints task count
5. Closes one task
6. Deletes the lowest priority task

---

## Requirements

- Use ORM only
- Use relationships
- Print output clearly

---

# Exercise 4 — Migration Rollback (5 min)

## Scenario

You added a bad column:
`estimated_hours`

The migration has already been applied.

---

## Task

Rollback the migration programmatically.

### Example

```python
command.downgrade(alembic_cfg, "-1")
```

---

## Questions

1. What happens to the column? The estimated_hours column gets dropped from the table schema
2. What happens to the data? Any data stored in that column is gone. There's no recovery unless you have a backup

---

# Exercise 5 — Concept Check (5 min)

Answer briefly:
---

1. **Why use ORM instead of raw SQL?**  
   ORM lets you work with Python objects instead of writing SQL strings

2. **Why use migrations?**  
   Migrations track schema changes as versioned scripts

3. **When would you rollback?**  
   When a migration caused a bug, broke something in prod, or was applied by mistake

4. **Difference between `add()` and `commit()`?**  
   `add()` stages an object to be saved. `commit()` actually writes it to the database

5. **Why are relationships useful?**  
   They let you navigate between objects directly (`task.assignee.full_name`) instead of writing JOIN queries manually

---