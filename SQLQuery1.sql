--Day 01:assigment A
--01.
--Coustomer;one row = one bank cousromer (a person or entity that can hold one or more accounts)
--Accounts; one row = one specific account beloning to coustomer (a coustomer can own several)
--Transactions; one row = one single movment of money on one account (a deposit ,withdrowal,transfer or fee)

--02.
--Coustomers 
--Primary Key = - CustomerId

--Accounts
--Primary Key = AccountId 
--Foreign Key = CustomerId - Customer.CustomerId 

--Transactions  
--Primary Key = TransactionId 
--Foreign Key = AccountId - Accounts.AccountId


--  why AccountId alone cant identify a coustomer?
-- an account belongs to exactly one coustomer ,but a coustomer can own multiple accounts.Account Id uniquwly identifies an account,not the person behind it we need to follow the CoustomerId foreing key to get back to the customer.Knowing an AccountId tells you wich acount not "whose"


--03.
     
CREATE TABLE Customers
(
 CustomerId INT PRIMARY KEY,
 FullName VARCHAR(100) NOT NULL,
 Email VARCHAR(150) UNIQUE,
 CreatedDate DATETIME2 NOT NULL
);

CREATE TABLE Accounts
(
 AccountId INT PRIMARY KEY,
 CustomerId INT NOT NULL,
 AccountType VARCHAR(30) NOT NULL,
 Balance DECIMAL(18,2) NOT NULL,
 Status VARCHAR(20) NOT NULL,
 CONSTRAINT FK_Accounts_Customers
 FOREIGN KEY (CustomerId)
 REFERENCES Customers(CustomerId),
 CONSTRAINT CK_Accounts_AccountType
 CHECK (Status in ('Savings','Checking','Fixed Deposit', 'Loan')),
 CONSTRAINT CK_Accounts_Status
 CHECK (Status in ('Active','Closed','Frozen')),


);

CREATE TABLE Transactions
(
 TransactionId BIGINT PRIMARY KEY,
 AccountId INT NOT NULL,
 TransactionType VARCHAR(20) NOT NULL,
 Amount DECIMAL(18,2) NOT NULL,
 TransactionDate DATETIME2 NOT NULL,
 CONSTRAINT FK_Transactions_Accounts
 FOREIGN KEY (AccountId)
 REFERENCES Accounts(AccountId),
 CONSTRAINT CK_Transaction_Type
 CHECK (TransactionType in ('Deposit','Withdrawal','Transfer', 'Fee')),
 CONSTRAINT CK_Transactions_Amount 
 CHECK (Amount <> 0)

);
--04.
--insert an account for coustomerId 999
 
 INSERT INTO Accounts VALUES (9999,999,'Savings',1000,'Active');


 --ERROR
--Msg 547, Level 16, State 0, Line 70
--The INSERT statement conflicted with the CHECK constraint "CK_Accounts_AccountType". The conflict occurred in database "BankingLab", table "dbo.Accounts", column 'Status'.
--The statement has been terminated.

--explanation
--it violates FK_Accounts_Customers - CoustomerId 999 doesn'exit in Coustomers,and the foreign key wont let Accounts refference a customer that isnt there.

--05.
--insert an transaction for AccountId 999


INSERT INTO Transactions VALUES (9999,999,'Deposit',500,'2026.09.22');

--error
--Msg 547, Level 16, State 0, Line 86
--The INSERT statement conflicted with the FOREIGN KEY constraint "FK_Transactions_Accounts". The conflict occurred in database "BankingLab", table "dbo.Accounts", column 'AccountId'.

--it violates Fk_Transactions_Accounts.this shows the dependency chain:Transactions depends on Accounts exising first ,wich itself depends onCustomers existing first - we cant create a transaction "floting" on a nonexistent account, just as you we cant create an account on a nonexsistent customer.


--06.

INSERT INTO Customers VALUES (9001,'Test A','duplicate@test.com','2026.01.01');
INSERT INTO Customers VALUES (9002,'Test B','duplicate@test.com','2026.01.01');

--Pourpose of UNIQUE:it guarantees no two rows share the same value in that column here ,no two customers can register the same email.NULL behavior under UNIQUE in SQL Server:NULL is treated as "unknown" not as a duplicate-able value,so SQL Server allows multiple rows with Email= NULL without violating the constraint.

--07.
--FLOAT stores approximate binary values numbers like 10.10 can silently drift to something like 10.0999999999 after repeated arithmetic , wich is unacceptable when tracking money to  the cent.DECIMAL (18,2) store an exact fixed point value with guaranteed precision m so ammounts never drift and balance always add up exactly.

--Assigment B
--01
SELECT CustomerId, FullName,Email
FROM Customers

--02

SELECT AccountId, CustomerId, Balance, Status
FROM Accounts
WHERE Status = 'Active' AND Balance >= 50000;
--03
SELECT AccountId, CustomerId, Balance, Status
FROM Accounts
WHERE (Status = 'Closed') OR  (Balance = 0);
--04
SELECT AccountId, CustomerId, AccountType
FROM Accounts
WHERE AccountType IN ('Savings','Checking');

--05
SELECT Top(10) AccountId, CustomerId, Balance
FROM Accounts
ORDER BY Balance DESC ,AccountId ASC;

--06
SELECT DISTINCT AccountType
FROM Accounts
ORDER BY AccountType ASC;
--07.
SELECT CustomerId, FullName FROM Customers WHERE Email IS NULL ;
SELECT CustomerId, FullName FROM Customers WHERE Email IS  NOT NULL ;

 --IN SQL,NULL  represents an unkonow, not a specific value - so SQL cant compare it with =.even if a row's email really is NULL, Email = NULL evaluates to Uknown,so it's silently excluded .That's why SQL provides dedicated oparators,IS NULL and IS NOT NILL,just for checking whether a value is missing.
--08.
SELECT TransactionId,TransactionType, Amount ,TransactionDate
FROM Transactions
WHERE TransactionDate >= '2026-09-01' AND TransactionDate < '2026-10-01';

--Assigment C
--01.
SELECT
CustomerId,
COUNT(*) AS AccountCount,
SUM(Balance) AS TotalBalance,
AVG(Balance) AS AvBalance
FROM Accounts
GROUP BY CustomerId;
--02.
SELECT
CustomerId,
SUM(Balance) AS ActiveTotalBalance
FROM Accounts
WHERE Status = 'Active'
GROUP BY CustomerId
HAVING SUM(Balance) >100000;
--03
SELECT
SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS ActiveCount,
SUM(CASE WHEN Status = 'Closed' THEN 1 ELSE 0 END) AS ClosedCount
FROM Accounts;
--04.
SELECT 
AccountType,
MAX(Balance) AS MaxBalance,
MIN(Balance) AS MinBalance,
AVG(Balance) AS AvgBalance
FROM Accounts
GROUP BY AccountType;
--05.
SELECT
TransactionType,
SUM(Amount) AS TotalAmount
FROM Transactions
GROUP BY TransactionType;

--06.
--WHERE Status = 'Active' filters individual rows before any grouping happens - it throws out non-active account one by one.HAVING SUM(Balance) > 10000 filters groups after aggregation -it only runs once each customer's rows have already been summed.we cant write WHERE SUM(Balance)>100000,because at the point WHERE executes ,no sums exist yet; aggregates only exist after GROUP BY has run, which is exactly why HAVING exist as a separate step.

--07.
--C1 - Customer-level(one row per CustomerID)
--C2 - Customer-level(one row per qualifying CustomerID)
--C3 - Singal overall summary row 
--C4 - Group-level(one row per AccountType)
--C5 - Group-level(one row per TransactionType)

--hard scenario
--01.
SELECT 
AccountId,CustomerId,Balance,
CASE
WHEN Balance < 0 THEN 'Negative'
WHEN Balance = 0 THEN 'zero'
WHEN Balance > 100000 THEN 'High - Value'
END AS Flag
FROM Accounts
WHERE Balance < 0 OR Balance = 0 OR Balance > 100000;

--02.
SELECT
Status,
COUNT(*) AS AccountCount,
SUM(Balance) AS TotalBalance,
MIN(Balance) AS MINBalance,
MAX(Balance) AS MAXBalance
FROM Accounts
GROUP BY Status;

--03.
--Not possible with pure Day 1 tools — and that's the point of the question.To flag a status whose total exceeds the average of all status totals, you'd need to: compute each status's total, average those totals together, then compare each status back against that average — all in one query. HAVING can only compare a group to a fixed constant (like HAVING SUM(Balance) > 100000), never to a value derived from the other groups' own results. Getting that derived comparison requires either a subquery/CTE (sum first, then average the sums) or a window function like AVG(SUM(Balance)) OVER () — both Day 3 topics.

--04.
SELECT *
FROM Accounts
WHERE Status IS NULL OR AccountType IS NULL OR Balance IS NULL;

--05.
-- Test 1: IS NULL correctly finds rows with missing emails
SELECT COUNT(*) AS ExpectedTwo FROM Customers WHERE Email IS NULL;
-- Expected: 2

-- Test 2: proves '=' is the wrong tool for NULL — always 0, even
-- though we just proved 2 NULL emails exist above
SELECT COUNT(*) AS AlwaysZero FROM Customers WHERE Email = NULL;
-- Expected: 0

-- Test 3: NOT IN silently breaks when the list contains a NULL —
-- classic hidden bug, worth knowing about even though it uses a
-- subquery (Day 3 tool, shown here only to illustrate the trap)
SELECT CustomerId FROM Customers
WHERE CustomerId NOT IN (SELECT CustomerId FROM Customers WHERE Email IS NULL);
-- Expected: 0 rows for the WHOLE query — not "6 rows minus the 2
-- NULLs" as you might assume — because NOT IN against any list
-- containing NULL returns unknown for every row, excluding everything.

SELECT*FROM Customers;
 

 

 
 
 










