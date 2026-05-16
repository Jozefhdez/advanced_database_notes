-- ============================================================
-- Lesson 03: SQLAlchemy ORM + Alembic Migrations
-- File: 01_setup_schema.sql
-- Purpose: V1 Schema — teams, users, tasks
--
-- ============================================================

-- Drop tables if they exist (clean start)
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS teams;

-- TEAMS
CREATE TABLE teams (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR2(50)  NOT NULL UNIQUE,
    description VARCHAR2(200),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- USERS
CREATE TABLE users (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username    VARCHAR2(50)  NOT NULL UNIQUE,
    email       VARCHAR2(100) NOT NULL,
    full_name   VARCHAR2(100),
    team_id     NUMBER,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_team
        FOREIGN KEY (team_id) REFERENCES teams(id)
);

-- TASKS
CREATE TABLE tasks (
    id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        VARCHAR2(200) NOT NULL,
    description  VARCHAR2(1000),
    status       VARCHAR2(20)  DEFAULT 'open',
    assigned_to  NUMBER,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP,
    CONSTRAINT fk_tasks_user
        FOREIGN KEY (assigned_to) REFERENCES users(id)
);

-- SEED DATA

-- Teams
INSERT INTO teams (name, description) VALUES ('Engineering', 'Software development team');
INSERT INTO teams (name, description) VALUES ('Product', 'Product management team');

-- Users
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('alice_dev', 'alice@example.com', 'Alice Smith', 1);
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('bob_dev', 'bob@example.com', 'Bob Jones', 1);
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('carol_pm', 'carol@example.com', 'Carol White', 2);

-- Tasks
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Fix login bug', 'Users cannot log in with SSO', 'open', 1);
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Design new dashboard', 'Create mockups for analytics page', 'in_progress', 3);
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Update dependencies', 'Upgrade numpy and pandas', 'open', 2);

COMMIT;

-- VERIFY
SELECT 'Teams:' AS section, name FROM teams
UNION ALL
SELECT 'Users:' AS section, username FROM users
UNION ALL
SELECT 'Tasks:' AS section, title FROM tasks;