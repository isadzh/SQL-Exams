--1

CREATE DATABASE IB160061_Jun
USE IB160061_Jun

CREATE TABLE Narudzba
(
	NarudzbaID INT CONSTRAINT pk_narudzba PRIMARY KEY (NarudzbaID),
	Kupac NVARCHAR(40),
	PunaAdresa NVARCHAR(80),
	DatumNarudzbe DATE,
	Prevoz MONEY,
	Uposlenik NVARCHAR(40),
	GradUposlenika NVARCHAR(30),
	DatumZaposlenja DATE,
	BrGodStaza INT
)

CREATE TABLE Proizvod
(
	ProizvodID INT CONSTRAINT pk_proizvod PRIMARY KEY(ProizvodID),
	NazivProizvoda NVARCHAR(40),
	NazivDobavljaca NVARCHAR(40),
	StanjeNaSklad INT,
	NarucenaKol INT
)

CREATE TABLE DetaljiNarudzbe
(
	NarudzbaID INT NOT NULL,
	ProizvodID INT NOT NULL,
	CijenaProizvoda MONEY,
	Kolicina INT NOT NULL,
	Popust REAL,
	CONSTRAINT pk_detalji PRIMARY KEY(NarudzbaID,ProizvodID),
	CONSTRAINT fk_narudzba FOREIGN KEY(NarudzbaID) REFERENCES Narudzba(NarudzbaID),
	CONSTRAINT fk_proizvod FOREIGN KEY(ProizvodID) REFERENCES Proizvod(ProizvodID)
)

--2

INSERT INTO Narudzba
SELECT O.OrderID, C.CompanyName, C.Address + ' - ' + C.PostalCode + ' - ' + C.City, O.OrderDate, O.Freight, E.FirstName + ' ' + E.LastName, E.City, E.HireDate, DATEDIFF(YEAR, E.HireDate, GETDATE())
FROM Northwind.dbo.Customers AS C INNER JOIN Northwind.dbo.Orders AS O
	 ON C.CustomerID = O.CustomerID INNER JOIN Northwind.dbo.Employees AS E
	 ON O.EmployeeID = E.EmployeeID

INSERT INTO Proizvod
SELECT P.ProductID, P.ProductName, S.CompanyName, P.UnitsInStock, P.UnitsOnOrder
FROM Northwind.dbo.Products AS P INNER JOIN Northwind.dbo.Suppliers AS S
	 ON P.SupplierID = S.SupplierID
WHERE	P.ProductID IN (SELECT P.ProductID FROM Northwind.dbo.Products)

INSERT INTO DetaljiNarudzbe
SELECT OrderID, ProductID, FLOOR(UnitPrice), Quantity, Discount
FROM Northwind.dbo.[Order Details]

--3

ALTER TABLE Narudzba
ADD SifraUposlenika NVARCHAR(20) CONSTRAINT ck_sifra CHECK(LEN(SifraUposlenika)=15)

UPDATE Narudzba
SET SifraUposlenika=LEFT(REVERSE(GradUposlenika+' '+CONVERT(NVARCHAR(10),DatumZaposlenja)),15)

SELECT * FROM Narudzba

ALTER TABLE Narudzba
DROP CONSTRAINT ck_sifra

UPDATE Narudzba
SET SifraUposlenika = LEFT(NEWID(),20)
WHERE GradUposlenika LIKE '%d'

SELECT * FROM Narudzba

--4

CREATE VIEW view_prvi AS
SELECT N.Uposlenik, N.SifraUposlenika, COUNT(P.NazivProizvoda) AS UkupnoProdatih
FROM Narudzba AS N INNER JOIN DetaljiNarudzbe AS DN
	 ON N.NarudzbaID = DN.NarudzbaID INNER JOIN Proizvod AS P
	 ON P.ProizvodID = DN.ProizvodID
WHERE LEN(N.SifraUposlenika) = 20
GROUP BY N.Uposlenik, N.SifraUposlenika
HAVING COUNT(P.NazivProizvoda) > 2

SELECT * FROM view_prvi
ORDER BY 3 DESC

--5

CREATE PROCEDURE proc_sifraupos AS
BEGIN
	UPDATE Narudzba
	SET SifraUposlenika = LEFT(NEWID(),4)
	WHERE LEN(SifraUposlenika)=20
END

EXEC proc_sifraupos

SELECT * FROM Narudzba

--6

CREATE VIEW view_prodaja AS
SELECT P.NazivProizvoda, ROUND(SUM(DN.CijenaProizvoda * DN.Kolicina * (1-DN.Popust)),2) AS 'Ukupno'
FROM DetaljiNarudzbe AS DN INNER JOIN Proizvod AS P
	 ON DN.ProizvodID = P.ProizvodID
WHERE P.NarucenaKol > 0
GROUP BY P.NazivProizvoda
HAVING ROUND(SUM(DN.CijenaProizvoda * DN.Kolicina * (1-DN.Popust)),2) > 10000

SELECT * FROM view_prodaja
ORDER BY 2 DESC

--7

CREATE VIEW view_srednjacijena AS
SELECT N.Kupac, P.NazivProizvoda, SUM(DN.CijenaProizvoda) AS SumaPoCijeni
FROM Proizvod AS P INNER JOIN DetaljiNarudzbe AS DN
	 ON P.ProizvodID = DN.ProizvodID INNER JOIN Narudzba AS N 
	 ON N.NarudzbaID = DN.NarudzbaID
WHERE DN.CijenaProizvoda > (SELECT AVG(CijenaProizvoda) FROM DetaljiNarudzbe)
GROUP BY N.Kupac, P.NazivProizvoda

SELECT * FROM view_srednjacijena
ORDER BY 3 

CREATE PROCEDURE proc_srednjacijena
(
	@Kupac NVARCHAR(40) = NULL, 
	@NazivProizvoda NVARCHAR(40) = NULL, 
	@SumaPoCijeni MONEY = NULL
)
AS
BEGIN
	SELECT Kupac, NazivProizvoda, SumaPoCijeni
	FROM view_srednjacijena
	WHERE SumaPoCijeni > (SELECT AVG(SumaPoCijeni) FROM view_srednjacijena) AND
		  (@Kupac = Kupac OR @NazivProizvoda = NazivProizvoda OR @SumaPoCijeni = SumaPoCijeni)
	ORDER BY 3
END

EXEC proc_srednjacijena @SumaPoCijeni = 123

EXEC proc_srednjacijena @Kupac = 'Hanari Carnes'

EXEC proc_srednjacijena @NazivProizvoda = 'Côte de Blaye'

--8

CREATE NONCLUSTERED INDEX ix_stanjenasklad ON Proizvod
(
	NazivDobavljaca ASC
) INCLUDE (StanjeNaSklad, NarucenaKol)

SELECT * FROM Proizvod
WHERE NazivDobavljaca = 'Pavlova, Ltd.' AND StanjeNaSklad>10 AND NarucenaKol<10

ALTER INDEX ix_stanjenasklad
ON Proizvod
DISABLE

-- 9

BACKUP DATABASE IB160061_Jun
TO DISK = 'IB160061_Jun.bak'

-- 10

CREATE PROCEDURE proc_brisanje AS
BEGIN
	DROP VIEW view_prvi, view_Ukupno, view_prodaja, view_srednjacijena
	DROP PROCEDURE proc_sifraupos, proc_srednjacijena
END

EXEC proc_brisanje