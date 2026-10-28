-- Day 2: Setup script (safe to re-run: it resets Day 2 objects first)

-- Assumes the Day 1 tables and seed data already exist in BankingLab.

-- =========================================================

USE BankingLab;

GO

-- Reset (children before parents)

DROP TABLE IF EXISTS Fees;

DROP TABLE IF EXISTS Employees;

DROP TABLE IF EXISTS Products;

DROP TABLE IF EXISTS Branches;

DROP TABLE IF EXISTS SettlementTransactions;

DROP TABLE IF EXISTS CoreTransactions;

DELETE FROM Customers WHERE CustomerId IN (1009, 1010);

GO

-- Two customers WITHOUT accounts (needed for LEFT JOIN / IS NULL practice)

INSERT INTO Customers (CustomerId, FullName, Email, CreatedDate) VALUES

(1009, 'Isha Patel', 'isha.patel@mail.com', '2024-09-10'),

(1010, 'Jonas Reed', 'jonas.reed@mail.com', '2024-10-01');

-- Reconciliation tables (Assignment B1/B2)

-- ReferenceNo is deliberately NOT unique so a duplicate can be inserted later.

CREATE TABLE CoreTransactions

(

    CoreId       INT IDENTITY(1,1) PRIMARY KEY,

    ReferenceNo  VARCHAR(20)   NOT NULL,

    Amount       DECIMAL(18,2) NOT NULL

);

CREATE TABLE SettlementTransactions

(

    SettlementId INT IDENTITY(1,1) PRIMARY KEY,

    ReferenceNo  VARCHAR(20)   NOT NULL,

    Amount       DECIMAL(18,2) NOT NULL

);

INSERT INTO CoreTransactions (ReferenceNo, Amount) VALUES

('REF001', 100.00),   -- matches settlement

('REF002', 200.00),   -- amount mismatch (settlement has 250)

('REF003', 300.00),   -- core only

('REF004', 400.00);   -- core only

INSERT INTO SettlementTransactions (ReferenceNo, Amount) VALUES

('REF001', 100.00),

('REF002', 250.00),

('REF005', 500.00);   -- settlement only

-- CROSS JOIN tables (Assignment B3): 3 branches x 4 products = 12

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

-- SELF JOIN table (Assignment B4): manager is another row in the same table

CREATE TABLE Employees

(

    EmployeeId INT PRIMARY KEY,

    FullName   VARCHAR(100) NOT NULL,

    ManagerId  INT NULL,

    CONSTRAINT FK_Employees_Manager

        FOREIGN KEY (ManagerId) REFERENCES Employees(EmployeeId)

);

INSERT INTO Employees (EmployeeId, FullName, ManagerId) VALUES

(1, 'Ravi Kumar', NULL),   -- top of the hierarchy, no manager

(2, 'Meena Rao',  1),

(3, 'Arun Das',   1),

(4, 'Sita Nair',  2),

(5, 'Kiran Shah', 2);

-- Fees table (Assignment C2): several fees per account

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
 

