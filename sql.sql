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
