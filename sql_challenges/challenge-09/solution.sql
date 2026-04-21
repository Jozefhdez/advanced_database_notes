-- Lesson 04: Setup
-- Create a simple accounts table for the transfer demo

DROP TABLE accounts PURGE;

CREATE TABLE accounts (
    account_id   NUMBER PRIMARY KEY,
    owner_name   VARCHAR2(50) NOT NULL,
    balance      NUMBER(10,2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts VALUES (1, 'Alice',  1000.00);
INSERT INTO accounts VALUES (2, 'Bob',     500.00);
INSERT INTO accounts VALUES (3, 'Charlie', 250.00);
COMMIT;

-- Verify starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Expected: Alice=1000, Bob=500, Charlie=250

-- Lesson 04: Class Exercises
-- Students: work through these in order. Don't skip the verify steps.

-- ============================================================
-- EXERCISE 1: Manual transaction (warm-up)
-- ============================================================
-- Transfer $50 from Charlie (3) to Alice (1) using BEGIN / COMMIT manually.
-- Before: verify balances. After COMMIT: verify again.

-- Your SQL here:
UPDATE accounts SET balance = balance - 50 WHERE account_id = 3;
UPDATE accounts SET balance = balance + 50 WHERE account_id = 1;
COMMIT;
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;


-- ============================================================
-- EXERCISE 2: Catch yourself with ROLLBACK
-- ============================================================
-- Start a transfer of $10,000 from Bob (2) to Charlie (3).
-- Before committing, check the balances. Does Bob have enough? No
-- Use ROLLBACK to undo. Verify balances restored.

-- Your SQL here:
UPDATE accounts SET balance = balance - 10000 WHERE account_id = 2;
UPDATE accounts SET balance = balance + 10000 WHERE account_id = 3;

SELECT balance FROM accounts WHERE account_id = 2; -- 500, not enough
ROLLBACK;
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
 

-- ============================================================
-- EXERCISE 3: SAVEPOINT checkpoint
-- ============================================================
-- You need to:
-- 1. Add $25 to Alice's balance
-- 2. Set a savepoint
-- 3. Deduct $25 from Charlie's balance (wrong account — you meant Bob)
-- 4. Rollback to savepoint
-- 5. Deduct $25 from Bob's balance instead
-- 6. Commit

-- Your SQL here:
UPDATE accounts SET balance = balance + 25 WHERE account_id = 1;
SAVEPOINT after_alice;
UPDATE accounts SET balance = balance - 25 WHERE account_id = 3;
ROLLBACK TO SAVEPOINT after_alice;
UPDATE accounts SET balance = balance - 25 WHERE account_id = 2;
COMMIT;

 

-- ============================================================
-- EXERCISE 4: Write your own stored procedure
-- ============================================================
-- Create a procedure called deposit_funds(p_account_id, p_amount)
-- It should:
-- 1. Validate that p_amount > 0 (raise error if not)
-- 2. Add p_amount to the account balance
-- 3. COMMIT on success
-- 4. ROLLBACK + re-raise on any error
-- Test it with: EXEC deposit_funds(3, 75);

-- Your SQL here:
CREATE OR REPLACE PROCEDURE deposit_funds(p_account_id IN NUMBER, p_amount IN NUMBER) AS
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Amount must be greater than zero');
    END IF;

    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_account_id;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

EXEC deposit_funds(3, 75);
 

-- ============================================================
-- EXERCISE 5: Discussion
-- ============================================================
-- Answer these in words (no SQL needed):

-- Q1: You're building a patient appointment booking system.
-- A booking requires:
--   a) Reserve the time slot
--   b) Create the appointment record
--   c) Send a confirmation notification
-- Which of these should be inside the transaction? Which should be outside? Why?
-- Steps a and b (reserve slot + create record) go inside the transaction. They are tightly coupled -- if either fails, both must roll back. Step c (send notification) goes outside. Notifications are I/O side effects you can't roll back, and they should only fire after the transaction commits successfully.

-- Q2: Your stored procedure calls COMMIT at the end.
-- A developer calls your procedure from inside their own larger transaction.
-- What problem does this create?
-- The inner COMMIT commits the outer transaction too. Oracle doesn't have nested transactions. Any work the caller did before calling your procedure gets committed prematurely, even if they weren't done yet.

-- Q3: You have a function called calculate_copay() and a procedure called post_payment().
-- A colleague wants to use calculate_copay() inside a SELECT statement.
-- Can they? Can they do the same with post_payment()? Why or why not?
-- calculate_copay() can be used in a SELECT because it's a function that returns a value and has no side effects. post_payment() cannot -- procedures don't return values and may contain DML with COMMIT/ROLLBACK, which Oracle doesn't allow inside a SQL query context. 

 

-- Lesson 04: Stored Procedures — Package the Logic in the Database

-- ============================================================
-- PART 1: Create the stored procedure
-- ============================================================

CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_account  IN  NUMBER,
    p_to_account    IN  NUMBER,
    p_amount        IN  NUMBER
) AS
    v_from_balance  NUMBER;
BEGIN
    -- Check sufficient funds before doing anything
    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_id = p_from_account;

    IF v_from_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient funds in account ' || p_from_account);
    END IF;

    -- Perform the transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

    -- Commit only if both succeed
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Transfer complete: $' || p_amount ||
                         ' from account ' || p_from_account ||
                         ' to account ' || p_to_account);
EXCEPTION
    WHEN OTHERS THEN
        -- Something went wrong — undo everything
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Transfer failed. All changes rolled back.');
        RAISE;  -- re-raise the error so the caller knows it failed
END;
/


-- ============================================================
-- PART 2: Call the procedure
-- ============================================================

-- Check starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;

-- Transfer $100 from Alice (1) to Bob (2)
SET SERVEROUTPUT ON;
EXEC transfer_funds(1, 2, 100);

-- Verify
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;


-- ============================================================
-- PART 3: What happens with insufficient funds?
-- ============================================================

-- Try to transfer more than Alice has
EXEC transfer_funds(1, 2, 99999);
-- Expected: error, ROLLBACK triggered, no change

SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Balances unchanged


-- ============================================================
-- PART 4: Stored procedure vs function — side by side
-- ============================================================

-- PROCEDURE: does something, can use COMMIT/ROLLBACK
-- Use when: inserting data, updating state, complex multi-step operations
-- Called with: EXEC or CALL — cannot use in SELECT

-- FUNCTION: returns a value, no COMMIT/ROLLBACK
-- Use when: calculations, data transformation
-- Can use in: SELECT, WHERE, HAVING

-- Example function (contrast)
CREATE OR REPLACE FUNCTION get_balance(p_account_id IN NUMBER) RETURN NUMBER AS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance FROM accounts WHERE account_id = p_account_id;
    RETURN v_balance;
END;
/

-- Function used directly in SELECT
SELECT account_id, owner_name, get_balance(account_id) AS current_balance
FROM accounts;

-- Procedure: CANNOT do this:
-- SELECT transfer_funds(1, 2, 100) FROM dual;  -- ERROR