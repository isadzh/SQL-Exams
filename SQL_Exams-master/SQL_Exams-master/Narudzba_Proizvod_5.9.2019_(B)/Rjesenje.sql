--1 

CREATE DATABASE IB160061_SeptB
GO

USE IB160061_SeptB
GO

CREATE TABLE Produkt 
(
	produktID INT CONSTRAINT pk_produkt PRIMARY KEY(produktID),
	jed_cijena MONEY,
	kateg_naziv NVARCHAR(15),
	mj_jedinica NVARCHAR(20),
	dobavljac_naziv NVARCHAR(40),
	dobavljac_post_br NVARCHAR(10)
)

CREATE TABLE Narudzba
(
	narudzbaID INT CONSTRAINT pk_narudzba PRIMARY KEY(narudzbaID),
	dtm_narudzbe DATE,
	dtm_isporuke DATE,
	grad_isporuke NVARCHAR(15),
	klijentID NVARCHAR(5),
	klijent_naziv NVARCHAR(40),
	prevoznik_naziv NVARCHAR(40)
)

CREATE TABLE Narudzba_Produkt
(
	narudzbaID INT NOT NULL,
	produktID INT NOT NULL,
	uk_cijena MONEY,
	CONSTRAINT pk_nar_pro PRIMARY KEY(narudzbaID, produktID),
	CONSTRAINT fk_narudzba FOREIGN KEY(narudzbaID) REFERENCES Narudzba(narudzbaID),
	CONSTRAINT fk_produkt FOREIGN KEY(produktID) REFERENCES Produkt(produktID)
)

--2

INSERT INTO Produkt
SELECT P.ProductID, P.UnitPrice, C.CategoryName, P.QuantityPerUnit, S.CompanyName, S.PostalCode
FROM Northwind.dbo.Categories AS C INNER JOIN Northwind.dbo.Products AS P
	 ON C.CategoryID = P.CategoryID INNER JOIN Northwind.dbo.Suppliers AS S
	 ON S.SupplierID = P.SupplierID

INSERT INTO Narudzba
SELECT O.OrderID, O.OrderDate, O.ShippedDate, O.ShipCity, C.CustomerID, C.CompanyName, S.CompanyName
FROM Northwind.dbo.Customers AS C INNER JOIN Northwind.dbo.Orders AS O
	 ON C.CustomerID = O.CustomerID INNER JOIN Northwind.dbo.Shippers AS S
	 ON O.ShipVia=S.ShipperID

INSERT INTO Narudzba_Produkt
SELECT OrderID, ProductID, UnitPrice * Quantity AS uk_cijena
FROM Northwind.dbo.[Order Details]
WHERE Discount=0.05

--3

CREATE VIEW view_uk_cijena AS
SELECT N.narudzbaID, N.klijentID, FLOOR(NP.uk_cijena) AS 'Cijeli dio', ((NP.uk_cijena - FLOOR(NP.uk_cijena))*100) AS 'Decimalni dio'
FROM Narudzba AS N INNER JOIN Narudzba_Produkt AS NP
	 ON N.narudzbaID = NP.narudzbaID

SELECT * FROM view_uk_cijena

SELECT narudzbaID, klijentID, [Cijeli dio], [Decimalni dio], [Cijeli dio]+1 AS 'Nova cijena' INTO nova_uk_cijena
FROM view_uk_cijena
WHERE [Decimalni dio]>49

SELECT * FROM nova_uk_cijena

--4

GO
CREATE PROCEDURE proc_uk_cijena
(
	@narudzbaID INT = NULL,
	@klijentID NVARCHAR(5) = NULL,
	@cijeli_dio DECIMAL(5,2) = NULL,
	@decimalni_dio DECIMAL(5,2) = NULL,
	@nova_cijena DECIMAL(5,2) = NULL
)
AS
BEGIN
	SELECT narudzbaID, klijentID, [Cijeli dio], [Decimalni dio], [Nova cijena]
	FROM nova_uk_cijena
	WHERE narudzbaID = @narudzbaID OR 
		  klijentID = @klijentID OR
		  [Cijeli dio] = @cijeli_dio OR
		  [Decimalni dio] = @decimalni_dio OR
		  [Nova cijena] = @nova_cijena
END

EXEC proc_uk_cijena @narudzbaID = 10730

EXEC proc_uk_cijena @klijentID = ERNSH

--5 

GO
CREATE PROCEDURE proc_startcifra
AS
BEGIN
	SELECT dobavljac_post_br, COUNT(dobavljac_post_br) AS 'Broj po postanskom'
	FROM Produkt
	WHERE LEFT(dobavljac_post_br, 1) LIKE '[0-9]'
	GROUP BY dobavljac_post_br
END

EXEC proc_startcifra

-- 6

CREATE VIEW view_brojnarudzbi AS
SELECT klijent_naziv, COUNT(klijent_naziv) AS 'Broj narudzbi po klijentu'
FROM Narudzba
GROUP BY klijent_naziv


SELECT * FROM view_brojnarudzbi

SELECT MAX([Broj narudzbi po klijentu]) AS 'Maximalni broj narudzbe'
FROM view_brojnarudzbi

SELECT klijent_naziv, [Broj narudzbi po klijentu], (SELECT MAX([Broj narudzbi po klijentu]) FROM view_brojnarudzbi) - [Broj narudzbi po klijentu] AS 'Razlika'
FROM view_brojnarudzbi
WHERE [Broj narudzbi po klijentu] <> (SELECT MAX([Broj narudzbi po klijentu]) FROM view_brojnarudzbi)

--7

ALTER TABLE Produkt
ADD Lozinka NVARCHAR(20)

CREATE PROCEDURE proc_lozinka AS
BEGIN
	UPDATE Produkt
	SET Lozinka = REVERSE(RIGHT(mj_jedinica,4) + dobavljac_post_br)
	WHERE dobavljac_post_br NOT LIKE '[A-Z]%' AND dobavljac_post_br NOT LIKE '%[A-Z]%' AND dobavljac_post_br NOT LIKE '%[A-Z]'

	UPDATE Produkt 
	SET Lozinka = REVERSE(LEFT(NEWID(),20))
	WHERE dobavljac_post_br LIKE '[A-Z]%' OR dobavljac_post_br LIKE '%[A-Z]%' OR dobavljac_post_br  LIKE '%[A-Z]'
END

EXEC proc_lozinka

SELECT * FROM Produkt

--8

CREATE VIEW view_isporuka AS
SELECT P.produktID, P.dobavljac_naziv, N.grad_isporuke, DATEDIFF(DAY,dtm_narudzbe, dtm_isporuke) AS 'Dana do isporuke'
FROM Produkt AS P INNER JOIN Narudzba_Produkt AS NP 
	 ON P.produktID = NP.produktID INNER JOIN Narudzba AS N
	 ON NP.narudzbaID = N.narudzbaID
WHERE DATEDIFF(DAY,dtm_narudzbe,dtm_isporuke) <= 28

SELECT * FROM view_isporuka

SELECT * INTO Isporuka FROM view_isporuka

--9

ALTER TABLE Isporuka
ADD red_br_sedmice NVARCHAR(10)

UPDATE Isporuka
SET red_br_sedmice = 'Prva'
WHERE [Dana do isporuke] <= 7

UPDATE Isporuka
SET red_br_sedmice = 'Druga'
WHERE [Dana do isporuke] BETWEEN 8 AND 14

UPDATE Isporuka 
SET red_br_sedmice = 'Treca'
WHERE [Dana do isporuke] BETWEEN 15 AND 21

UPDATE Isporuka
SET red_br_sedmice = 'Cetvrta'
WHERE [Dana do isporuke] BETWEEN 22 AND 28

SELECT red_br_sedmice, COUNT(red_br_sedmice)
FROM Isporuka
GROUP BY red_br_sedmice

--10

BACKUP DATABASE IB160061_SeptB
TO DISK = 'IB160061_SeptB.bak'

CREATE PROCEDURE proc_delete
AS
BEGIN
	DROP VIEW view_uk_cijena
	DROP PROCEDURE proc_lozinka, proc_startcifra, proc_uk_cijena
END

EXEC proc_delete