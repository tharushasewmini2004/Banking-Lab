--DAY 3 — Advanced Querying
--Assignment A — CASE and subqueries
USE BankingLab;
GO
--A1.Classsify Each account
SELECT AccountId,Balance,
   CASE 
       WHEN Balance < 0         THEN 'Overdrawn'
       WHEN Balance = 0         THEN 'Zero Balance'
       WHEN Balance > 100000    THEN 'High Balance'
       ELSE 'Standard'
   END AS Classification
FROM Accounts;


--A2.accounts above the overall average balance(Scalar subquery)
SELECT AccountId,Balance
FROM Accounts
WHERE Balance > (SELECT AVG(Balance) FROM Accounts);


--A3. accounts above their own accountType's average (Correlated subquery)
SELECT AccountId, AccountType, Balance
FROM Accounts a1
WHERE Balance > (
    SELECT AVG(Balance) FROM Accounts a2 WHERE a2.AccountType =a1.AccountType
);


--A4. Coustomers with at least one active account(Correlated EXISTS)
SELECT c.CustomerId,c.FullName
FROM Customers c
WHERE EXISTS (
     SELECT 1 FROM Accounts a
     WHERE a.CustomerId = c.CustomerId AND a.Status ='Active'
);

--A5. accounts with no transaction (NOT EXISTS)
SELECT AccountId
FROM Accounts a
WHERE NOT EXISTS (
SELECT 1 FROM Transactions t WHERE t.AccountID = a.AccountId

);


--why its an existence question--
--its never needs to know wich transactions exixt,only whether at least one does.
--SQL Server can stop serching the moment it finds one match (or confirms there's none),
--instead of reading every row . 

--A6.scalar vs correlated(explanation)
--A scalar subquery returns one value and runs independently of the outer query (A2).
--A correlated subquery references a column from the outer row in its own WHERE clause,
--so it effectively re-runs once per outer row (A3, A4, A5).


--Assignment B — CTEs and set operators


--B1.ActiveAccounts CTE 
WITH ActiveAccounts AS (
   SELECT CustomerId, COUNT(*) AS ActiveAccountCount, SUM(Balance) AS ActiveBalance
   FROM Accounts
   WHERE Status = 'Active'
   GROUP BY CustomerId
)
SELECT c.CustomerId, c.FullName,
      COALESCE(aa.ActiveAccountCount, 0) AS ActiveAccountCount,
      COALESCE(aa.ActiveBalance, 0)      AS ActiveBalance
FROM Customers c
LEFT JOIN ActiveAccounts aa ON aa.CustomerId = c.CustomerId;
--WITH ... AS (.....)Names a temporary Result set the reset of the statement can referance like a table.


--B2 Two stage CTE pipeline 
WITH TxnByAccount AS (
   SELECT AccountId, SUM(Amount) AS TotalTxn
   FROM Transactions
   GROUP BY AccountId
)
SELECT a.AccountId, a.Balance, COALESCE(t.TotalTxn, 0) AS TotalTransactionAmount
FROM Accounts a
LEFT JOIN TxnByAccount t ON t.AccountId = a.AccountId
WHERE a.Status = 'Active';

--Same "aggregate first, then join" pattern from Day 2 C4 — the CTE collapses Transactions to one row per account before joining, so there's no multiplication risk.


--B3 Union 
SELECT CustomerId FROM Customers
UNION
SELECT CustomerId FROM Accounts;

--explain why duplicates disappear.
--Every CustomerId in Accounts already exists in Customers (the foreign key guarantees it), so UNION recognizes those as duplicates and drops them, 
--even though Accounts alone contributes 14 non-distinct values.
 

 --B4 ALL Union 
SELECT CustomerId FROM Customers
UNION ALL
SELECT CustomerId FROM Accounts;

--explain why duplicate rows may be meaningful.


--Here the duplicates are meaningful: a CustomerId appearing 3 times tells you that customer owns 2 accounts — collapsing it with UNION would destroy that information.

--B5 credits, total debits, and net movement per account. 
WITH Movement AS (
  SELECT
       AccountId,
       SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,
       SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits
   FROM Transactions
   GROUP BY AccountId
)
SELECT AccountId, TotalCredits, TotalDebits, (TotalCredits - TotalDebits) AS NetMovement
FROM Movement;

--the schema doesn't mark direction, so I treated Deposit/Transfer as money in and Withdrawal/Fee as money out.
 


--B6 Explain why a CTE improves readability but does not automatically materialize data or guarantee faster performance.

--A CTE only improves readability. 
--SQL Server doesn't store its result anywhere — it's expanded into the main query plan at execution time, same as an inline subquery.
--A CTE referenced twice can be computed twice.





--Assignment C — Window functions

-- C1.ROW_NUMBER partitioned by AccountId

SELECT AccountId,TransactionId,TransactionDate,
     ROW_NUMBER() OVER (PARTITION BY AccountId ORDER BY TransactionDate DESC) AS RowNum
FROM Transactions;


--PARTITION BY restarts the numbering for every new AccountId — the window-function version of GROUP BY, 
--But without collapsing rows.
 

-- C2. Latest transaction per account, with a tie-breaker
WITH Ranked AS (
   SELECT AccountId, TransactionId, TransactionDate,
          ROW_NUMBER() OVER (
              PARTITION BY AccountId
              ORDER BY TransactionDate DESC, TransactionId DESC
          ) AS RowNum
   FROM Transactions
)
SELECT AccountId, TransactionId, TransactionDate
FROM Ranked
WHERE RowNum = 1;

--TransactionId DESC is a pure tie-breaker — if two transactions shared a date,
--it guarantees the same result every run instead of an arbitrary pick.




--C3.Running Total per account 
SELECT AccountId, TransactionId, TransactionDate, Amount,
      SUM(Amount) OVER (
          PARTITION BY AccountId
          ORDER BY TransactionDate, TransactionId
      ) AS RunningTotal
FROM Transactions;

--With ORDER BY inside OVER(), the default frame is "from the start of this partition to the current row,
--" so the total accumulates down each account and resets at the next account.




--C4.Use DENSE_RANK to find the second-highest account balance
WITH RankedBalances AS (
   SELECT AccountId, Balance, DENSE_RANK() OVER (ORDER BY Balance DESC) AS BalanceRank
   FROM Accounts
)
SELECT AccountId, Balance
FROM RankedBalances
WHERE BalanceRank = 2;

--DENSE_RANK gives tied values the same rank and doesn't skip the next number, unlike RANK().




--C5.Compare GROUP BY and window functions (explanation only)
--GROUP BY collapses a group into one summary row, losing the detail rows. 
--A window function attaches the same kind of calculation to every detail row instead.
--Business example: a bank statement needs every transaction line visible and a running balance beside each one — 
--GROUP BY could only give one final total, destroying the list; C3's window function keeps both.




--C6. Monthly transaction ranking report
 SELECT
   AccountId, TransactionId, TransactionDate, Amount,
   FORMAT(TransactionDate, 'yyyy-MM') AS TransactionMonth,
   RANK() OVER (
       PARTITION BY FORMAT(TransactionDate, 'yyyy-MM')
       ORDER BY Amount DESC
   ) AS AmountRankInMonth
FROM Transactions
ORDER BY TransactionMonth, AmountRankInMonth;
--Partitioning by the formatted month groups transactions into calendar months without needing a separate month column.




-- Day 3 hard scenario -- Fraud review queue
-- H1: CTE that aggregates credits and debits per account

-- Grain: one row per AccountId that has at least one transaction.
-- Same Deposit/Transfer = credit, Withdrawal/Fee = debit assumption as B5.

WITH Movement AS (
   SELECT
       AccountId,
       SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,
       SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits
   FROM Transactions
   GROUP BY AccountId
)
SELECT * FROM Movement;




-- H2: second CTE that ranks each account's transactions and  retains the latest record.

-- Grain: one row per AccountId that has at least one transaction
-- (this CTE alone does NOT cover accounts with zero transactions 

WITH Ranked AS (
   SELECT AccountId, TransactionId, TransactionDate, Amount,
          ROW_NUMBER() OVER (
              PARTITION BY AccountId
              ORDER BY TransactionDate DESC, TransactionId DESC
          ) AS RowNum
   FROM Transactions
),
LatestPerAccount AS (
   SELECT AccountId, TransactionId, TransactionDate, Amount
   FROM Ranked
   WHERE RowNum = 1
)
SELECT * FROM LatestPerAccount;

-- How duplicates were prevented: TransactionDate DESC, TransactionId DESC
-- gives every row inside a partition a unique rank, so exactly one row per AccountId can ever satisfy RowNum = 1,
--even if two transactions shared the same date.




-- H3: accounts where total debits exceed total credits
-- Grain: one row per AccountId flagged for unusually high outgoing movement.

WITH Movement AS (
   SELECT
       AccountId,
       SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,
       SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits
   FROM Transactions
   GROUP BY AccountId
)
SELECT AccountId, TotalCredits, TotalDebits
FROM Movement
WHERE TotalDebits > TotalCredits;




-- H4: latest transaction for each account, PRESERVING accounts with no transactions at all.

-- Grain: one row per Account , with NULL transaction columns
-- for accounts that have never had a transaction.

WITH Ranked AS (
   SELECT AccountId, TransactionId, TransactionDate, Amount,
          ROW_NUMBER() OVER (
              PARTITION BY AccountId
              ORDER BY TransactionDate DESC, TransactionId DESC
          ) AS RowNum
   FROM Transactions
)
SELECT a.AccountId, r.TransactionId, r.TransactionDate, r.Amount
FROM Accounts a
LEFT JOIN Ranked r ON r.AccountId = a.AccountId AND r.RowNum = 1
ORDER BY a.AccountId;

-- The key difference from H2: this LEFT JOINs the ranked CTE onto the FULL
-- Accounts table , rather than selecting from the CTE alone. Putting
-- "AND r.RowNum = 1" inside the ON clause (not a separate WHERE) matters here
-- -- see Day 2 Assignment A3 for why a condition on the right-hand table
-- belongs in ON when we need to keep unmatched left-hand rows.




-- H5: customers with no transaction during a specified date window

-- Grain: one row per customer who had zero activity in the window.
-- Window used here as an example: September 2026 (adjust the two dates
-- to whatever window your trainer specifies).

SELECT c.CustomerId, c.FullName
FROM Customers c
WHERE NOT EXISTS (
   SELECT 1
   FROM Accounts a
   JOIN Transactions t ON t.AccountId = a.AccountId
   WHERE a.CustomerId = c.CustomerId
     AND t.TransactionDate >= '2026-09-01' AND t.TransactionDate < '2026-10-01'
);

-- The subquery has to join Accounts to Transactions, because Transactions has
-- no CustomerId column of its own -- CustomerId only exists by way of the
-- account each transaction belongs to.




-- H6 grain of each CTE, and duplicate prevention

-- Movement (H1/H3)     -- grain: one row per AccountId that has at least one
--                         transaction. GROUP BY collapses all of an account's
--                         transactions into a single credits/debits pair.
-- Ranked / LatestPerAccount (H2) -- grain: one row per transaction, with a
--                         RowNum column attached (window functions never
--                         collapse rows); filtering WHERE RowNum = 1 then
--                         narrows this down to exactly one row per AccountId
--                         that has transactions.
-- H4's final result     -- grain: one row per Account (every account, 14
--                         total), because the LEFT JOIN is against the full
--                         Accounts table, not just the ones with transactions.
--
-- Duplicate prevention: ROW_NUMBER() with ORDER BY TransactionDate DESC,
-- TransactionId DESC guarantees a strict, total order within each AccountId
-- partition -- TransactionId is a primary key, so no two rows can ever tie on
-- both columns together. That is what guarantees RowNum = 1 selects EXACTLY
-- one row per account, never zero and never two.





