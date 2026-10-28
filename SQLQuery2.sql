--DAY 2 — JOINs and Relationship Reasoning
--assigment A
--01.
SELECT c.CustomerId,c.FullName,a.AccountId,a.AccountType
FROM Customers c
INNER JOIN Accounts a ON a.CustomerId = c.CustomerId;

--02.
SELECT c.CustomerId, c.FullName, a.AccountId, a.AccountType
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId;

--03.
-- Condition in ON
SELECT c.CustomerId, c.FullName, a.AccountId, a.Status
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId AND a.Status = 'Active';
-- Condition in WHERE
SELECT c.CustomerId, c.FullName, a.AccountId, a.Status
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId
WHERE a.Status = 'Active';

--04.
SELECT c.CustomerId, c.FullName
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId
WHERE a.AccountId IS NULL;

--05.
SELECT a.AccountId, a.AccountType, a.Balance, c.FullName, c.Email
FROM Accounts a
INNER JOIN Customers c ON c.CustomerId = a.CustomerId;

--06.
SELECT c.CustomerId, c.FullName, COUNT(a.AccountId) AS AccountCount

FROM Customers c

LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId

GROUP BY c.CustomerId, c.FullName;


-- =========================================================

--  Assignment B


USE BankingLab;

GO

-- ---------------- SETUP (safe to re-run) ----------------

DROP TABLE IF EXISTS SettlementTransactions;

DROP TABLE IF EXISTS CoreTransactions;

DROP TABLE IF EXISTS Products;

DROP TABLE IF EXISTS Branches;

DROP TABLE IF EXISTS Employees;

GO

-- B1 tables

CREATE TABLE CoreTransactions

(

    CoreId      INT IDENTITY(1,1) PRIMARY KEY,

    ReferenceNo VARCHAR(20)   NOT NULL,

    Amount      DECIMAL(18,2) NOT NULL

);

CREATE TABLE SettlementTransactions

(

    SettlementId INT IDENTITY(1,1) PRIMARY KEY,

    ReferenceNo  VARCHAR(20)   NOT NULL,   -- deliberately NOT unique (see B2)

    Amount       DECIMAL(18,2) NOT NULL

);

INSERT INTO CoreTransactions (ReferenceNo, Amount) VALUES

('REF001', 100.00), ('REF002', 200.00), ('REF003', 300.00), ('REF004', 400.00);

INSERT INTO SettlementTransactions (ReferenceNo, Amount) VALUES

('REF001', 100.00), ('REF002', 250.00), ('REF005', 500.00);

-- B3 tables

CREATE TABLE Branches

(

    BranchId   INT PRIMARY KEY,

    BranchName VARCHAR(50) NOT NULL

);

CREATE TABLE Products

(

    ProductId   INT PRIMARY KEY,

    ProductName VARCHAR(50) NOT NULL

);

INSERT INTO Branches (BranchId, BranchName) VALUES

(1, 'Central'), (2, 'North'), (3, 'South');

INSERT INTO Products (ProductId, ProductName) VALUES

(1, 'Savings Plus'), (2, 'Home Loan'), (3, 'Fixed Deposit'), (4, 'Credit Card');

-- B4 table (ManagerId points at another row of the SAME table)

CREATE TABLE Employees

(

    EmployeeId INT PRIMARY KEY,

    FullName   VARCHAR(100) NOT NULL,

    ManagerId  INT NULL,

    CONSTRAINT FK_Employees_Manager

        FOREIGN KEY (ManagerId) REFERENCES Employees(EmployeeId)

);

INSERT INTO Employees (EmployeeId, FullName, ManagerId) VALUES

(1, 'Ravi Kumar', NULL),

(2, 'Meena Rao',  1),

(3, 'Arun Das',   1),

(4, 'Sita Nair',  2),

(5, 'Kiran Shah', 2);

GO

-- Check: expect Branches, CoreTransactions, Employees, Products, SettlementTransactions

SELECT name FROM sys.tables ORDER BY name;


-- ---------------- B1: FULL OUTER JOIN reconciliation ----------------

SELECT

    COALESCE(c.ReferenceNo, s.ReferenceNo) AS ReferenceNo,

    c.Amount AS CoreAmount,

    s.Amount AS SettlementAmount,

    CASE

        WHEN s.ReferenceNo IS NULL THEN 'Core Only'

        WHEN c.ReferenceNo IS NULL THEN 'Settlement Only'

        WHEN c.Amount <> s.Amount  THEN 'Amount Mismatch'

        ELSE 'Matched'

    END AS ReconStatus

FROM CoreTransactions c

FULL OUTER JOIN SettlementTransactions s ON s.ReferenceNo = c.ReferenceNo;




-- ---------------- B2: duplicate reference (run the INSERT ONCE) ----------------

INSERT INTO SettlementTransactions (ReferenceNo, Amount) VALUES ('REF001', 100.00);

-- Now re-run the B1 query: 6 rows, REF001 appears twice.

-- Key-uniqueness check

SELECT ReferenceNo, COUNT(*) AS Occurrences

FROM SettlementTransactions

GROUP BY ReferenceNo

HAVING COUNT(*) > 1;



-- Inflation demo

SELECT SUM(c.Amount) AS CoreTotalViaJoin

FROM CoreTransactions c

INNER JOIN SettlementTransactions s ON s.ReferenceNo = c.ReferenceNo;

-- ---------------- B3: CROSS JOIN ----------------



SELECT b.BranchName, p.ProductName

FROM Branches b

CROSS JOIN Products p;


-- ---------------- B4: SELF JOIN ----------------

SELECT e.EmployeeId, e.FullName AS Employee, m.FullName AS Manager

FROM Employees e

LEFT JOIN Employees m ON m.EmployeeId = e.ManagerId;

-- Expected: 5 rows (Ravi Kumar has Manager = NULL)


-- ---------------- B5 (explanation) ----------------

-- CROSS JOIN returns rows(A) x rows(B). A forgotten join condition silently

-- turns a normal join into one: 1,000,000 x 1,000,000 = 1 trillion rows.

-- Reports crash or crawl, and any totals built on it are wildly inflated.
 

 USE BankingLab;

GO
--- assigment C


SELECT (SELECT COUNT(*) FROM Customers)    AS Customers,

       (SELECT COUNT(*) FROM Accounts)     AS Accounts,

       (SELECT COUNT(*) FROM Transactions) AS Transactions;


-- ---------------- STEP 1: SETUP (safe to re-run) ----------------

DROP TABLE IF EXISTS Fees;

GO

-- Two customers with no accounts (also needed by Assignment A)

DELETE FROM Customers WHERE CustomerId IN (1009, 1010);

INSERT INTO Customers (CustomerId, FullName, Email, CreatedDate) VALUES

(1009, 'Isha Patel', 'isha.patel@mail.com', '2024-09-10'),

(1010, 'Jonas Reed', 'jonas.reed@mail.com', '2024-10-01');

-- C2 table: several fees per account (account 2001 has 2, account 2003 has 3)

CREATE TABLE Fees

(

    FeeId     INT PRIMARY KEY,

    AccountId INT NOT NULL,

    FeeType   VARCHAR(30)   NOT NULL,

    FeeAmount DECIMAL(18,2) NOT NULL,

    CONSTRAINT FK_Fees_Accounts

        FOREIGN KEY (AccountId) REFERENCES Accounts(AccountId)

);

INSERT INTO Fees (FeeId, AccountId, FeeType, FeeAmount) VALUES

(4001, 2001, 'Maintenance', 10.00),

(4002, 2001, 'SMS Alert',   15.00),

(4003, 2003, 'Maintenance',  5.00),

(4004, 2003, 'SMS Alert',    5.00),

(4005, 2003, 'Card',         5.00);

GO



SELECT (SELECT COUNT(*) FROM Customers) AS Customers,

       (SELECT COUNT(*) FROM Fees)      AS Fees;


-- ---------------- C1: total transaction amount by customer ----------------

-- Grain: one row per customer

SELECT c.CustomerId, c.FullName, COALESCE(SUM(t.Amount), 0) AS TotalTransactionAmount

FROM Customers c

LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId

LEFT JOIN Transactions t ON t.AccountId  = a.AccountId

GROUP BY c.CustomerId, c.FullName;


-- ---------------- C2: adding Fees INFLATES the totals ----------------

SELECT c.CustomerId, c.FullName, COALESCE(SUM(t.Amount), 0) AS InflatedTotal

FROM Customers c

LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId

LEFT JOIN Transactions t ON t.AccountId  = a.AccountId

LEFT JOIN Fees f         ON f.AccountId  = a.AccountId

GROUP BY c.CustomerId, c.FullName;


-- ---------------- C3: row-count diagnostic after each JOIN stage ----------------

-- Stage 0: Customers only

SELECT COUNT(*) AS Stage0_Rows

FROM Customers c;                                                   

-- Stage 1: + Accounts

SELECT COUNT(*) AS Stage1_Rows

FROM Customers c

LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId;                 -- 16

-- Stage 2: + Transactions  (Stage2_TxnRows must equal the real 15 transactions)

SELECT COUNT(*) AS Stage2_Rows, COUNT(t.TransactionId) AS Stage2_TxnRows

FROM Customers c

LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId

LEFT JOIN Transactions t ON t.AccountId  = a.AccountId;              -- 21 and 15

-- Stage 3: + Fees

SELECT COUNT(*) AS Stage3_Rows, COUNT(t.TransactionId) AS Stage3_TxnRows

FROM Customers c

LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId

LEFT JOIN Transactions t ON t.AccountId  = a.AccountId

LEFT JOIN Fees f         ON f.AccountId  = a.AccountId;              -- 28 and 22

-- ---------------- C4: aggregate-first solution ----------------

-- Aggregate Transactions and Fees by AccountId SEPARATELY, then join to Accounts.

-- (The two inner SELECTs are derived tables. If your trainer disallows them on

-- Day 2, run the two aggregations as separate queries instead.)

SELECT

    c.CustomerId,

    c.FullName,

    COALESCE(SUM(ta.TotalTxn), 0)  AS TotalTransactions,

    COALESCE(SUM(fa.TotalFees), 0) AS TotalFees

FROM Customers c

LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId

LEFT JOIN (SELECT AccountId, SUM(Amount) AS TotalTxn

           FROM Transactions GROUP BY AccountId) ta ON ta.AccountId = a.AccountId

LEFT JOIN (SELECT AccountId, SUM(FeeAmount) AS TotalFees

           FROM Fees GROUP BY AccountId) fa ON fa.AccountId = a.AccountId

GROUP BY c.CustomerId, c.FullName;

SELECT SUM(Amount) AS TrueGrandTotal FROM Transactions;             

-- ---------------- C5: why DISTINCT is not a reliable fix ----------------

SELECT SUM(Amount) AS RealTotal, SUM(DISTINCT Amount) AS DistinctTotal

FROM Transactions;

-- Expected: 209825.00 vs 204625.00

-- DISTINCT compares VALUES, not rows. Two genuine transactions of 5000 (and two of

-- 200) collapse into one, so real money disappears. Meanwhile join duplicates that

-- differ in any other way are not removed. The fix is controlling the grain

-- (aggregate first), not hiding duplicates.


-- ---------------- C6: JOIN decision memo ----------------

-- Requirement                              | JOIN        | Why

-- All customers                            | LEFT JOIN   | Customers is the preserved side

-- Only matched customers (have accounts)   | INNER JOIN  | Only rows that match on both sides

-- All records from both recon sources      | FULL OUTER  | Keep unmatched rows from BOTH sides

-- Every branch/product combination         | CROSS JOIN  | Cartesian product, no key needed

-- Employee-manager display                 | SELF (LEFT) | Same table twice; keep the top employee
 