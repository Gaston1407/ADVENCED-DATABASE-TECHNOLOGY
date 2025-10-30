-- Distributed Schema
 Design and 
Fragmentation for Sacco insurance and member extension system 
 
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1. Distributed Schema Design and Fragmentation
-- Create two schemas representing two SACCO branches
CREATE SCHEMA IF NOT EXISTS sacco_a;
CREATE SCHEMA IF NOT EXISTS sacco_b;

-- Member table: horizontally fragmented by member_id parity (odd -> sacco_a, even -> sacco_b)
CREATE TABLE sacco_a.members (
    member_id    integer PRIMARY KEY,
    full_name    text NOT NULL,
    id_number    text UNIQUE,
    phone        text,
    joined_date  date DEFAULT current_date,
    branch_code  text DEFAULT 'A'
);

CREATE TABLE sacco_b.members (
    member_id    integer PRIMARY KEY,
    full_name    text NOT NULL,
    id_number    text UNIQUE,
    phone        text,
    joined_date  date DEFAULT current_date,
    branch_code  text DEFAULT 'B'
);

-- Insurance policies (each branch holds policies for its members)
CREATE TABLE sacco_a.policies (
    policy_id    serial PRIMARY KEY,
    member_id    integer NOT NULL,
    policy_type  text NOT NULL,
    premium      numeric(12,2) NOT NULL,
    start_date   date,
    end_date     date
);

CREATE TABLE sacco_b.policies (
    policy_id    serial PRIMARY KEY,
    member_id    integer NOT NULL,
    policy_type  text NOT NULL,
    premium      numeric(12,2) NOT NULL,
    start_date   date,
    end_date     date
);

-- Claims table (fragmented similarly)
CREATE TABLE sacco_a.claims (
    claim_id     serial PRIMARY KEY,
    policy_id    integer NOT NULL,
    member_id    integer NOT NULL,
    amount       numeric(12,2),
    claim_date   date DEFAULT current_date,
    status       text DEFAULT 'PENDING'
);

CREATE TABLE sacco_b.claims (
    claim_id     serial PRIMARY KEY,
    policy_id    integer NOT NULL,
    member_id    integer NOT NULL,
    amount       numeric(12,2),
    claim_date   date DEFAULT current_date,
    status       text DEFAULT 'PENDING'
);

-- Contributions table (payments into SACCO savings/insurance)
CREATE TABLE sacco_a.contributions (
    contribution_id serial PRIMARY KEY,
    member_id integer NOT NULL,
    amount numeric(12,2),
    paid_at timestamptz DEFAULT now()
);

CREATE TABLE sacco_b.contributions (
    contribution_id serial PRIMARY KEY,
    member_id integer NOT NULL,
    amount numeric(12,2),
    paid_at timestamptz DEFAULT now()
);

-- Seed small sample data (total <= 10 across both branches)
INSERT INTO sacco_a.members(member_id, full_name, id_number, phone) VALUES
(1,'Alice Niyonzima','1001001','0788000001'),
(3,'Charles Musekura','1001003','0788000003'),
(5,'Eunice Byiringiro','1001005','0788000005');

INSERT INTO sacco_b.members(member_id, full_name, id_number, phone) VALUES
(2,'Brian Kayumba','1001002','0788000002'),
(4,'Diana Mukamana','1001004','0788000004');

INSERT INTO sacco_a.policies(member_id, policy_type, premium, start_date, end_date) VALUES
(1,'Life',100.00,'2025-01-01','2026-01-01'),
(3,'Accident',50.00,'2025-03-01','2026-03-01');

INSERT INTO sacco_b.policies(member_id, policy_type, premium, start_date, end_date) VALUES
(2,'Life',120.00,'2025-02-01','2026-02-01'),
(4,'Health',80.00,'2025-04-01','2026-04-01');

INSERT INTO sacco_a.contributions(member_id, amount) VALUES (1,200.00),(3,150.00);
INSERT INTO sacco_b.contributions(member_id, amount) VALUES (2,300.00),(4,100.00);

-- 2. Create and Use Database Links (postgres_fdw)
-- Create a foreign server representing sacco_b accessible from sacco_a
CREATE SERVER IF NOT EXISTS srv_sacco_b
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'localhost', dbname current_database(), port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
  SERVER srv_sacco_b
  OPTIONS (user CURRENT_USER);

-- Expose sacco_b tables as foreign tables in sacco_a schema to simulate remote access
DROP FOREIGN TABLE IF EXISTS sacco_a.remote_members;
CREATE FOREIGN TABLE sacco_a.remote_members (
    member_id integer,
    full_name text,
    id_number text,
    phone text,
    joined_date date,
    branch_code text
) SERVER srv_sacco_b OPTIONS (schema_name 'sacco_b', table_name 'members');

DROP FOREIGN TABLE IF EXISTS sacco_a.remote_policies;
CREATE FOREIGN TABLE sacco_a.remote_policies (
    policy_id integer,
    member_id integer,
    policy_type text,
    premium numeric,
    start_date date,
    end_date date
) SERVER srv_sacco_b OPTIONS (schema_name 'sacco_b', table_name 'policies');

DROP FOREIGN TABLE IF EXISTS sacco_a.remote_claims;
CREATE FOREIGN TABLE sacco_a.remote_claims (
    claim_id integer,
    policy_id integer,
    member_id integer,
    amount numeric,
    claim_date date,
    status text
) SERVER srv_sacco_b OPTIONS (schema_name 'sacco_b', table_name 'claims');

-- Example remote SELECT and distributed join (run in sacco_a):
-- SELECT a.member_id, a.full_name AS local_name, r.full_name AS remote_name
-- FROM sacco_a.members a
-- LEFT JOIN sacco_a.remote_members r ON a.member_id = r.member_id;

-- 3. Parallel Query Execution
-- Create a synthetic large table for performance testing (transactions/claims)
DROP TABLE IF EXISTS public.big_claims;
CREATE TABLE public.big_claims AS
SELECT
    gs AS claim_tx_id,
    (random()*10000)::numeric(12,2) AS amount,
    (now() - (random()*10000||' seconds')::interval) AS created_at
FROM generate_series(1,250000) gs;

ANALYZE public.big_claims;

-- Example commands to compare serial vs parallel:
-- SET max_parallel_workers_per_gather = 0;
-- EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM public.big_claims WHERE amount > 5000;
-- SET max_parallel_workers_per_gather = 4;
-- EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM public.big_claims WHERE amount > 5000;

-- 4. Two-Phase Commit Simulation (PREPARE / COMMIT PREPARED)
-- To simulate a distributed insert across sacco_a and sacco_b:
-- Session 1 (on sacco_a):
-- BEGIN;
-- INSERT INTO sacco_a.claims(policy_id, member_id, amount) VALUES (1,1,250.00);
-- PREPARE TRANSACTION 'tx_sacco_a_claim_1';
--
-- Session 2 (on sacco_b):
-- BEGIN;
-- INSERT INTO sacco_b.claims(policy_id, member_id, amount) VALUES (1,2,300.00);
-- PREPARE TRANSACTION 'tx_sacco_b_claim_1';
--
-- Coordinator (once both prepared):
-- COMMIT PREPARED 'tx_sacco_a_claim_1';
-- COMMIT PREPARED 'tx_sacco_b_claim_1';
--
-- Inspect prepared transactions:
-- SELECT * FROM pg_prepared_xacts;

-- 5. Distributed Rollback and Recovery (simulate coordinator failure)
-- If coordinator fails, inspect prepared transactions:
-- SELECT gid, database, prepared, owner, transaction FROM pg_prepared_xacts;
-- To rollback a prepared tx:
-- ROLLBACK PREPARED 'tx_sacco_a_claim_1';

-- 6. Distributed Concurrency Control
-- Prepare a row for locking demo
INSERT INTO sacco_a.members(member_id, full_name, id_number, phone) VALUES (11,'Lock Demo','1001011','0788000011')
  ON CONFLICT DO NOTHING;

-- Steps to demonstrate lock conflict (run in separate sessions):
-- Session 1:
-- BEGIN;
-- UPDATE sacco_a.members SET phone='0781111111' WHERE member_id=11;
-- -- keep transaction open
--
-- Session 2:
-- BEGIN;
-- UPDATE sacco_a.members SET phone='0782222222' WHERE member_id=11;
-- -- this will block until Session1 finishes
--
-- Inspect locks:
-- SELECT pid, locktype, mode, granted, relation::regclass
-- FROM pg_locks l LEFT JOIN pg_class c ON l.relation = c.oid
-- WHERE relation IS NOT NULL;

-- 7. Parallel Data Loading / ETL Simulation
DROP TABLE IF EXISTS public.etl_contributions;
CREATE TABLE public.etl_contributions (
    id serial PRIMARY KEY,
    member_id integer,
    amount numeric,
    created_at timestamptz DEFAULT now()
);

-- Simulate parallel loading using concurrent sessions:
-- Session A: INSERT INTO public.etl_contributions(member_id, amount) SELECT (1 + (random()*100)::int), random()*1000 FROM generate_series(1,50000);
-- Session B: INSERT INTO public.etl_contributions(member_id, amount) SELECT (1 + (random()*100)::int), random()*1000 FROM generate_series(1,50000);
-- Then:
-- EXPLAIN (ANALYZE, BUFFERS) SELECT count(*), avg(amount) FROM public.etl_contributions;

-- 8. Three-Tier Architecture Note
-- Presentation: Web UI (e.g., React) for members & claims
-- Application: API layer (Node.js/Python) to implement business logic & talk to DB(s)
-- Database: PostgreSQL nodes (sacco_a, sacco_b) + FDW for cross-node queries

-- 9. Distributed Query Optimization
-- Create foreign table for sacco_b.policies in sacco_a for distributed join example
DROP FOREIGN TABLE IF EXISTS sacco_a.remote_policies;
CREATE FOREIGN TABLE sacco_a.remote_policies (
    policy_id integer,
    member_id integer,
    policy_type text,
    premium numeric,
    start_date date,
    end_date date
) SERVER srv_sacco_b OPTIONS (schema_name 'sacco_b', table_name 'policies');

-- Distributed join example (run in sacco_a):
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT a.member_id, a.full_name, r.policy_type, r.premium
-- FROM sacco_a.members a
-- JOIN sacco_a.remote_policies r ON a.member_id = r.member_id



