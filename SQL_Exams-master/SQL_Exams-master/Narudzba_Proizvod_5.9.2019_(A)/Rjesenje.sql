--------------------------------------------------------------------

--1

CREATE DATABASE IB160061_Sept
GO
USE IB160061_Sept

CREATE TABLE Narudzba
(
	narudzbaID INT CONSTRAINT pk_Narudzba PRIMARY KEY(narudzbaID),
	dtm_narudzbe DATE,
	dtm_isporuke DATE,
	prevoz MONEY,
	klijentID NVARCHAR(5),
	klijent_naziv NVARCHAR(40),
	prevoznik_naziv NVARCHAR(40)
)

CREATE TABLE Proizvod
(
	proizvodID INT CONSTRAINT pk_proizvod PRIMARY KEY(proizvodID),
	mj_jedinica NVARCHAR(20),
	jed_cijena MONEY,
	kateg_naziv NVARCHAR(15),
	dobavljac_naziv NVARCHAR(40),
	dobavljac_web TEXT
)

CREATE TABLE Narudzba_Proizvod
(
	narudzbaID INT NOT NULL,
	proizvodID INT NOT NULL,
	uk_cijena MONEY,
	CONSTRAINT pk_narpro PRIMARY KEY(narudzbaID, proizvodID),
	CONSTRAINT fk_narudzba FOREIGN KEY(narudzbaID) REFERENCES Narudzba(narudzbaID),
	CONSTRAINT fk_proizvod FOREIGN KEY(proizvodID) REFERENCES Proizvod(proizvodID)
)

--------------------------------------------------------------------

--2

INSERT INTO Narudzba
SELECT O.OrderID, O.OrderDate, O.ShippedDate, O.Freight, C.CustomerID, C.CompanyName, S.CompanyName
FROM Northwind.dbo.Customers AS C INNER JOIN Northwind.dbo.Orders AS O
	ON C.CustomerID = O.CustomerID INNER JOIN Northwind.dbo.Shippers AS S
	ON S.ShipperID = O.ShipVia

INSERT INTO Proizvod
SELECT P.ProductID, P.QuantityPerUnit, P.UnitPrice, C.CategoryName, S.CompanyName, S.HomePage
FROM Northwind.dbo.Categories AS C INNER JOIN Northwind.dbo.Products AS P
	 ON C.CategoryID = P.CategoryID INNER JOIN Northwind.dbo.Suppliers AS S
	 ON S.SupplierID = P.SupplierID

INSERT INTO Narudzba_Proizvod
SELECT OD.OrderID, OD.ProductID, OD.UnitPrice * OD.Quantity AS uk_cijena
FROM Northwind.dbo.[Order Details] AS OD
WHERE OD.Discount=0

--------------------------------------------------------------------

--3

CREATE VIEW view_kolicina AS
SELECT P.proizvodID, P.kateg_naziv, P.jed_cijena, NP.uk_cijena, (NP.uk_cijena / P.jed_cijena) AS kolicina
FROM Narudzba_Proizvod AS NP INNER JOIN Proizvod AS P
	 ON NP.proizvodID = P.proizvodID
WHERE (NP.uk_cijena / P.jed_cijena)%1=0


SELECT * FROM view_kolicina 

--------------------------------------------------------------------

-- 4

CREATE PROCEDURE proc_kolicina
(
	@proizvodID INT = NULL,
	@kateg_naziv NVARCHAR(15) = NULL,
	@jed_cijena MONEY=NULL,
	@uk_cijena MONEY=NULL,
	@kolicina DECIMAL(5,2) = NULL
)
AS
BEGIN
	SELECT proizvodID, kateg_naziv, jed_cijena, uk_cijena, kolicina
	FROM view_kolicina
	WHERE proizvodID = @proizvodID OR
		  kateg_naziv = @kateg_naziv OR
		  jed_cijena = @jed_cijena OR
		  uk_cijena = @uk_cijena OR
		  kolicina = @kolicina
END

EXEC proc_kolicina @kateg_naziv = 'Produce'

EXEC proc_kolicina @kateg_naziv = 'Beverages'

--------------------------------------------------------------------

--5

CREATE PROCEDURE proc_prebrojavanje AS
BEGIN
	SELECT kateg_naziv, COUNT(kateg_naziv)
	FROM view_kolicina
	GROUP BY kateg_naziv
END

EXEC proc_prebrojavanje

--------------------------------------------------------------------

--6

CREATE VIEW view_suma AS
SELECT narudzbaID, SUM(uk_cijena) AS suma
FROM Narudzba_Proizvod
GROUP BY narudzbaID

SELECT * FROM view_suma

SELECT ROUND(AVG(suma),2)
FROM view_suma

SELECT narudzbaID, suma, suma - (SELECT ROUND(AVG(suma),2) FROM view_suma) AS razlika
FROM view_suma
WHERE suma > (SELECT avg(suma) FROM view_suma)

--------------------------------------------------------------------

--7

ALTER TABLE Narudzba
ADD evid_br NVARCHAR(30)

CREATE PROCEDURE proc_evidbr AS
BEGIN
	UPDATE Narudzba
	SET evid_br = LEFT(NEWID(),30)
	WHERE dtm_isporuke IS NULL
	UPDATE Narudzba
	SET evid_br = CONVERT(NVARCHAR,dtm_isporuke) + '-' + CONVERT(NVARCHAR,dtm_narudzbe)
	WHERE dtm_isporuke IS NOT NULL
END

EXEC proc_evidbr

SELECT * FROM Narudzba

--------------------------------------------------------------------

--8

CREATE PROCEDURE proc_kateg_rijec AS
BEGIN
	SELECT N.narudzbaID, N.klijent_naziv, P.proizvodID, P.kateg_naziv, P.dobavljac_naziv
	FROM Narudzba AS N INNER JOIN Narudzba_Proizvod AS NP
		 ON N.narudzbaID = NP.narudzbaID INNER JOIN Proizvod AS P
		 ON P.proizvodID = NP.proizvodID
	WHERE CHARINDEX(' ', P.kateg_naziv) = 0 AND CHARINDEX('/', P.kateg_naziv) = 0
END

EXEC proc_kateg_rijec

--------------------------------------------------------------------

--9

-- jedna rijec

UPDATE Proizvod
SET dobavljac_web='www.'+dobavljac_naziv+'.com'
WHERE (CHARINDEX(' ',dobavljac_naziv)-1) < 0

-- vise rijeci

UPDATE Proizvod
SET dobavljac_web='www.'+LEFT(dobavljac_naziv, (CHARINDEX(' ',dobavljac_naziv)-1))+'.com'
WHERE (CHARINDEX(' ',dobavljac_naziv)-1) >= 0

-- provjera

SELECT * FROM Proizvod

--------------------------------------------------------------------

--10

BACKUP DATABASE IB160061_Sept
TO DISK = 'IB160061_Sept.bak'

CREATE PROCEDURE proc_delete AS
BEGIN
	DROP VIEW view_kolicina, view_suma
	DROP PROCEDURE proc_evidbr, proc_kateg_rijec, proc_prebrojavanje, proc_kolicina
END

EXEC proc_delete