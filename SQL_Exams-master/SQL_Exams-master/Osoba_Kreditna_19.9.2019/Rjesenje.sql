-- 1a

CREATE DATABASE IB160061_Sept2

USE IB160061_Sept2

-- 1b

CREATE TABLE Kreditna
(
	KreditnaID INT CONSTRAINT pk_kreditna PRIMARY KEY(KreditnaID),
	br_kreditne NVARCHAR(25) NOT NULL,
	dtm_evid DATE NOT NULL
)

CREATE TABLE Osoba
(
	OsobaID INT CONSTRAINT pk_osoba PRIMARY KEY(OsobaID),
	KreditnaID INT NOT NULL,
	mail_lozinka NVARCHAR(128) NOT NULL,
	lozinka NVARCHAR(10) NOT NULL,
	br_tel NVARCHAR(25) NOT NULL,
	CONSTRAINT fk_kreditna FOREIGN KEY(KreditnaID) REFERENCES Kreditna(KreditnaID)
)

CREATE TABLE Narudzba
(
	NarudzbaID INT CONSTRAINT pk_narudzba PRIMARY KEY(NarudzbaID),
	KreditnaID INT,
	br_narudzbe NVARCHAR(25),
	br_racuna NVARCHAR(15),
	prodavnicaID INT,
	CONSTRAINT fk_kreditnanarudzba FOREIGN KEY(KreditnaID) REFERENCES Kreditna(KreditnaID)
)

-- 2a

INSERT INTO Kreditna
SELECT CC.CreditCardID, CC.CardNumber, CC.ModifiedDate
FROM AdventureWorks2017.Sales.CreditCard AS CC

-- 2b

INSERT INTO Osoba
SELECT PP.BusinessEntityID, PCC.CreditCardID, PPW.PasswordHash, PPW.PasswordSalt, PPH.PhoneNumber
FROM AdventureWorks2017.Person.Password AS PPW INNER JOIN AdventureWorks2017.Person.Person AS PP
	 ON PPW.BusinessEntityID = PP.BusinessEntityID INNER JOIN AdventureWorks2017.Sales.PersonCreditCard AS PCC
	 ON PCC.BusinessEntityID = PP.BusinessEntityID INNER JOIN AdventureWorks2017.Person.PersonPhone AS PPH
	 ON PPH.BusinessEntityID = PP.BusinessEntityID

-- 2c

INSERT INTO Narudzba
SELECT SOH.SalesOrderID, SOH.CreditCardID, SOH.PurchaseOrderNumber, SOH.AccountNumber, C.StoreID
FROM AdventureWorks2017.Sales.Customer AS C INNER JOIN AdventureWorks2017.Sales.SalesOrderHeader AS SOH
	 ON C.CustomerID = SOH.CustomerID

-- 3

CREATE VIEW view_kred_mail AS
SELECT RIGHT(K.br_kreditne,11) AS Novi_Broj_Kreditne, SUBSTRING(O.mail_lozinka,10,34) AS Nova_Mail_Lozinka, O.br_tel, LEN(O.br_tel) AS Broj_cifara_telefona
FROM Osoba AS O INNER JOIN Kreditna AS K
	 ON O.KreditnaID = K.KreditnaID

SELECT * FROM view_kred_mail

-- 4 

CREATE PROCEDURE proc_osoba
(
	@OsobaID INT = NULL,
	@KreditnaID INT = NULL,
	@mail_lozinka NVARCHAR(128) = NULL,
	@lozinka NVARCHAR(10) = NULL,
	@br_tel NVARCHAR(25) = NULL
) 
AS
BEGIN
	SELECT OsobaID, KreditnaID, mail_lozinka, lozinka, br_tel
	FROM Osoba
	WHERE br_tel LIKE '%(%' AND
		  (OsobaID = @OsobaID OR
		   KreditnaID = @KreditnaID OR
		   mail_lozinka = @mail_lozinka OR
		   lozinka = @lozinka OR
		   br_tel = @br_tel )
END

EXEC proc_osoba @br_tel = '1 (11) 500 555-0132'

-- 5a

SELECT * INTO Kreditna1
FROM Kreditna

-- 5b

ALTER TABLE Kreditna1
ADD dtm_izmjene DATETIME NOT NULL DEFAULT(GETDATE())

-- 6a

UPDATE Kreditna1
SET br_kreditne = LEFT(NEWID(),25)
WHERE LEFT(br_kreditne,1) IN (1,3)

-- 6b

SELECT COUNT(DATEDIFF(YEAR,dtm_evid,dtm_izmjene)) AS Broj_datuma
FROM Kreditna1
WHERE DATEDIFF(YEAR, dtm_evid, dtm_izmjene) <= 6

-- 6c

DROP TABLE Kreditna1

-- 7a

UPDATE Narudzba
SET br_narudzbe = LEFT(NEWID(),25)
WHERE br_narudzbe IS NULL

-- 7b

UPDATE Narudzba
SET prodavnicaID = RIGHT(NarudzbaID,3)
WHERE prodavnicaID IS NULL AND LEFT(NarudzbaID,1) IN (4,5)

-- 7c

UPDATE Narudzba
SET prodavnicaID = RIGHT(NarudzbaID,4)
WHERE prodavnicaID IS NULL AND LEFT(NarudzbaID,1) IN (6,7)

-- 8

CREATE PROCEDURE proc_skracivanje
AS
BEGIN
	UPDATE Narudzba
	SET br_narudzbe = SUBSTRING(br_narudzbe,3,22)
	WHERE LEN(br_narudzbe) < 25
END

EXEC proc_skracivanje

-- 9a

CREATE VIEW view_agregacija
AS
SELECT LEN(br_narudzbe) AS Duzina_broja_narudzbe, COUNT(LEN(br_narudzbe)) AS Prebrojano
FROM Narudzba 
WHERE LEN(br_narudzbe) < 25
GROUP BY LEN(br_narudzbe)

SELECT * FROM view_agregacija

-- 9b

SELECT MIN(Prebrojano), MAX(Prebrojano), AVG(Prebrojano)
FROM view_agregacija

SELECT Duzina_broja_narudzbe, Prebrojano
FROM view_agregacija
WHERE Prebrojano > (SELECT AVG(Prebrojano) FROM view_agregacija)

-- 10a

BACKUP DATABASE IB160061_Sept2
TO DISK = 'IB160061_Sept2.bak'

-- 10b

USE master
DROP DATABASE IB160061_Sept2