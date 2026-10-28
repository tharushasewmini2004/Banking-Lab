--DAY 5 — Performance, Reporting and Final Assessment
--Assignment A — Performance investigation

-- A1. Baseline for the transaction query

-- turn on time and IO stats so we can see CPU time, elapsed time and logical reads
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- get all transactions from 2026
SELECT *
FROM Transactions
WHERE YEAR(TransactionDate) = 2026;

--show how many rows the query above returend
SELECT @@ROWCOUNT AS RowsReturend;

-- turn stats off again
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;



--A2.Rewrite as a date-range predicate

-- get all 2026 transactions using BETWEEN
SELECT *
FROM Transactions
WHERE TransactionDate BETWEEN '2026-01-01' AND '2026-12-31 23:59:59.9999999';



--A3.-----------------------------------------------------------------------------------------
--Actual execution plan - it's contain runtime information (Ctrl+M)
--                        ex;-Actual Number of rows 
--                         Full execute the query

-- 3 Types of Scans
-- Table Scan -Read every row in a table (worst type)
-- Idex Scan  -Read all entries in a index to find results.
-- Index Seek -Quickly rocates specific rows in an index. (Best type)

--ex;To read 12 rows we read 6034 rows in Table scan but Index seek we read only 12rows

--A lookup is used to find and retrive a related value from another table using a coomon field usually an ID
--ex;DepartmentID - DepartmentName 

---------------------------------------------------------------------------------------------------

--A3. Inspect the actual execution plan
  --(no new query - results from the Execution plan tab for A1 and A2)
 
/* Findings:
  - Scans: both queries used a Clustered Index Scan, meaning SQL Server
    read the whole table. The existing index from Day 4
    (AccountId, TransactionDate) could not help, because its first column
    is AccountId and these queries filter only on TransactionDate.
  - Lookups: none.
  - Expensive joins: none, it is a single-table query.
  - Spills: none, there were no Sort or Hash operators and no warnings.
  - Estimation:
      A1 (YEAR)  estimated __ rows, actual __ rows
      A2 (range) estimated __ rows, actual __ rows
    The YEAR() query estimate was less accurate, because SQL Server cannot
    use column statistics properly when the column is inside a function.
    Poor estimates can lead SQL Server to choose a bad plan on bigger
    queries.
  - Missing index suggestion: SQL Server suggested an index on
    TransactionDate (green text at the top of the plan) [keep or remove
    this line depending on what your plan shows].
  Main problem: a full table scan to return a small number of rows.
  */







/* -A4. Create one index candidate and measure again
   (Only ONE thing changes: the index. The query is exactly the same as A2.)*/

CREATE INDEX IX_Transactions_TransactionDate_Only
ON Transactions (TransactionDate)
INCLUDE (AccountId, TransactionType, Amount);

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT *
FROM Transactions
WHERE TransactionDate BETWEEN '2026-01-01' AND '2026-12-31 23:59:59.9999999';
SELECT @@ROWCOUNT AS RowsReturned;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

/*
  Explanation:
  The index is sorted by TransactionDate, so SQL Server can jump straight
  to 1 Jan 2026 and stop at 1 Jan 2027 instead of reading every row.
  The INCLUDE columns, plus TransactionId (added automatically because it
  is the clustered key), mean the index holds every column the query
  needs, so no Key Lookup back to the table is required.
*/

-- extra check: the YEAR() version with the new index in place
SET STATISTICS IO ON;

SELECT *
FROM Transactions
WHERE YEAR(TransactionDate) = 2026;

SET STATISTICS IO OFF;
/* Result: Index Scan, not Index Seek. Logical reads = 0
  Even with the right index, the function on the column stops SQL Server
  from seeking. The improvement needs BOTH the index AND the SARGable
  date-range predicate.*/







 /*  --A5. Why a faster query may still be incorrect or unsuitable
      for a write-heavy workload 
  
1. Faster does not mean correct.
     For example:
         WHERE TransactionDate BETWEEN '2026-01-01' AND '2026-12-31'
     runs just as fast, but misses every transaction after midnight on
     31 December, so the result is wrong. That is why I always compared
     row counts BEFORE comparing speed.

2. Indexes have a write cost.
     Transactions is a write-heavy table: a new row is added for every
     deposit, withdrawal, transfer and fee. Every time a row is inserted,
     updated or deleted, SQL Server must also update every index on the
     table. An index that makes one report faster can slow down thousands
     of inserts and uses extra storage. Whether it is worth keeping
     depends on how often the table is read compared to how often it is
     written.*/




 --Assignment B: Reporting Failure Diagnosis

 --B1. Investigate a report whose SUM is higher than the trusted source total

-- the report: joins Transactions AND Fees onto Accounts

SELECT c.CustomerId, SUM(t.Amount) AS ReportTotal

FROM Customers c
LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId
LEFT JOIN Transactions t ON t.AccountId  = a.AccountId
LEFT JOIN Fees f         ON f.AccountId  = a.AccountId
GROUP BY c.CustomerId;


-- total of the whole report
SELECT SUM(ReportTotal) AS ReportGrandTotal
FROM (
   SELECT c.CustomerId, SUM(t.Amount) AS ReportTotal
   FROM Customers c
   LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId
   LEFT JOIN Transactions t ON t.AccountId  = a.AccountId
   LEFT JOIN Fees f         ON f.AccountId  = a.AccountId
   GROUP BY c.CustomerId
) AS r;

/* Result:
  Report grand total = 289,325
  Trusted total      = 209,825  (see B4)
  Customer 1001 shows 19,225 instead of 9,725.
  Customer 1002 shows 110,050 instead of 40,050.
  The report is too high, so some rows are being counted more than once.
*/




--B2. Define the expected grain and count rows after each JOIN

/* Expected grain of the report: one row per customer.
  Count rows as each table is added, to find where rows multiply. */
-- stage 1: customers only
SELECT COUNT(*) AS Stage1_Rows
FROM Customers c;
-- stage 2: + accounts
SELECT COUNT(*) AS Stage2_Rows
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId;
-- stage 3: + transactions
SELECT COUNT(*) AS Stage3_Rows, COUNT(t.TransactionId) AS TxnRows
FROM Customers c
LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId
LEFT JOIN Transactions t ON t.AccountId  = a.AccountId;
-- stage 4: + fees
SELECT COUNT(*) AS Stage4_Rows, COUNT(t.TransactionId) AS TxnRows
FROM Customers c
LEFT JOIN Accounts a     ON a.CustomerId = c.CustomerId
LEFT JOIN Transactions t ON t.AccountId  = a.AccountId
LEFT JOIN Fees f         ON f.AccountId  = a.AccountId;

/* Result:
  | Stage            | Rows | Transaction rows |
  |------------------|------|------------------|
  | Customers        | 10   | -                |
  | + Accounts       | 16   | -                |
  | + Transactions   | 21   | 15               |
  | + Fees           | 28   | 22               |
  Stages 2 and 3 grow for a good reason: customers have several
  accounts, and accounts have several transactions.
  Stage 4 is the problem: there are only 15 real transactions, but 22
  transaction rows appear. The duplication starts when Fees is joined.
*/
  



--B3. Check whether a one-to-many table was joined to another one-to-many table before aggregation

-- how many transactions and fees each account has

SELECT a.AccountId,
      (SELECT COUNT(*) FROM Transactions t WHERE t.AccountId = a.AccountId) AS TxnCount,
      (SELECT COUNT(*) FROM Fees f         WHERE f.AccountId = a.AccountId) AS FeeCount
FROM Accounts a
ORDER BY a.AccountId;

/* Result:
  Account 2001: 3 transactions x 2 fees = 6 rows (should be 3)
  Account 2003: 2 transactions x 3 fees = 6 rows (should be 2)
  Cause: Transactions and Fees are BOTH one-to-many from Accounts, but
  they are not related to each other. Joining both onto the same
  account, before aggregating, pairs every transaction with every fee
  on that account. Each transaction amount is then counted once per fee.
*/




--B4. Create a control query that independently calculates the trusted total
 
-- control query: straight from the source table, no joins

SELECT SUM(Amount) AS TrustedTotal
FROM Transactions;

/* Result: 209,825
  Fix for the report: aggregate transactions per account FIRST,
  then join. Fees is left out because this report is about
  transaction totals only. */

WITH TxnPerAccount AS (
   SELECT AccountId, SUM(Amount) AS TotalTxn
   FROM Transactions
   GROUP BY AccountId
)

SELECT c.CustomerId, COALESCE(SUM(tp.TotalTxn), 0) AS ReportTotal
FROM Customers c
LEFT JOIN Accounts a       ON a.CustomerId = c.CustomerId
LEFT JOIN TxnPerAccount tp ON tp.AccountId = a.AccountId
GROUP BY c.CustomerId;

-- check the fixed report adds up to the trusted total

WITH TxnPerAccount AS (
   SELECT AccountId, SUM(Amount) AS TotalTxn
   FROM Transactions
   GROUP BY AccountId
),

Report AS (
   SELECT c.CustomerId, COALESCE(SUM(tp.TotalTxn), 0) AS ReportTotal
   FROM Customers c
   LEFT JOIN Accounts a       ON a.CustomerId = c.CustomerId
   LEFT JOIN TxnPerAccount tp ON tp.AccountId = a.AccountId
   GROUP BY c.CustomerId
)

SELECT SUM(ReportTotal) AS FixedReportTotal
FROM Report;

/* Result: 209,825, which matches the control query, so the fix works.
  The control query is independent: it calculates the total a
  completely different way, so a bug in the report can't also hide
  in the check.
*/





--B5. Investigate missing customers caused by INNER JOIN or a right-side WHERE predicate
  
-- how many customers should appear
SELECT COUNT(*) AS TrueCustomerCount
FROM Customers;

-- cause 1: INNER JOIN drops customers with no accounts
SELECT COUNT(DISTINCT c.CustomerId) AS CustomersShown
FROM Customers c
INNER JOIN Accounts a ON a.CustomerId = c.CustomerId;

-- cause 2: a WHERE on the right table turns a LEFT JOIN into an INNER JOIN
SELECT COUNT(DISTINCT c.CustomerId) AS CustomersShown
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId
WHERE a.Status = 'Active';

-- fix: keep the LEFT JOIN and move the condition into ON
SELECT COUNT(DISTINCT c.CustomerId) AS CustomersShown
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId
                   AND a.Status = 'Active';

/* Result:
  True customer count = 10
  Cause 1 (INNER JOIN)        = 8   -> 1009 and 1010 missing (no accounts)
  Cause 2 (right-side WHERE)  = 7   -> 1008, 1009, 1010 missing
  Fix (condition in ON)       = 10  -> every customer kept
  Why cause 2 happens: customers with no active account get NULL in
  a.Status. WHERE a.Status = 'Active' then throws those NULL rows away,
  so the LEFT JOIN behaves like an INNER JOIN. In ON, the condition only
  decides which accounts match, and every customer is still kept.
*/




--B6. Investigate duplicate customers caused by account-level output being mistaken for customer-level output
  

-- looks like a customer list, but it is really one row per account
SELECT c.CustomerId, c.FullName
FROM Customers c
INNER JOIN Accounts a ON a.CustomerId = c.CustomerId;

-- which customers appear more than once
SELECT c.CustomerId, COUNT(*) AS TimesShown
FROM Customers c
INNER JOIN Accounts a ON a.CustomerId = c.CustomerId
GROUP BY c.CustomerId
HAVING COUNT(*) > 1;

-- fix: make the grain one row per customer
SELECT c.CustomerId, c.FullName, COUNT(a.AccountId) AS AccountCount
FROM Customers c
LEFT JOIN Accounts a ON a.CustomerId = c.CustomerId
GROUP BY c.CustomerId, c.FullName;

/* Result:
  First query: 14 rows, but only 8 different customers.
  Customers 1001, 1002, 1003, 1004, 1007 and 1008 each appear twice,
  because each has 2 accounts.
  Fixed query: 10 rows, one per customer, with their account count.
  I fixed the grain with GROUP BY instead of adding DISTINCT.
  DISTINCT would hide the duplicates without fixing the real problem.
*/





 -- B7. Investigate incorrect latest-record logic when timestamps are tied
 
-- create a tie: a new transaction on account 2001 at exactly the same

-- time as transaction 3012 (only inserts it once)
INSERT INTO Transactions (TransactionId, AccountId, TransactionType, Amount, TransactionDate)
SELECT 3016, 2001, 'Deposit', 10.00, '2026-09-22T13:00:00'
WHERE NOT EXISTS (SELECT 1 FROM Transactions WHERE TransactionId = 3016);

-- find tied timestamps
SELECT AccountId, TransactionDate, COUNT(*) AS TiedRows
FROM Transactions
GROUP BY AccountId, TransactionDate
HAVING COUNT(*) > 1;

-- buggy: no tie-breaker
SELECT AccountId, TransactionId, TransactionDate,
      ROW_NUMBER() OVER (PARTITION BY AccountId
                         ORDER BY TransactionDate DESC) AS rn
FROM Transactions
WHERE AccountId = 2001;
-- fixed: TransactionId breaks the tie
SELECT AccountId, TransactionId, TransactionDate,
      ROW_NUMBER() OVER (PARTITION BY AccountId
                         ORDER BY TransactionDate DESC, TransactionId DESC) AS rn
FROM Transactions
WHERE AccountId = 2001;

/* Result:
  Tie check: account 2001 has 2 rows at 2026-09-22 13:00.
  Buggy query: 3012 and 3016 have the same date, so SQL Server can
  give rn = 1 to either one. The "latest" record can change between runs.
  Fixed query: 3016 always gets rn = 1, because TransactionId is the
  primary key and can never tie.
  I kept transaction 3016 in the table because Part C uses it as the
  "tied transaction timestamps" edge case.
*/



 