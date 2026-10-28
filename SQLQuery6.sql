

 --DAY 5 - Assignment C: Final Banking Operations Mini-Project

 

USE BankingLab;

GO



--- C1. Show every customer and the number of active accounts, including customers with zero active accounts


SELECT

    c.CustomerId,

    c.FullName,

    COUNT(a.AccountId) AS ActiveAccountCount

FROM Customers c

LEFT JOIN Accounts a

       ON a.CustomerId = c.CustomerId

      AND a.Status = 'Active'

GROUP BY c.CustomerId, c.FullName

ORDER BY c.CustomerId;

/* Expected: 10 rows.

   1001 = 2, 1002 = 2, 1003 = 1, 1004 = 1, 1005 = 1, 1006 = 1, 1007 = 2,

   1008 = 0, 1009 = 0, 1010 = 0

   Grain: one row per customer.

   JOIN: LEFT JOIN, because every customer must appear, even with no

   active accounts. Status = 'Active' is in the ON clause, not WHERE.

   In WHERE it would remove customers 1008, 1009 and 1010.

   COUNT(a.AccountId) gives 0 for them. COUNT(*) would wrongly give 1.*/





  -- C2. Show each active account's total credits, total debits, and net movement

WITH Movement AS (

    -- step 1: one row per account with transactions

    SELECT

        AccountId,

        SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,

        SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits

    FROM Transactions

    GROUP BY AccountId

)

-- step 2: join to active accounts

SELECT

    a.AccountId,

    a.CustomerId,

    COALESCE(m.TotalCredits, 0) AS TotalCredits,

    COALESCE(m.TotalDebits, 0)  AS TotalDebits,

    COALESCE(m.TotalCredits, 0) - COALESCE(m.TotalDebits, 0) AS NetMovement

FROM Accounts a

LEFT JOIN Movement m ON m.AccountId = a.AccountId

WHERE a.Status = 'Active'

ORDER BY a.AccountId;


/* Expected: 10 rows (the 10 active accounts). Examples:

   2001: credits 8,010, debits 1,500, net 6,510

   2004: credits 0,     debits 5,050, net -5,050

   2010 and 2012: 0 / 0 / 0 (active accounts with no transactions)

   Grain: one row per active account.

   JOIN: LEFT JOIN, so active accounts with no transactions still show 0.

   Transactions are aggregated in the CTE BEFORE the join, so each

   account joins to at most one row and nothing is double-counted.

   Here WHERE a.Status = 'Active' is correct, because Status is on the

   LEFT table (Accounts) and we only want active accounts.

*/



   ---C3. Show the latest transaction for each account, including accounts without transactions

   
WITH Ranked AS (

    SELECT

        AccountId, TransactionId, TransactionType, Amount, TransactionDate,

        ROW_NUMBER() OVER (

            PARTITION BY AccountId

            ORDER BY TransactionDate DESC, TransactionId DESC

        ) AS rn

    FROM Transactions

)

SELECT

    a.AccountId,

    r.TransactionId,

    r.TransactionType,

    r.Amount,

    r.TransactionDate

FROM Accounts a

LEFT JOIN Ranked r

       ON r.AccountId = a.AccountId

      AND r.rn = 1

ORDER BY a.AccountId;

/* Expected: 14 rows (every account).

   2001 -> 3016 (tied with 3012 on date, the tie-breaker picks 3016)

   2010, 2012, 2013, 2014 -> NULL (no transactions)

   Grain: one row per account.

   JOIN: LEFT JOIN from Accounts, so accounts with no transactions are

   kept. rn = 1 is in the ON clause, not WHERE. In WHERE, the NULL rows

   would be removed and those 4 accounts would disappear.

   TransactionId DESC is the tie-breaker. It is the primary key, so it

   can never tie, and exactly one row gets rn = 1 per account.

*/




   --C4. Identify accounts where total debits exceed total credits

SELECT

    AccountId,

    SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,

    SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits

FROM Transactions

GROUP BY AccountId

HAVING SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END)
> SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END)

ORDER BY AccountId;


/* Expected: 2 rows.

   2004: credits 0, debits 5,050

   2007: credits 0, debits 200

   Grain: one row per flagged account.

   No JOIN is needed. All the information is in Transactions.

   HAVING (not WHERE) is used, because the filter is on totals that only

   exist after GROUP BY.

*/



   --C5. Reconciliation between the internal transaction table  and the external settlement table

  
WITH CoreByRef AS (

    SELECT ReferenceNo, COUNT(*) AS CoreRows, SUM(Amount) AS CoreAmount

    FROM CoreTransactions

    GROUP BY ReferenceNo

),

SettlementByRef AS (

    SELECT ReferenceNo, COUNT(*) AS SettlementRows, SUM(Amount) AS SettlementAmount

    FROM SettlementTransactions

    GROUP BY ReferenceNo

)

SELECT

    COALESCE(c.ReferenceNo, s.ReferenceNo) AS ReferenceNo,

    c.CoreAmount,

    s.SettlementAmount,

    CASE

        WHEN s.ReferenceNo IS NULL                    THEN 'Core Only'

        WHEN c.ReferenceNo IS NULL                    THEN 'Settlement Only'

        WHEN c.CoreRows > 1 OR s.SettlementRows > 1   THEN 'Duplicate Reference'

        WHEN c.CoreAmount <> s.SettlementAmount       THEN 'Amount Mismatch'

        ELSE 'Matched'

    END AS ReconStatus

FROM CoreByRef c

FULL OUTER JOIN SettlementByRef s ON s.ReferenceNo = c.ReferenceNo

ORDER BY ReferenceNo;



/* Expected: 5 rows.

   REF001 -> Duplicate Reference (settlement has it twice)

   REF002 -> Amount Mismatch     (core 200 vs settlement 250)

   REF003 -> Core Only

   REF004 -> Core Only

   REF005 -> Settlement Only

   Grain: one row per ReferenceNo.

   JOIN: FULL OUTER JOIN, because unmatched records from BOTH sides must

   appear. INNER would hide them; LEFT or RIGHT would hide one side.

   Both sides are grouped by ReferenceNo BEFORE the join. Without that,

   the duplicate REF001 would multiply the rows and show REF001 twice as

   "Matched", hiding the problem instead of flagging it.

*/





  -- C6. Grain and JOIN choice for every output


/*

   | Output | Grain                     | JOIN            | Why                                         |

   |--------|---------------------------|-----------------|---------------------------------------------|

   | C1     | one row per customer      | LEFT JOIN       | keep customers with zero active accounts    |

   | C2     | one row per active account| LEFT JOIN       | keep active accounts with no transactions   |

   | C3     | one row per account       | LEFT JOIN       | keep accounts with no transactions          |

   | C4     | one row per flagged acct  | none            | everything needed is in Transactions        |

   | C5     | one row per ReferenceNo   | FULL OUTER JOIN | keep unmatched records from both systems    |

   In every case, child tables were aggregated BEFORE joining, so no

   row could be counted twice.

*/




  -- C7. Validate the report with independent control queries

-- row counts

SELECT COUNT(*) AS Customers_ShouldMatchC1      FROM Customers;                          -- 10

SELECT COUNT(*) AS ActiveAccounts_ShouldMatchC2 FROM Accounts WHERE Status = 'Active';   -- 10

SELECT COUNT(*) AS Accounts_ShouldMatchC3       FROM Accounts;                           -- 14

SELECT COUNT(*) AS References_ShouldMatchC5

FROM (SELECT ReferenceNo FROM CoreTransactions

      UNION

      SELECT ReferenceNo FROM SettlementTransactions) AS refs;                            -- 5



-- credits and debits for active accounts (no join, should match the C2 totals)

SELECT

    SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS ControlCredits,

    SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS ControlDebits

FROM Transactions

WHERE AccountId IN (SELECT AccountId FROM Accounts WHERE Status = 'Active');

-- Expected: credits 177,960, debits 21,775

-- C2 totals, to compare with the control above

WITH Movement AS (

    SELECT AccountId,

        SUM(CASE WHEN TransactionType IN ('Deposit','Transfer') THEN Amount ELSE 0 END) AS TotalCredits,

        SUM(CASE WHEN TransactionType IN ('Withdrawal','Fee')   THEN Amount ELSE 0 END) AS TotalDebits

    FROM Transactions

    GROUP BY AccountId

)

SELECT SUM(COALESCE(m.TotalCredits, 0)) AS ReportCredits,

       SUM(COALESCE(m.TotalDebits, 0))  AS ReportDebits

FROM Accounts a

LEFT JOIN Movement m ON m.AccountId = a.AccountId

WHERE a.Status = 'Active';

-- Expected: credits 177,960, debits 21,775 (same as the control)

-- reconciliation categories, counted a different way

SELECT COUNT(DISTINCT ReferenceNo) AS CoreOnly          -- expected 2

FROM CoreTransactions c

WHERE NOT EXISTS (SELECT 1 FROM SettlementTransactions s WHERE s.ReferenceNo = c.ReferenceNo);

SELECT COUNT(DISTINCT ReferenceNo) AS SettlementOnly    -- expected 1

FROM SettlementTransactions s

WHERE NOT EXISTS (SELECT 1 FROM CoreTransactions c WHERE c.ReferenceNo = s.ReferenceNo);

SELECT COUNT(*) AS DuplicateRefs                        -- expected 1

FROM (SELECT ReferenceNo FROM SettlementTransactions GROUP BY ReferenceNo HAVING COUNT(*) > 1

      UNION

      SELECT ReferenceNo FROM CoreTransactions GROUP BY ReferenceNo HAVING COUNT(*) > 1) AS d;

SELECT COUNT(DISTINCT c.ReferenceNo) AS AmountMismatches -- expected 1

FROM CoreTransactions c

JOIN SettlementTransactions s ON s.ReferenceNo = c.ReferenceNo

WHERE c.Amount <> s.Amount;

/* Validation result:

   | Check                    | Report | Control | Pass? |

   |--------------------------|--------|---------|-------|

   | C1 rows                  | 10     | 10      |       |

   | C2 rows                  | 10     | 10      |       |

   | C3 rows                  | 14     | 14      |       |

   | C5 rows                  | 5      | 5       |       |

   | Active credits           | 177,960| 177,960 |       |

   | Active debits            | 21,775 | 21,775  |       |

   | Core Only / Settl. Only  | 2 / 1  | 2 / 1   |       |

   | Duplicate / Mismatch     | 1 / 1  | 1 / 1   |       |

   Each control query calculates the number in a different way from the

   report, so a bug in the report can't also hide in its check.

*/




  -- C8. Edge cases (at least five)

-- 1. customer without an account

SELECT c.CustomerId, c.FullName

FROM Customers c

WHERE NOT EXISTS (SELECT 1 FROM Accounts a WHERE a.CustomerId = c.CustomerId);

-- expected: 1009, 1010 -> C1 shows them with 0 active accounts

-- 2. account without a transaction

SELECT a.AccountId

FROM Accounts a

WHERE NOT EXISTS (SELECT 1 FROM Transactions t WHERE t.AccountId = a.AccountId);

-- expected: 2010, 2012, 2013, 2014 -> C3 shows them with NULLs

-- 3. duplicate reference

SELECT ReferenceNo, COUNT(*) AS Times

FROM SettlementTransactions

GROUP BY ReferenceNo

HAVING COUNT(*) > 1;

-- expected: REF001 (2 times) -> C5 flags it as Duplicate Reference

-- 4. tied transaction timestamps

SELECT AccountId, TransactionDate, COUNT(*) AS TiedRows

FROM Transactions

GROUP BY AccountId, TransactionDate

HAVING COUNT(*) > 1;

-- expected: account 2001 at 2026-09-22 13:00 -> C3 picks 3016 every time

-- 5. amount mismatch

SELECT c.ReferenceNo, c.Amount AS CoreAmount, s.Amount AS SettlementAmount

FROM CoreTransactions c

JOIN SettlementTransactions s ON s.ReferenceNo = c.ReferenceNo

WHERE c.Amount <> s.Amount;

-- expected: REF002 (200 vs 250) -> C5 flags it as Amount Mismatch




  -- C9. Five-minute explanation

/*

   1. Business requirement (1 min)

      Operations needs to see every customer and account, how money moved

      on each active account, the latest activity, which accounts are

      losing money, and whether our records match the settlement system.

      The rule: nothing can be silently missing or counted twice.

   2. Query design (1.5 min)

      - LEFT JOIN wherever every customer or account must appear.

      - FULL OUTER JOIN for reconciliation, so both sides' unmatched

        records show up.

      - Child tables are aggregated BEFORE joining, so totals can't be

        multiplied.

      - CTEs split each report into clear named steps.

      - ROW_NUMBER with TransactionId as tie-breaker gives exactly one,

        repeatable latest transaction.

   3. Risks (1 min)

      - Join multiplication inflating totals (seen in Part B).

      - A WHERE condition on the right table dropping customers.

      - Tied timestamps giving a random "latest" record.

      - Duplicate references hiding inside a "Matched" result.

      - Credits/debits depend on my stated TransactionType assumption.

   4. Validation approach (1 min)

      Every output was checked against an independent control query that

      calculates the same number a different way: row counts, credit and

      debit totals, and reconciliation category counts all matched.

      I also built five edge cases to prove the report handles them.

   5. Production monitoring (30 sec)

      - Run the control queries every time the report runs, and alert if

        any number doesn't match.

      - Alert when Duplicate Reference or Amount Mismatch rows appear.

      - Track query duration and logical reads over time, so a slowdown

        from data growth is caught early (using the Part A approach).

*/
 