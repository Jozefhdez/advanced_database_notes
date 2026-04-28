# Notes

A schema is a collection of database objects owned by one user: tables, indexes, triggers, views, sequences, and PL/SQL units.

## Extracting DDL

```sql
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name) FROM user_tables;
```

Set transform params first to strip storage noise and hardcoded schema names:

```sql
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/
```

## Restore order

Tables -> FK constraints -> indexes -> procedures/functions -> triggers

## Verify

```sql
SELECT object_type, COUNT(*) FROM user_objects GROUP BY object_type;
SELECT object_name, status FROM user_objects WHERE status = 'INVALID';
```