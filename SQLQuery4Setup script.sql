INSERT INTO Customers (CustomerId, FullName, Email, CreatedDate) VALUES
(1001, 'Alice Johnson', 'alice.johnson@mail.com', '2024-01-10'),
(1002, 'Brian Smith',   'brian.smith@mail.com',   '2024-02-15'),
(1003, 'Carla Diaz',    NULL,                     '2024-03-20'),
(1004, 'David Lee',     'david.lee@mail.com',     '2024-04-05'),
(1005, 'Emma Wilson',   'emma.wilson@mail.com',   '2024-05-12'),
(1006, 'Farhan Ali',    'farhan.ali@mail.com',    '2024-06-18'),
(1007, 'Grace Chen',    'grace.chen@mail.com',    '2024-07-22'),
(1008, 'Henry Brown',   'henry.brown@mail.com',   '2024-08-30');
INSERT INTO Accounts (AccountId, CustomerId, AccountType, Balance, Status) VALUES
(2001, 1001, 'Savings',       75000.00,  'Active'),
(2002, 1001, 'Checking',       1200.50,  'Active'),
(2003, 1002, 'Savings',      120000.00,  'Active'),
(2004, 1002, 'Loan',         -25000.00,  'Active'),   -- negative: outstanding loan
(2005, 1003, 'Checking',           0.00,'Closed'),    -- zero balance
(2006, 1003, 'Fixed Deposit',  50000.00, 'Active'),
(2007, 1004, 'Savings',         -500.00, 'Active'),   -- negative: overdraft
(2008, 1004, 'Checking',       30000.00, 'Frozen'),
(2009, 1005, 'Savings',        99000.00, 'Active'),
(2010, 1006, 'Savings',        45000.00, 'Active'),
(2011, 1007, 'Checking',       68000.00, 'Active'),
(2012, 1007, 'Fixed Deposit', 150000.00, 'Active'),   -- high-value
(2013, 1008, 'Loan',          -12000.00, 'Closed'),
(2014, 1008, 'Savings',          500.00, 'Frozen');
INSERT INTO Transactions (TransactionId, AccountId, TransactionType, Amount, TransactionDate) VALUES
(3001, 2001, 'Deposit',    5000.00, '2026-08-01T09:00:00'),
(3002, 2001, 'Withdrawal', 1500.00, '2026-08-15T14:30:00'),
(3003, 2002, 'Deposit',     200.00, '2026-09-01T08:00:00'),  -- Sept boundary start
(3004, 2002, 'Fee',          25.00, '2026-09-10T00:00:00'),
(3005, 2003, 'Deposit',   20000.00, '2026-07-20T10:00:00'),
(3006, 2004, 'Withdrawal', 5000.00, '2026-09-12T11:15:00'),
(3007, 2005, 'Deposit',     100.00, '2026-06-01T09:00:00'),
(3008, 2006, 'Deposit',   50000.00, '2026-05-15T09:00:00'),
(3009, 2007, 'Withdrawal',  200.00, '2026-09-18T16:00:00'),
(3010, 2008, 'Transfer',  10000.00, '2026-09-20T12:00:00'),
(3011, 2009, 'Deposit',   99000.00, '2026-04-10T09:00:00'),
(3012, 2001, 'Transfer',   3000.00, '2026-09-22T13:00:00'),
(3013, 2003, 'Withdrawal',15000.00, '2026-09-30T23:00:00'),  -- Sept boundary end
(3014, 2004, 'Fee',          50.00, '2026-10-01T00:00:00'),  -- just outside Sept
(3015, 2011,'Deposit',     750.00, '2026-09-05T09:00:00');
USE BankingLab;
SELECT AccountId FROM Accounts ORDER BY AccountId;
SELECT COUNT(*) AS CurrentTransactions FROM Transactions;
-- add 15 sample transactions (all in 2026)
INSERT INTO Transactions (TransactionId, AccountId, TransactionType, Amount, TransactionDate)
VALUES
(3001, 2001, 'Deposit',     5000.00, '2026-08-01T09:00:00'),
(3002, 2001, 'Withdrawal',  1500.00, '2026-08-15T14:30:00'),
(3003, 2002, 'Deposit',      200.00, '2026-09-01T08:00:00'),
(3004, 2002, 'Fee',           25.00, '2026-09-10T00:00:00'),
(3005, 2003, 'Deposit',    20000.00, '2026-07-20T10:00:00'),
(3006, 2004, 'Withdrawal',  5000.00, '2026-09-12T11:15:00'),
(3007, 2005, 'Deposit',      100.00, '2026-06-01T09:00:00'),
(3008, 2006, 'Deposit',    50000.00, '2026-05-15T09:00:00'),
(3009, 2007, 'Withdrawal',   200.00, '2026-09-18T16:00:00'),
(3010, 2008, 'Transfer',   10000.00, '2026-09-20T12:00:00'),
(3011, 2009, 'Deposit',    99000.00, '2026-04-10T09:00:00'),
(3012, 2001, 'Transfer',    3000.00, '2026-09-22T13:00:00'),
(3013, 2003, 'Withdrawal', 15000.00, '2026-09-30T23:00:00'),
(3014, 2004, 'Fee',           50.00, '2026-10-01T00:00:00'),
(3015, 2011, 'Deposit',      750.00, '2026-09-05T09:00:00');
SELECT *
FROM Transactions