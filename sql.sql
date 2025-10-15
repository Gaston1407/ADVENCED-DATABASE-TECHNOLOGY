#1. Create Tables with Constraints
-- 1. Member Table
CREATE TABLE Member (
    MemberID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Gender VARCHAR(10) CHECK (Gender IN ('Male', 'Female')),
    Contact VARCHAR(20),
    Address VARCHAR(100),
    JoinDate DATE NOT NULL
);

-- 2. Officer Table
CREATE TABLE Officer (
    OfficerID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Branch VARCHAR(50),
    Contact VARCHAR(20),
    Role VARCHAR(50)
);

-- 3. LoanAccount Table
CREATE TABLE LoanAccount (
    LoanID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    OfficerID INT NOT NULL,
    Amount NUMERIC(12,2) NOT NULL,
    InterestRate NUMERIC(5,2),
    StartDate DATE,
    Status VARCHAR(20) CHECK (Status IN ('Active','Closed','Defaulted')) DEFAULT 'Active',
    FOREIGN KEY (MemberID) REFERENCES Member(MemberID),
    FOREIGN KEY (OfficerID) REFERENCES Officer(OfficerID)
);


-- 4. InsurancePolicy Table
CREATE TABLE InsurancePolicy (
    PolicyID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Type VARCHAR(50),
    Premium NUMERIC(10,2),
    StartDate DATE,
    EndDate DATE,
    Status VARCHAR(20) CHECK (Status IN ('Active','Expired','Closed')) DEFAULT 'Active',
    FOREIGN KEY (MemberID) REFERENCES Member(MemberID)
);

-- 5. Claim Table
CREATE TABLE Claim (
    ClaimID SERIAL PRIMARY KEY,
    PolicyID INT NOT NULL,
    DateFiled DATE,
    AmountClaimed NUMERIC(10,2),
    Status VARCHAR(20) CHECK (Status IN ('Pending','Approved','Rejected','Settled')) DEFAULT 'Pending',
    FOREIGN KEY (PolicyID) REFERENCES InsurancePolicy(PolicyID)
);

-- 6. Payment Table
CREATE TABLE Payment (
    PaymentID SERIAL PRIMARY KEY,
    ClaimID INT UNIQUE,
    Amount NUMERIC(10,2),
    PaymentDate DATE,
    Method VARCHAR(30),
    FOREIGN KEY (ClaimID) REFERENCES Claim(ClaimID)
        ON DELETE CASCADE
);
# 2 Insert Sample Data
INSERT INTO Member (FullName, Gender, Contact, Address, JoinDate)
VALUES
('John Mukasa', 'Male', '078900001', 'Kigali', '2024-01-10'),
('Alice Uwase', 'Female', '078900002', 'Huye', '2024-02-05'),
('Peter Niyonzima', 'Male', '078900003', 'Musanze', '2024-03-12'),
('Grace Ndayishimiye', 'Female', '078900004', 'Rubavu', '2024-04-15'),
('Eric Habimana', 'Male', '078900005', 'Rwamagana', '2024-05-20');

INSERT INTO InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
VALUES
(1, 'Life', 50000, '2025-01-01', '2025-12-31', 'Active'),
(2, 'Health', 30000, '2025-03-01', '2025-09-01', 'Active'),
(2, 'Loan Protection', 25000, '2025-02-01', '2025-07-01', 'Expired');


#3. Retrieve All Active Insurance Policies
SELECT * 
FROM InsurancePolicy
WHERE Status = 'Active';

#4 Update Claim Status After Settlement

UPDATE Claim
SET Status = 'Settled'
WHERE ClaimID = 1;  -- change ID as needed


# 5. Identify Members with Multiple Insurance Policies

SELECT m.FullName, COUNT(p.PolicyID) AS PolicyCount
FROM Member m
JOIN InsurancePolicy p ON m.MemberID = p.MemberID
GROUP BY m.MemberID, m.FullName
HAVING COUNT(p.PolicyID) > 1;

#6. View for Total Premiums Collected Per Month
CREATE OR REPLACE VIEW MonthlyPremiums AS
SELECT 
    TO_CHAR(StartDate, 'YYYY-MM') AS Month,
    SUM(Premium) AS TotalPremiums
FROM InsurancePolicy
GROUP BY TO_CHAR(StartDate, 'YYYY-MM')
ORDER BY Month
SELECT * FROM MonthlyPremiums;

#7 Trigger to Auto-Close Policy After End Date

CREATE OR REPLACE FUNCTION close_expired_policies()
RETURNS TRIGGER AS $$
BEGIN
    -- If the end date has passed, set policy status to 'Closed'
    IF NEW.EndDate < CURRENT_DATE THEN
        NEW.Status := 'Closed';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_close_policy_after_enddate
BEFORE UPDATE ON InsurancePolicy
FOR EACH ROW
EXECUTE FUNCTION close_expired_policies();




