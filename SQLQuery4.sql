--DAY 4 — Database Engineering Decisions

--Assignment A: Constraints and financial data
--A1. Payments table with a positive-amount CHECK and FK
CREATE TABLE Payments
(
   PaymentId   INT IDENTITY(1,1) PRIMARY KEY,
   AccountId   INT NOT NULL,
   Amount      DECIMAL(18,2) NOT NULL,
   PaymentDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
   CONSTRAINT FK_Payments_Accounts
       FOREIGN KEY (AccountId) REFERENCES Accounts(AccountId),
   CONSTRAINT CK_Payments_Amount
       CHECK (Amount > 0)
);
--CHECK (Amount > 0) blocks a negative or zero payment at the database level — no application bug can bypass it.



--A2. Risk of allowing negative payments (explanation) 
--A negative payment lets "payment" quietly behave like a refund or balance adjustment with nothing in the schema distinguishing them. 
--SUM(Amount) stops meaning "total paid," and it opens a path to secretly reduce what a customer owes through a channel that isn't categorized the way a real refund process would be — a fraud risk, not just messy data.



--A3. DECIMAL precision and scale (explanation)
--Balances & payments: DECIMAL(18,2) — scale 2 matches currency's smallest unit (cents); precision 18 gives enormous headroom.
--Exchange rates: DECIMAL(10,6) — rates are small numbers where extra decimal places (e.g. 0.912345) meaningfully change a converted amount, so scale 6 preserves that accuracy.



--A4.4. Add a status constraint  or controlled lookup design for account status. Explain the trade-off
--Design chosen: CHECK constraint.
      --CONSTRAINT CK_Accounts_Status
        --CHECK (Status IN ('Active','Closed','Frozen'))
--This constraint was created in Day 1 as part of the Accounts table design.
--Revisiting it here for Day 4's engineering-decisions review: ..."


--Trade-off:
--A CHECK constraint is simple to set up and needs no extra table, but it is rigid: adding a new status (for example, "Pending") requires an ALTER TABLE statement, which is a schema change and typically needs a deployment. 
--It also has nowhere to store extra information about each status,such as a description or whether that status should block withdrawals.


--A5. Audit table for transfers
CREATE TABLE TransferAudit
(
   AuditId              INT IDENTITY(1,1) PRIMARY KEY,
   TransferId           UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
   SourceAccountId      INT NOT NULL,
   DestinationAccountId INT NOT NULL,
   Amount               DECIMAL(18,2) NOT NULL,
   TransferDate         DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
   PerformedBy          SYSNAME NOT NULL DEFAULT SUSER_SNAME(),
   Status               VARCHAR(20) NOT NULL,
   CONSTRAINT FK_TransferAudit_Source FOREIGN KEY (SourceAccountId) REFERENCES Accounts(AccountId),
   CONSTRAINT FK_TransferAudit_Destination FOREIGN KEY (DestinationAccountId) REFERENCES Accounts(AccountId)
);
--Traceability fields: who (PerformedBy), when (TransferDate), which accounts, how much, and the outcome (Status) — enough to reconstruct exactly what happened.




--Assignment B: Atomic transfer
--B1

CREATE OR ALTER PROCEDURE sp_TransferFunds
   @SourceAccountId INT, @DestinationAccountId INT, @Amount DECIMAL(18,2)
AS
BEGIN
   -- Stops SQL Server from sending back "(1 row affected)" messages for
   -- every statement inside -- keeps EXEC output clean.
   SET NOCOUNT ON;
   -- Validation checks run BEFORE any transaction starts. If either check
   -- fails, THROW aborts the procedure immediately -- nothing has touched
   -- the Accounts table yet, so there is nothing to roll back.
   -- Reject a transfer to and from the same account (Assignment B5)
   IF @SourceAccountId = @DestinationAccountId
       THROW 50001, 'Source and destination accounts must be different.', 1;
   -- Reject a zero or negative transfer amount (Assignment B6, part 1)
   IF @Amount <= 0
       THROW 50002, 'Transfer amount must be greater than zero.', 1;
   BEGIN TRY
       -- Everything from here to COMMIT either ALL happens or NONE of it
       -- does -- that's what makes the transfer atomic (Assignment B2).
       BEGIN TRANSACTION;
       -- Debit the source account. The balance check lives INSIDE this
       -- UPDATE's WHERE clause (Balance >= @Amount) rather than as a
       -- separate SELECT beforehand -- that makes "check balance" and
       -- "deduct balance" one single atomic step, so no other connection
       -- can sneak in and change the balance in between (Assignment C2).
       UPDATE Accounts SET Balance = Balance - @Amount
       WHERE AccountId = @SourceAccountId AND Balance >= @Amount;
       -- @@ROWCOUNT holds how many rows the UPDATE just above actually
       -- changed. If it's 0, either @SourceAccountId doesn't exist, or
       -- its balance was too low for the WHERE clause to match -- either
       -- way, nothing was debited, so raise an error (Assignment B6, part 2).
       IF @@ROWCOUNT = 0
           THROW 50003, 'Source account not found or balance is insufficient.', 1;
       -- Credit the destination account with the same amount just debited.
       UPDATE Accounts SET Balance = Balance + @Amount
       WHERE AccountId = @DestinationAccountId;
       -- Same safety check as above, but for the destination side: if no
       -- row matched, that AccountId doesn't exist.
       IF @@ROWCOUNT = 0
           THROW 50004, 'Destination account not found.', 1;
       -- Both halves of the transfer succeeded -- write the audit trail
       -- recording who moved what, from where, to where (Assignment A5).
       INSERT INTO TransferAudit (SourceAccountId, DestinationAccountId, Amount, Status)
       VALUES (@SourceAccountId, @DestinationAccountId, @Amount, 'Success');
       -- Nothing failed anywhere above -- make every change permanent.
       COMMIT TRANSACTION;
   END TRY
   BEGIN CATCH
       -- Something inside TRY raised an error (one of the THROWs above,
       -- or an unexpected database error). @@TRANCOUNT > 0 means a
       -- transaction is still open, so undo every change made since
       -- BEGIN TRANSACTION -- including the debit, even though it
       -- physically ran (Assignment B4's proof that a mid-transfer
       -- failure leaves balances untouched).
       IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
       -- Re-raise the original error so the caller (EXEC statement, or
       -- whatever called this procedure) still sees exactly what went
       -- wrong, instead of the failure being silently swallowed here.
       THROW;
   END CATCH
END;


--B3. Test a successful transfer
-- STEP 1: Record the BEFORE balances
SELECT AccountId, Balance AS BalanceBefore
FROM Accounts
WHERE AccountId IN (2001, 2003);
-- STEP 2: Work out a safe amount to transfer -- half of 2001's current
-- balance, so it is always comfortably less than what's available
DECLARE @SafeAmount DECIMAL(18,2);
SELECT @SafeAmount = ROUND(Balance / 2, 2)
FROM Accounts
WHERE AccountId = 2001;
SELECT @SafeAmount AS AmountAboutToTransfer;
-- STEP 3: Run the actual transfer
EXEC sp_TransferFunds
   @SourceAccountId      = 2001,
   @DestinationAccountId = 2003,
   @Amount               = @SafeAmount;
-- STEP 4: Record the AFTER balances
SELECT AccountId, Balance AS BalanceAfter
FROM Accounts
WHERE AccountId IN (2001, 2003);
-- STEP 5: Confirm the audit record was written
SELECT TOP 1 *
FROM TransferAudit
ORDER BY AuditId DESC;


--B4. Force a failure between debit and credit

BEGIN TRY
   BEGIN TRANSACTION;
   UPDATE Accounts SET Balance = Balance - 500 WHERE AccountId = 2001;
   THROW 50099, 'Simulated failure injected between debit and credit.', 1;
   UPDATE Accounts SET Balance = Balance + 500 WHERE AccountId = 2003;
   COMMIT TRANSACTION;
END TRY
BEGIN CATCH
   IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
   PRINT 'Rolled back: ' + ERROR_MESSAGE();
END CATCH;

--Check 2001's balance before and after — it should be unchanged. 
--The debit physically ran, but ROLLBACK undoes it since it was never committed. That's atomicity.



-- B5: same source and destination account 
EXEC sp_TransferFunds
   @SourceAccountId = 2001, @DestinationAccountId = 2001, @Amount = 100;
-- B6: amount is zero 
EXEC sp_TransferFunds
   @SourceAccountId = 2001, @DestinationAccountId = 2003, @Amount = 0;
-- B6: amount greater than available balance 
EXEC sp_TransferFunds
   @SourceAccountId = 2001, @DestinationAccountId = 2003, @Amount = 999999999;



--B7. Why a debit-succeeds-credit-fails gap is serious (explanation)
--Moneyis deducted from the source but never arrives anywhere
--the total across all accounts no longer stays constant. That gap is nearly impossible to notice without a full reconciliation, by which point the funds are simply gone.



--Assignment C — Concurrency, indexes, views and procedures



-- C1. Safe conditional withdrawal
DECLARE @WithdrawAccountId INT = 2001;
DECLARE @WithdrawAmount DECIMAL(18,2) = 200.00;
UPDATE Accounts
SET Balance = Balance - @WithdrawAmount
WHERE AccountId = @WithdrawAccountId AND Balance >= @WithdrawAmount;
SELECT @@ROWCOUNT AS RowsAffected;




--C2. What @@ROWCOUNT means (explanation)
--It holds the row count affected by the immediately preceding statement. 
--Checking it after the UPDATE tells you whether the condition actually matched — 0 means the withdrawal was safely skipped rather than overdrawing. 
--Checking balance with a separate SELECT first would be a race condition; folding the check into the UPDATE's WHERE makes it atomic.



--C3. Composite index
CREATE INDEX IX_Transactions_AccountId_TransactionDate
ON Transactions (AccountId, TransactionDate)
INCLUDE (Amount);

--Speeds up "this account's transactions in date order" queries. INCLUDE (Amount) lets a query needing only those three columns be answered entirely from the index — a covering index.



--C4. Why not index every column (explanation)
--Every index slows every INSERT/UPDATE/DELETE, since it must be maintained too.
-- An index nobody queries by still costs that overhead for zero benefit, and too many indexes can even confuse the optimizer.
--Index based on actual query patterns, not defensively.



--C5. View for active accounts
CREATE OR ALTER VIEW vw_ActiveAccounts AS
SELECT AccountId, CustomerId, AccountType, Balance
FROM Accounts
WHERE Status = 'Active';
--Does: re-runs its SELECT live against Accounts every time it's queried. Does not: store or cache any rows of its own — dropping it never deletes data.



--C6. Parameterized stored procedure
CREATE OR ALTER PROCEDURE sp_GetCustomerAccounts
   @CustomerId INT
AS
BEGIN
   SET NOCOUNT ON;
   SELECT AccountId, AccountType, Balance, Status FROM Accounts WHERE CustomerId = @CustomerId;
END;



--C7. Why string concatenation is unsafe (explanation)
-- Concatenating raw input into SQL text lets an attacker's input become part of the command, not just a value — classic SQL injection.
-- It's hard to govern because every concatenation site needs its own correct escaping, and missing it once reopens the hole.
-- A parameter like @CustomerId is passed separately and can never be interpreted as SQL syntax.




--C8. Two ways to reduce deadlock risk (explanation)
--Consistent lock order:
--always touch accounts in the same order (e.g. by ascending AccountId), 
--regardless of source/destination role — otherwise two opposite-direction transfers between 
--the same two accounts can each hold one lock while waiting on the other's.

--Short transactions: 
--do all validation before BEGIN TRANSACTION, and keep nothing slow between it 
--and COMMIT — the shorter the lock is held, the smaller the collision window.