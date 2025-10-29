README.txt

A1.  Fragment & Recombine Main Fact (≤10 rows) 
 Horizontal Fragmentation and Distributed Query (Claim Table Example)

1. Objective
------------
The purpose of this exercise is to demonstrate horizontal fragmentation of a relational table (Claim)
across two database nodes (Node_A and Node_B) and to validate that the combined distributed view
produces consistent results.

2. Environment Setup
--------------------
- Node_A: local database instance (acts as coordinator)
- Node_B: remote database instance accessible through a database link named proj_link
- Both nodes contain tables with the same structure

3. Implementation Steps
-----------------------

Step 1: Create Horizontally Fragmented Tables
---------------------------------------------
A deterministic fragmentation rule ensures that every row is stored in exactly one fragment.

Example using HASH rule on ClaimID:
  -- On Node_A
  CREATE TABLE Claim_A AS
  SELECT * FROM Claim WHERE MOD(ClaimID, 2) = 0;

  -- On Node_B
  CREATE TABLE Claim_B AS
  SELECT * FROM Claim WHERE MOD(ClaimID, 2) = 1;

Alternatively, using RANGE rule:
  -- On Node_A
  CREATE TABLE Claim_A AS SELECT * FROM Claim WHERE ClaimID <= 5000;
  -- On Node_B
  CREATE TABLE Claim_B AS SELECT * FROM Claim WHERE ClaimID > 5000;

Step 2: Insert Sample Data
--------------------------
Insert a total of up to 10 committed rows, split between Node_A and Node_B (e.g., 5 each).

Example:
  -- On Node_A
  INSERT INTO Claim_A VALUES (100, 'Alice', 4500, '2025-01-12');
  INSERT INTO Claim_A VALUES (102, 'Ben', 3000, '2025-01-13');
  INSERT INTO Claim_A VALUES (104, 'Clara', 5200, '2025-01-15');
  INSERT INTO Claim_A VALUES (106, 'Dan', 2700, '2025-01-17');
  INSERT INTO Claim_A VALUES (108, 'Eva', 6000, '2025-01-19');
  COMMIT;

  -- On Node_B
  INSERT INTO Claim_B VALUES (101, 'Felix', 4100, '2025-01-12');
  INSERT INTO Claim_B VALUES (103, 'Grace', 3500, '2025-01-13');
  INSERT INTO Claim_B VALUES (105, 'Helen', 2400, '2025-01-15');
  INSERT INTO Claim_B VALUES (107, 'Ivan', 2900, '2025-01-17');
  INSERT INTO Claim_B VALUES (109, 'Joy', 7200, '2025-01-19');
  COMMIT;

Step 3: Create Distributed View on Node_A
-----------------------------------------
The global view aggregates both fragments to behave as one logical table.

  CREATE OR REPLACE VIEW Claim_ALL AS
  SELECT * FROM Claim_A
  UNION ALL
  SELECT * FROM Claim_B@proj_link;

Step 4: Validate Data Consistency
---------------------------------
Perform COUNT and checksum validation to ensure the distributed data is consistent.

(a) Count Validation
  SELECT COUNT(*) FROM Claim_A;
  SELECT COUNT(*) FROM Claim_B@proj_link;
  SELECT COUNT(*) FROM Claim_ALL;

(b) Checksum Validation (on ClaimID)
  SELECT SUM(MOD(ClaimID, 97)) FROM Claim_A;
  SELECT SUM(MOD(ClaimID, 97)) FROM Claim_B@proj_link;
  SELECT SUM(MOD(ClaimID, 97)) FROM Claim_ALL;

Results of COUNT and checksum must match between fragments and Claim_ALL.

4. Expected Results
-------------------
Example (if 5 rows per fragment):
  COUNT(Claim_A) = 5
  COUNT(Claim_B) = 5
  COUNT(Claim_ALL) = 10

  SUM(MOD(ClaimID,97)) results should also match Claim_A + Claim_B = Claim_ALL

5. Notes
--------
- Always COMMIT after inserts.
- Ensure the database link proj_link is valid.
- Use UNION ALL because fragments are disjoint.
- Checksum provides numeric integrity verification.

6. Conclusion
-------------
This confirms correct implementation of horizontal fragmentation,
distributed view creation, and integrity validation using COUNT and checksum.




 
A2:  Database Link and Distributed Join (Node_A to Node_B)

1. Objective
------------
This task demonstrates the use of Oracle database links for remote data access and distributed queries.
It includes creating a database link from Node_A to Node_B, verifying remote connectivity, and performing
a distributed join between local and remote tables.

2. Environment Setup
--------------------
- Node_A: local database instance (acts as coordinator)
- Node_B: remote database instance
- Database link name: proj_link
- Sample local table: Claim_A (or base Claim)
- Sample remote tables: Member and Officer

3. Implementation Steps
-----------------------

Step 1: Create Database Link (from Node_A to Node_B)
----------------------------------------------------
Use a valid Node_B service name, username, and password. The link allows Node_A to query Node_B directly.

Example:
  CREATE DATABASE LINK proj_link
  CONNECT TO nodeb_user IDENTIFIED BY nodeb_password
  USING 'NODEB_TNS';

Validation:
  SELECT * FROM dual@proj_link;

If this returns "X", the link is working correctly.

Step 2: Remote SELECT on Member@proj_link
-----------------------------------------
Once the database link is created, verify remote access by selecting up to 5 sample rows.

Example:
  SELECT MemberID, MemberName, JoinDate
  FROM Member@proj_link
  WHERE ROWNUM <= 5;

Expected output:
  - Displays a few rows fetched from the Member table on Node_B.
  - Confirms that Node_A can read data remotely.

Step 3: Distributed Join (Local and Remote Tables)
--------------------------------------------------
Perform a distributed query joining local Claim_A with remote Officer@proj_link.

Example:
  SELECT c.ClaimID, c.MemberName, o.OfficerName, o.Region
  FROM Claim_A c
  JOIN Officer@proj_link o
  ON c.OfficerID = o.OfficerID
  WHERE o.Region = 'North'
  AND ROWNUM <= 10;

Notes:
  - The predicate (e.g., o.Region = 'North') limits rows for performance and clarity.
  - The query joins local and remote data transparently through Oracle’s distributed query engine.
  - The total result set should contain between 3 and 10 rows.

4. Validation and Testing
-------------------------
(a) Verify that the database link proj_link works:
    SELECT * FROM dual@proj_link;

(b) Verify remote access:
    SELECT COUNT(*) FROM Member@proj_link;

(c) Verify distributed join returns valid rows:
    SELECT COUNT(*) FROM (
      SELECT c.ClaimID FROM Claim_A c
      JOIN Officer@proj_link o ON c.OfficerID = o.OfficerID
    );

The above should show a small count (within 3–10 rows).

5. Expected Output
------------------
Sample distributed join result:

| ClaimID | MemberName | OfficerName | Region |
|----------|-------------|--------------|--------|
| 101      | Alice       | John Doe     | North  |
| 102      | Ben         | Sarah Lee    | North  |
| 103      | Clara       | Peter Kim    | North  |

(Example output will vary depending on sample data.)

6. Notes
--------
- Ensure that username, password, and service name are correctly configured for the database link.
- ROWNUM predicate helps control output row count for demonstration purposes.
- Both tables must share compatible data types for the join key (OfficerID in this example).

7. Conclusion
-------------
This exercise demonstrates successful creation of a database link (proj_link), remote querying via Member@proj_link,
and execution of a distributed join between local and remote tables using Oracle distributed database functionality.








A3: Parallel vs Serial Aggregation (≤10 rows data) 




 Serial vs Parallel Aggregation and Execution Plan Analysis

1. Objective
------------
This task demonstrates how to perform aggregation on a distributed view (Claim_ALL) in both serial and
parallel execution modes. It also shows how to analyze execution plans and compare performance statistics.

2. Environment Setup
--------------------
- Node_A: coordinator node where Claim_ALL view is created.
- Claim_ALL: UNION ALL view combining Claim_A (local) and Claim_B@proj_link (remote).
- Dataset: small, ≤10 total rows across fragments.

3. Implementation Steps
-----------------------

Step 1: Run Serial Aggregation
------------------------------
Perform a normal serial aggregation on Claim_ALL, grouped by a domain column such as Region or OfficerID.
The output should contain between 3 and 10 groups.

Example:
  SELECT Region, SUM(ClaimAmount) AS Total_Amount
  FROM Claim_ALL
  GROUP BY Region
  ORDER BY Region;

Expected Result:
  - Produces a few aggregated rows (e.g., 3–10 rows).
  - Runs in serial mode (default).

Step 2: Run Parallel Aggregation
--------------------------------
Force parallel execution using hints even on small data to compare plans.

Example:
  SELECT /*+ PARALLEL(Claim_A,8) PARALLEL(Claim_B,8) */
         Region, SUM(ClaimAmount) AS Total_Amount
  FROM Claim_ALL
  GROUP BY Region
  ORDER BY Region;

Expected Result:
  - Similar output as serial query.
  - Execution plan will show parallel operations for Claim_A and Claim_B fragments.

Step 3: Capture Execution Plans
-------------------------------
Use DBMS_XPLAN to display plan details for both serial and parallel queries.

Example:
  EXPLAIN PLAN FOR
  SELECT Region, SUM(ClaimAmount) FROM Claim_ALL GROUP BY Region;

  SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

For parallel version:
  EXPLAIN PLAN FOR
  SELECT /*+ PARALLEL(Claim_A,8) PARALLEL(Claim_B,8) */
         Region, SUM(ClaimAmount) FROM Claim_ALL GROUP BY Region;

  SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

Step 4: Capture AUTOTRACE Statistics
------------------------------------
Enable AUTOTRACE to compare statistics and resource usage between serial and parallel runs.

Example:
  SET AUTOTRACE ON STATISTICS

  -- Serial
  SELECT Region, SUM(ClaimAmount) FROM Claim_ALL GROUP BY Region;

  -- Parallel
  SELECT /*+ PARALLEL(Claim_A,8) PARALLEL(Claim_B,8) */
         Region, SUM(ClaimAmount) FROM Claim_ALL GROUP BY Region;

Compare the logical reads, physical reads, and CPU time between both runs.

4. Result Comparison Table
--------------------------
Example of summarized comparison:

| Mode      | Plan Summary (from DBMS_XPLAN)               | Key Notes                               |
|------------|----------------------------------------------|------------------------------------------|
| SERIAL     | Full table scan on Claim_ALL, single thread  | Default execution; simple aggregation.   |
| PARALLEL   | Parallel table scan (PX COORDINATOR used)    | Multiple slaves used; small data, so timings nearly equal. |

Observation:
  - Execution times may be similar because dataset is small.
  - Parallel plan confirmed by "PX COORDINATOR" or "PX SEND/RECEIVE" operators in DBMS_XPLAN.

5. Notes
--------
- Parallelism may not improve runtime on tiny datasets but demonstrates concept.
- Use AUTOTRACE and DBMS_XPLAN.DISPLAY to verify query plan behavior.
- Adjust degree of parallelism (e.g., 4 or 8) if 8 is not supported on your environment.

6. Conclusion
-------------
This task illustrates how to compare serial and parallel execution behavior on distributed data.
Even with small data, it confirms correct configuration of parallel query processing
and plan verification through Oracle's DBMS_XPLAN and AUTOTRACE tools.





A4: Two-Phase Commit & Recovery (2 rows) 
README.txt
----------------------------
Project: Distributed Transaction Control with Two-Phase Commit

1. Objective
------------
This task demonstrates Oracle's two-phase commit (2PC) mechanism for distributed transactions.
It covers successful and failed distributed inserts, handling in-doubt transactions, and verifying
consistency between Node_A and Node_B.

2. Environment Setup
--------------------
- Node_A: local database (transaction coordinator)
- Node_B: remote database accessed via proj_link
- Local table: Claim_A (or Claim)
- Remote table: Payment@proj_link (or Claim@proj_link)
- Committed row limit: ≤10 total

3. Implementation Steps
-----------------------

Step 1: Normal Distributed Insert and Commit
--------------------------------------------
Run a PL/SQL block to insert one local and one remote row in the same transaction.

BEGIN
  INSERT INTO Claim_A (ClaimID, MemberName, ClaimAmount, ClaimDate)
  VALUES (201, 'Alice', 4500, SYSDATE);

  INSERT INTO Payment@proj_link (PaymentID, ClaimID, Amount, PaymentDate)
  VALUES (501, 201, 4500, SYSDATE);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Distributed insert committed successfully.');
END;
/

Expected: Both local and remote rows inserted and committed successfully.

Step 2: Simulate Failure to Create In-Doubt Transaction
-------------------------------------------------------
Force a network or link failure during the distributed transaction to create an in-doubt state.

BEGIN
  INSERT INTO Claim_A (ClaimID, MemberName, ClaimAmount, ClaimDate)
  VALUES (202, 'Ben', 3200, SYSDATE);

  INSERT INTO Payment@proj_link (PaymentID, ClaimID, Amount, PaymentDate)
  VALUES (502, 202, 3200, SYSDATE);

  COMMIT; -- May hang or fail due to link error
END;
/

If link fails, Oracle logs an in-doubt transaction visible in DBA_2PC_PENDING.
Rollback any incomplete rows to maintain ≤10 committed rows.

Step 3: Detect and Resolve In-Doubt Transaction
-----------------------------------------------
Query in-doubt transactions:

SELECT LOCAL_TRAN_ID, GLOBAL_TRAN_ID, STATE FROM DBA_2PC_PENDING;

Resolve using COMMIT FORCE or ROLLBACK FORCE:

COMMIT FORCE '1.23.987';
-- or
ROLLBACK FORCE '1.23.987';

Recheck:
SELECT * FROM DBA_2PC_PENDING;

Expected: No pending transactions remain.

Step 4: Repeat Clean Distributed Run
------------------------------------
After cleanup, repeat the distributed insert successfully.

BEGIN
  INSERT INTO Claim_A (ClaimID, MemberName, ClaimAmount, ClaimDate)
  VALUES (203, 'Clara', 5100, SYSDATE);

  INSERT INTO Payment@proj_link (PaymentID, ClaimID, Amount, PaymentDate)
  VALUES (503, 203, 5100, SYSDATE);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Clean distributed transaction committed successfully.');
END;
/

Confirm no entries remain in DBA_2PC_PENDING:
SELECT * FROM DBA_2PC_PENDING;

4. Verification
---------------
| Check | SQL Command | Expected Result |
|--------|--------------|----------------|
| Local Insert | SELECT * FROM Claim_A; | Row visible |
| Remote Insert | SELECT * FROM Payment@proj_link; | Row visible |
| Pending Txns | SELECT * FROM DBA_2PC_PENDING; | None |
| Data Consistency | Matching ClaimID/PaymentID | OK |

5. Notes
--------
- 2PC ensures atomicity across nodes.
- DBA_2PC_PENDING lists unresolved distributed transactions.
- COMMIT FORCE or ROLLBACK FORCE manually resolves in-doubt transactions.
- Always verify both nodes after resolution.
- Keep total committed rows ≤10 for this exercise.

6. Conclusion
-------------
This exercise demonstrates distributed transaction control in Oracle using two-phase commit.
It covers successful distributed inserts, controlled failure handling, in-doubt resolution, and
data consistency verification across multiple database nodes.



A5: Distributed Lock Conflict & Diagnosis (no extra rows) 





----------------------------
 Distributed Locking and Concurrency Demonstration

1. Objective
------------
This task demonstrates how Oracle handles **row-level locks** in a distributed environment across multiple nodes.
It shows how a second session waits when a row is locked by another session, and how to verify and release locks.

2. Environment Setup
--------------------
- Node_A: local database (coordinator)
- Node_B: remote database accessible via proj_link
- Tables: Claim or Payment
- Row budget: ≤10 total rows (reuse existing rows)

3. Implementation Steps
-----------------------

Step 1: Open Session 1 on Node_A
--------------------------------
Begin a transaction on Node_A that updates a single row and **keep it open (do not commit or rollback yet)**.

Example:
-- Session 1 (Node_A)
UPDATE Claim
SET ClaimAmount = ClaimAmount + 100
WHERE ClaimID = 101;
-- Do NOT COMMIT yet

sql
Copy code

Step 2: Open Session 2 on Node_B
--------------------------------
From Node_B, attempt to update the **same logical row** via the database link.

Example:
-- Session 2 (Node_B)
UPDATE Claim@proj_link
SET ClaimAmount = ClaimAmount + 200
WHERE ClaimID = 101;

vbnet
Copy code
Expected: This session will **wait** because the row is locked by Session 1.

Step 3: Query Lock Views on Node_A
----------------------------------
Use lock monitoring views to show blocking and waiting sessions.

Example:
-- Check blockers and waiters
SELECT * FROM DBA_BLOCKERS;
SELECT * FROM DBA_WAITERS;

-- Check detailed locks
SELECT * FROM V$LOCK;

pgsql
Copy code

Observation: You should see Session 2 waiting for the lock held by Session 1.

Step 4: Release the Lock
------------------------
Commit or rollback Session 1 to release the lock.

-- Session 1
COMMIT; -- or ROLLBACK;

pgsql
Copy code

After releasing the lock, Session 2 will complete its update successfully.

Step 5: Verification
--------------------
- Query the updated row to confirm both updates are applied in sequence.
SELECT ClaimID, ClaimAmount FROM Claim WHERE ClaimID = 101;

markdown
Copy code

- Ensure no additional rows were inserted; total rows remain ≤10.

4. Notes
--------
- This task demonstrates **distributed row-level locking** and how Oracle enforces consistency.
- DBA_BLOCKERS and DBA_WAITERS help visualize which sessions are blocked.
- V$LOCK shows detailed lock information including session IDs, type, and mode.
- Always release locks promptly to avoid blocking other sessions.

5. Conclusion
-------------
This exercise confirms the behavior of distributed locks in Oracle:
- A second session waits when a row is locked by another session.
- Locks can be monitored and resolved.
- Data consistency is maintained across nodes without inserting extra rows.




B6: Declarative Rules Hardening (≤10 committed rows) 


README.txt
----------------------------
 Declarative Constraints and Data Validation on Claim and Payment Tables

1. Objective
------------
This task demonstrates how to enforce **data integrity** using NOT NULL and CHECK constraints
on the Claim and Payment tables. It includes testing both valid and invalid inserts,
ensuring errors are handled cleanly, and maintaining a total row budget of ≤10.

2. Environment Setup
--------------------
- Tables: Claim and Payment
- Constraints: NOT NULL for mandatory fields, CHECK for domain rules such as:
  - Positive amounts (ClaimAmount, PaymentAmount)
  - Valid status values (e.g., 'OPEN', 'CLOSED')
  - Logical date order (StartDate ≤ EndDate)
- Committed row limit: ≤10 total

3. Implementation Steps
-----------------------

Step 1: Add or Verify Constraints
---------------------------------
Example for Claim table:
ALTER TABLE Claim
MODIFY ClaimAmount NUMBER NOT NULL;

ALTER TABLE Claim
ADD CONSTRAINT chk_claim_amount CHECK (ClaimAmount > 0);

ALTER TABLE Claim
ADD CONSTRAINT chk_claim_status CHECK (Status IN ('OPEN', 'CLOSED'));

ALTER TABLE Claim
ADD CONSTRAINT chk_claim_dates CHECK (StartDate <= EndDate);

css
Copy code

Example for Payment table:
ALTER TABLE Payment
MODIFY PaymentAmount NUMBER NOT NULL;

ALTER TABLE Payment
ADD CONSTRAINT chk_payment_amount CHECK (PaymentAmount > 0);

ALTER TABLE Payment
ADD CONSTRAINT chk_payment_status CHECK (Status IN ('PENDING', 'PAID'));

markdown
Copy code

Step 2: Prepare Passing and Failing Inserts
-------------------------------------------
- **Passing Inserts**: satisfy all constraints
-- Claim passing
INSERT INTO Claim (ClaimID, MemberName, ClaimAmount, Status, StartDate, EndDate)
VALUES (101, 'Alice', 4500, 'OPEN', DATE '2025-01-10', DATE '2025-01-15');

-- Payment passing
INSERT INTO Payment (PaymentID, ClaimID, PaymentAmount, Status, PaymentDate)
VALUES (201, 101, 4500, 'PAID', DATE '2025-01-12');

markdown
Copy code

- **Failing Inserts**: violate one or more constraints, wrapped in a block to rollback
BEGIN
-- Claim failing: negative amount
INSERT INTO Claim (ClaimID, MemberName, ClaimAmount, Status, StartDate, EndDate)
VALUES (102, 'Ben', -3000, 'OPEN', DATE '2025-01-10', DATE '2025-01-15');

-- Claim failing: invalid status
INSERT INTO Claim (ClaimID, MemberName, ClaimAmount, Status, StartDate, EndDate)
VALUES (103, 'Clara', 5200, 'INVALID', DATE '2025-01-10', DATE '2025-01-15');

ROLLBACK;
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('Claim insert failed as expected: ' || SQLERRM);
END;
/

BEGIN
-- Payment failing: negative amount
INSERT INTO Payment (PaymentID, ClaimID, PaymentAmount, Status, PaymentDate)
VALUES (202, 101, -4500, 'PAID', DATE '2025-01-12');

-- Payment failing: invalid status
INSERT INTO Payment (PaymentID, ClaimID, PaymentAmount, Status, PaymentDate)
VALUES (203, 101, 4500, 'INVALID', DATE '2025-01-12');

ROLLBACK;
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('Payment insert failed as expected: ' || SQLERRM);
END;
/

markdown
Copy code

Step 3: Verification
--------------------
- Query tables to confirm only passing rows are committed:
SELECT * FROM Claim;
SELECT * FROM Payment;

sql
Copy code

- Ensure total committed rows stay ≤10.
- Observe clean error messages for failing inserts via DBMS_OUTPUT.

4. Notes
--------
- NOT NULL ensures mandatory fields cannot be left empty.
- CHECK constraints enforce domain-specific rules (amounts, statuses, dates).
- Wrapping failing inserts in a PL/SQL block with ROLLBACK prevents invalid data from persisting.
- This maintains overall data integrity and keeps total committed rows within budget.

5. Conclusion
-------------
This exercise validates declarative constraints on Claim and Payment tables:
- Correctly enforced NOT NULL and CHECK rules
- Clean handling of failed inserts with rollback
- Successful inserts remain committed
- Maintains a consistent, valid dataset for further operations



B7: E–C–A Trigger for Denormalized Totals (small DML set) 


 Claim Audit Trigger and Statement-Level Totals

1. Objective
------------
This task demonstrates the use of **statement-level triggers** in Oracle to maintain
denormalized totals in a parent table (Claim) based on changes in a child table (Payment),
and logs changes to an audit table.

2. Environment Setup
--------------------
- Child table: Payment
- Parent table: Claim (contains total amounts)
- Audit table: Claim_AUDIT
- Committed row limit: ≤10 total
- Dataset: small, ≤4 rows affected in testing

3. Implementation Steps
-----------------------

Step 1: Create Audit Table
--------------------------
CREATE TABLE Claim_AUDIT (
bef_total NUMBER,
aft_total NUMBER,
changed_at TIMESTAMP DEFAULT SYSTIMESTAMP,
key_col VARCHAR2(64)
);

pgsql
Copy code

Step 2: Implement Statement-Level Trigger on Payment
---------------------------------------------------
Trigger fires **AFTER INSERT, UPDATE, DELETE** and recalculates totals in Claim.
It also logs before/after totals to Claim_AUDIT.

CREATE OR REPLACE TRIGGER trg_payment_totals
AFTER INSERT OR UPDATE OR DELETE ON Payment
DECLARE
v_before_total NUMBER;
v_after_total NUMBER;
BEGIN
-- Compute before total (optional: can query before change if needed)
SELECT SUM(Amount) INTO v_before_total FROM Claim; -- simplified example

-- Recompute totals in Claim
UPDATE Claim c
SET TotalAmount = (SELECT SUM(p.Amount) FROM Payment p WHERE p.ClaimID = c.ClaimID);

-- Compute after total
SELECT SUM(TotalAmount) INTO v_after_total FROM Claim;

-- Log to audit table
INSERT INTO Claim_AUDIT(bef_total, aft_total, changed_at, key_col)
VALUES (v_before_total, v_after_total, SYSTIMESTAMP, 'Claim totals');
END;
/

vbnet
Copy code

Step 3: Execute Mixed DML Script
---------------------------------
Apply a small number of inserts, updates, or deletes on Payment (≤4 rows) to test trigger.

Example:
-- Insert new payment
INSERT INTO Payment(PaymentID, ClaimID, Amount, Status, PaymentDate)
VALUES (301, 101, 500, 'PAID', SYSDATE);

-- Update existing payment
UPDATE Payment
SET Amount = Amount + 100
WHERE PaymentID = 302;

-- Delete a payment
DELETE FROM Payment
WHERE PaymentID = 303;

COMMIT;

pgsql
Copy code

Step 4: Verify Audit Table
--------------------------
Check that the audit table has 2–3 rows capturing before/after totals.

SELECT * FROM Claim_AUDIT;

markdown
Copy code

Step 5: Verify Claim Totals
---------------------------
Ensure Claim.TotalAmount reflects the sum of associated Payment rows.

SELECT ClaimID, TotalAmount FROM Claim;

markdown
Copy code

4. Notes
--------
- Trigger is **statement-level**, fires once per DML statement regardless of number of rows affected.
- Audit table captures net change for each DML statement on Payment.
- Keep total committed rows ≤10 across all exercises.
- This approach ensures denormalized totals are always up to date without per-row triggers.

5. Conclusion
-------------
This exercise demonstrates:
- Statement-level triggers to maintain aggregated totals
- Logging of before/after totals to an audit table
- Handling small DML changes in a controlled dataset
- Maintaining overall data integrity and traceability





B8: Recursive Hierarchy Roll-Up (6–10 rows)
----------------------------
 Hierarchical Query and Rollup Computation

1. Objective
------------
This task demonstrates the creation and querying of a **natural hierarchy** in Oracle using
a recursive WITH (CTE) query. It also shows how to compute rollups by joining hierarchical
data to a parent table (e.g., Claim).

2. Environment Setup
--------------------
- Hierarchy table: HIER(parent_id, child_id)
- Parent table: Claim
- Row budget: ≤10 total committed rows
- Dataset: 6–10 rows forming a 3-level hierarchy

3. Implementation Steps
-----------------------

Step 1: Create Hierarchy Table
------------------------------
CREATE TABLE HIER (
parent_id NUMBER NOT NULL,
child_id NUMBER NOT NULL
);

sql
Copy code

Step 2: Insert Hierarchy Data
-----------------------------
Insert 6–10 rows forming a 3-level hierarchy (root → mid → leaf).

Example:
INSERT INTO HIER VALUES (NULL, 1); -- Level 1 root
INSERT INTO HIER VALUES (1, 2); -- Level 2
INSERT INTO HIER VALUES (1, 3);
INSERT INTO HIER VALUES (2, 4); -- Level 3
INSERT INTO HIER VALUES (2, 5);
INSERT INTO HIER VALUES (3, 6);
COMMIT;

pgsql
Copy code
- This forms a hierarchy of 3 levels with 6 rows.  
- Use existing seed rows to stay within ≤10 committed rows.

Step 3: Recursive WITH Query
----------------------------
Use a recursive CTE to produce `(child_id, root_id, depth)`.

WITH RECURSIVE hier_cte (child_id, root_id, depth) AS (
SELECT child_id, child_id AS root_id, 1 AS depth
FROM HIER
WHERE parent_id IS NULL
UNION ALL
SELECT h.child_id, c.root_id, c.depth + 1
FROM HIER h
JOIN hier_cte c ON h.parent_id = c.child_id
)
SELECT child_id, root_id, depth
FROM hier_cte;

vbnet
Copy code

Step 4: Compute Rollups with Claim
----------------------------------
Join hierarchy to Claim (or parent table) to compute rollups.

Example:
SELECT h.child_id, h.root_id, h.depth, SUM(c.ClaimAmount) AS total_claim
FROM hier_cte h
JOIN Claim c ON c.ClaimID = h.child_id
GROUP BY h.child_id, h.root_id, h.depth
ORDER BY root_id, depth;

markdown
Copy code

- Returns 6–10 rows depending on hierarchy and data.  
- Aggregates claim amounts along the hierarchy.

4. Notes
--------
- Recursive WITH (CTE) simplifies hierarchical queries in Oracle.  
- Maintain the ≤10 committed rows limit by reusing existing seed rows.  
- This approach allows rollups and aggregation by root or parent node.

5. Conclusion
-------------
This exercise demonstrates:
- Creating and populating a natural hierarchical table
- Writing recursive queries to traverse the hierarchy
- Joining hierarchy to parent table (Claim) for aggregation and rollups
- Maintaining controlled dataset within the committed row limit







B9: Mini-Knowledge Base with Transitive Inference (≤10 facts) 


Recursive Inference with TRIPLE Table and Transitive isA*

1. Objective
------------
This task demonstrates the use of a **TRIPLE table** to store domain facts and implements
recursive inference using a **transitive isA\*** query. Labels are applied to base records,
and a small set of inferred rows is returned.

2. Environment Setup
--------------------
- Table: TRIPLE(s VARCHAR2(64), p VARCHAR2(64), o VARCHAR2(64))
- Row budget: ≤10 total committed rows (including TRIPLE)
- Dataset: 8–10 domain facts forming simple hierarchies or rule implications

3. Implementation Steps
-----------------------

Step 1: Create TRIPLE Table
---------------------------
CREATE TABLE TRIPLE (
s VARCHAR2(64),
p VARCHAR2(64),
o VARCHAR2(64)
);

sql
Copy code

Step 2: Insert Domain Facts
---------------------------
Insert 8–10 rows representing simple type hierarchies or rule implications.

Example:
INSERT INTO TRIPLE VALUES ('Car', 'isA', 'Vehicle');
INSERT INTO TRIPLE VALUES ('Truck', 'isA', 'Vehicle');
INSERT INTO TRIPLE VALUES ('Sedan', 'isA', 'Car');
INSERT INTO TRIPLE VALUES ('SUV', 'isA', 'Car');
INSERT INTO TRIPLE VALUES ('ElectricCar', 'isA', 'Car');
INSERT INTO TRIPLE VALUES ('Vehicle', 'isA', 'Transport');
INSERT INTO TRIPLE VALUES ('Bicycle', 'isA', 'Transport');
INSERT INTO TRIPLE VALUES ('Motorbike', 'isA', 'Vehicle');
COMMIT;

pgsql
Copy code

Step 3: Recursive Inference Query (Transitive isA\*)
---------------------------------------------------
Use a recursive WITH query to infer all transitive relationships.

WITH RECURSIVE isa_cte (sub, obj, label) AS (
SELECT s, o, s AS label
FROM TRIPLE
WHERE p = 'isA'
UNION ALL
SELECT t.s, c.obj, c.label
FROM TRIPLE t
JOIN isa_cte c ON t.o = c.sub
WHERE t.p = 'isA'
)
SELECT sub, obj, label
FROM isa_cte
WHERE ROWNUM <= 10;

sql
Copy code

- Returns up to 10 labeled rows, showing inferred relationships along the isA hierarchy.  

Step 4: Maintain Row Budget
---------------------------
- Total committed rows including TRIPLE ≤10.  
- Delete temporary rows after demonstration if needed:

DELETE FROM TRIPLE;
COMMIT;

sql
Copy code

4. Notes
--------
- TRIPLE table allows storing generic subject-predicate-object facts.  
- Recursive CTE implements transitive closure (isA*) for inference.  
- Limit output using `ROWNUM <= 10` to control result size.  
- Temporary rows can be removed to respect overall project row budget.

5. Conclusion
-------------
This exercise demonstrates:
- Creation and population of a TRIPLE table with domain facts
- Recursive inference using transitive isA* relationships
- Application of labels to base facts
- Controlled dataset size within ≤10 committed rows






B10: Business Limit Alert (Function + Trigger) (row-budget safe) 



 Business Limits Enforcement with Trigger and Validation Function

1. Objective
------------
This task demonstrates how to enforce **business rules** on a table (Payment or Claim)
using a lookup table, a PL/SQL function, and a trigger that validates DML operations.
It also includes testing passing and failing cases while maintaining a total committed row budget ≤10.

2. Environment Setup
--------------------
- Table: BUSINESS_LIMITS(rule_key VARCHAR2(64), threshold NUMBER, active CHAR(1))
- Function: fn_should_alert(...)
- Trigger: BEFORE INSERT OR UPDATE on Payment (or relevant table)
- Row budget: ≤10 total committed rows

3. Implementation Steps
-----------------------

Step 1: Create BUSINESS_LIMITS Table and Seed Rule
--------------------------------------------------
CREATE TABLE BUSINESS_LIMITS (
rule_key VARCHAR2(64),
threshold NUMBER,
active CHAR(1) CHECK(active IN ('Y','N'))
);

-- Insert exactly one active rule
INSERT INTO BUSINESS_LIMITS(rule_key, threshold, active)
VALUES ('MAX_PAYMENT', 5000, 'Y');

COMMIT;

sql
Copy code

Step 2: Implement Validation Function
-------------------------------------
Function checks current Payment or Claim data against BUSINESS_LIMITS.

CREATE OR REPLACE FUNCTION fn_should_alert(p_amount NUMBER) RETURN NUMBER IS
v_threshold NUMBER;
BEGIN
SELECT threshold INTO v_threshold
FROM BUSINESS_LIMITS
WHERE rule_key = 'MAX_PAYMENT' AND active = 'Y';

IF p_amount > v_threshold THEN
RETURN 1; -- violation
ELSE
RETURN 0; -- no violation
END IF;
END;
/

pgsql
Copy code

Step 3: Create Trigger on Payment
---------------------------------
Trigger fires BEFORE INSERT OR UPDATE and raises an error if function returns 1.

CREATE OR REPLACE TRIGGER trg_payment_limit
BEFORE INSERT OR UPDATE ON Payment
FOR EACH ROW
BEGIN
IF fn_should_alert(:NEW.Amount) = 1 THEN
RAISE_APPLICATION_ERROR(-20001, 'Payment exceeds business limit.');
END IF;
END;
/

markdown
Copy code

Step 4: Demonstrate Passing and Failing DML
-------------------------------------------
- **Passing Inserts/Updates** (amount ≤ threshold)
INSERT INTO Payment(PaymentID, ClaimID, Amount, Status, PaymentDate)
VALUES (401, 101, 4000, 'PAID', SYSDATE);

UPDATE Payment SET Amount = 4500 WHERE PaymentID = 401;

COMMIT;

markdown
Copy code

- **Failing Inserts/Updates** (amount > threshold), wrapped in a block with ROLLBACK
BEGIN
INSERT INTO Payment(PaymentID, ClaimID, Amount, Status, PaymentDate)
VALUES (402, 102, 6000, 'PAID', SYSDATE);
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('Failed insert as expected: ' || SQLERRM);
ROLLBACK;
END;
/

BEGIN
UPDATE Payment SET Amount = 7000 WHERE PaymentID = 401;
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('Failed update as expected: ' || SQLERRM);
ROLLBACK;
END;
/

markdown
Copy code

Step 5: Verification
--------------------
- Query Payment to confirm only passing rows are committed:

SELECT * FROM Payment;

sql
Copy code

- Ensure total committed rows ≤10.

4. Notes
--------
- BUSINESS_LIMITS table stores active rules and thresholds.
- fn_should_alert() encapsulates the business logic for validation.
- BEFORE INSERT OR UPDATE trigger enforces limits in real-time.
- Failing DML cases are rolled back to prevent exceeding limits.
- DBMS_OUTPUT shows clean error messages for violations.

5. Conclusion
-------------
This exercise demonstrates:
- Enforcing business rules using a reference table and PL/SQL function
- Real-time validation with a BEFORE trigger
- Handling failing DML gracefully with rollback
- Maintaining total committed rows within the project budget (≤10)







