-- Tables

CREATE TABLE PRODUCT (
    PRODUCT_ID NUMBER(10) PRIMARY KEY,
    PRODUCT_NAME VARCHAR2(30),
    PACKAGE_ID NUMBER(10),
    CURRENT_INVENTORY_COUNT NUMBER(5),
    STORE_COST NUMBER(10, 2),
    SALE_PRICE NUMBER(10, 2),
    LAST_UPDATE_DATE DATE,
    UPDATED_BY_USER VARCHAR2(30),
    PET_FLAG VARCHAR2(1),

    CONSTRAINT FK_PRODUCT_PACKAGE
        FOREIGN KEY (PACKAGE_ID)
        REFERENCES PRODUCT(PRODUCT_ID)
);

CREATE TABLE CUSTOMER (
    CUST_ID NUMBER(10) PRIMARY KEY,
    FIRSTNAME VARCHAR2(20),
    LASTNAME VARCHAR2(25),
    ADDRESS VARCHAR2(32),
    CITY VARCHAR2(20),
    STATE VARCHAR2(2),
    ZIP VARCHAR2(9)
);

CREATE TABLE CUSTOMER_SALE (
    SALES_ID NUMBER(10) PRIMARY KEY,
    CUST_ID NUMBER(10),
    TOTAL_ITEM_AMOUNT NUMBER(10, 2),
    TAX_AMOUNT NUMBER(10, 2),
    TOTAL_SALE_AMOUNT NUMBER(10, 2),
    SALES_DATE DATE,
    SHIPPING_HANDLING_FEE NUMBER(5, 2),

    CONSTRAINT FK_SALE_CUSTOMER
        FOREIGN KEY (CUST_ID)
        REFERENCES CUSTOMER(CUST_ID)
);

CREATE TABLE SALES_ITEM (
    SALES_ID NUMBER(10),
    PRODUCT_ID NUMBER(10),
    SALE_AMOUNT NUMBER(10, 2),

    CONSTRAINT PK_SALES_ITEM
        PRIMARY KEY (SALES_ID, PRODUCT_ID),

    CONSTRAINT FK_SALESITEM_SALE
        FOREIGN KEY (SALES_ID)
        REFERENCES CUSTOMER_SALE(SALES_ID),

    CONSTRAINT FK_SALESITEM_PRODUCT
        FOREIGN KEY (PRODUCT_ID)
        REFERENCES PRODUCT(PRODUCT_ID)
);

CREATE TABLE PET_CARE_LOG (
    PRODUCT_ID NUMBER(10),
    LOG_DATETIME DATE,
    CREATED_BY_USER VARCHAR2(30),
    LOG_TEXT VARCHAR2(500),
    LAST_UPDATE_DATETIME DATE,

    CONSTRAINT PK_PET_CARE_LOG
        PRIMARY KEY (PRODUCT_ID, LOG_DATETIME),

    CONSTRAINT FK_PETLOG_PRODUCT
        FOREIGN KEY (PRODUCT_ID)
        REFERENCES PRODUCT(PRODUCT_ID)
);

-- 1. Create a trigger that fires before inserting each row in the PET_CARE_LOG table. The trigger will assign the current data and time to the UPDATE_DATE column. It will also assign the current user to the UPDATED_BY_USER column. Use pseudocolumns to get the values that you need. Handle all errors in one general exception handler and send an error message using the RAISE_APPLICATION_ERROR procedure.

CREATE OR REPLACE TRIGGER trg_pet_care_log_bi
BEFORE INSERT ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    :NEW.LAST_UPDATE_DATETIME := SYSDATE;
    :NEW.CREATED_BY_USER := USER;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error in trg_pet_care_log_bi: ' || SQLERRM
        );
END;
/

-- 2. Create a trigger that fires before updating each row of the PET_CARE_LOG table. This trigger will look at the current user and compare it with the value in the UPDATED_BY_USER column. If the two are the same, the update proceeds. If they are different, the update raises an exception and fails. Handle any other database errors the same way you did in the insert trigger.

CREATE OR REPLACE TRIGGER trg_pet_care_log_bu
BEFORE UPDATE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    IF USER != :OLD.CREATED_BY_USER THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Update not allowed'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error in trg_pet_care_log_bu: ' || SQLERRM
        );
END;
/

-- 3. Create a trigger that fires before any row is deleted from the PET_CARE_LOG table. This trigger looks at the user who is deleting the row. If the user is ‘JOEMANAGER,’ the delete continues successfully. Otherwise, the delete fails and sends an error message. Handle any other database errors the same way you did in the insert trigger.

CREATE OR REPLACE TRIGGER trg_pet_care_log_bd
BEFORE DELETE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    IF USER != 'JOEMANAGER' THEN
        RAISE_APPLICATION_ERROR(
            -20004,
            'only JOEMANAGER can delete rows'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'Error in trg_pet_care_log_bd: ' || SQLERRM
        );
END;
/