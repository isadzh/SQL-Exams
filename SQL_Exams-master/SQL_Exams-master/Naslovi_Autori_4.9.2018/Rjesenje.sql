--1

CREATE DATABASE IB160061_Sept2018A

USE IB160061_Sept2018A

--2a

CREATE TABLE Autori
(
	AutorID NVARCHAR(11) PRIMARY KEY,
	Prezime NVARCHAR(25) NOT NULL,
	Ime NVARCHAR(25) NOT NULL,
	Telefon NVARCHAR(20) DEFAULT NULL,
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL
)

CREATE TABLE Izdavaci 
(
	IzdavacID NVARCHAR(4) PRIMARY KEY,
	Naziv NVARCHAR(100) NOT NULL CONSTRAINT uq_naziv UNIQUE,
	Biljeske NVARCHAR(1000) DEFAULT 'Lorem ipsum',
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL
)


CREATE TABLE Naslovi
(
	NaslovID NVARCHAR(6) PRIMARY KEY,
	IzdavacID NVARCHAR(4) CONSTRAINT fk_izdavac FOREIGN KEY(IzdavacID) REFERENCES Izdavaci(IzdavacID),
	Naslov NVARCHAR(100) NOT NULL,
	Cijena MONEY,
	DatumIzdavanja DATE NOT NULL DEFAULT GETDATE(),
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL
)

CREATE TABLE NasloviAutori
(
	AutorID NVARCHAR(11) CONSTRAINT fk_autor FOREIGN KEY(AutorID) REFERENCES Autori(AutorID),
	NaslovID NVARCHAR(6) CONSTRAINT fk_naslov FOREIGN KEY(NaslovID) REFERENCES Naslovi(NaslovID),
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL,
	CONSTRAINT pk_nasaut PRIMARY KEY(AutorID, NaslovID)
)

--2b

INSERT INTO Autori (AutorID, Prezime, Ime)
SELECT au_id, au_lname, au_fname
FROM pubs.dbo.authors
ORDER BY NEWID()

INSERT INTO Izdavaci (IzdavacID, Naziv, Biljeske)
SELECT P.pub_id, P.pub_name, CONVERT(NVARCHAR(100),PI.pr_info)
FROM pubs.dbo.publishers AS P INNER JOIN pubs.dbo.pub_info AS PI
	 ON P.pub_id = PI.pub_id
ORDER BY NEWID()

INSERT INTO Naslovi(NaslovID, IzdavacID, Naslov, Cijena, DatumIzdavanja)
SELECT title_id, pub_id, title, price, pubdate
FROM pubs.dbo.titles

INSERT INTO NasloviAutori(NaslovID, AutorID)
SELECT title_id, au_id
FROM pubs.dbo.titleauthor

--2c

CREATE TABLE Gradovi
(
	GradID INT IDENTITY(5,5) PRIMARY KEY,
	Naziv NVARCHAR(100) NOT NULL CONSTRAINT naziv_uq UNIQUE,
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL
)

INSERT INTO Gradovi(Naziv)
SELECT DISTINCT city
FROM pubs.dbo.authors

ALTER TABLE Autori
ADD GradID INT CONSTRAINT fk_grad FOREIGN KEY(GradID) REFERENCES Gradovi(GradID)

--2d

CREATE PROCEDURE proc_grad10 AS
BEGIN
	UPDATE TOP(10) Autori
	SET GradID = (SELECT GradID FROM Gradovi WHERE Naziv='San Francisco')
END

EXEC proc_grad10

SELECT * FROM Autori

CREATE PROCEDURE proc_gradostali AS
BEGIN
	UPDATE Autori
	SET GradID = (SELECT GradID FROM Gradovi WHERE Naziv='Berkeley')
	WHERE GradID IS NULL
END

EXEC proc_gradostali

SELECT * FROM Autori

--3

CREATE VIEW view_trecizad AS
SELECT A.Prezime+' '+A.Ime AS ImePrezime, G.Naziv, N.Naslov, N.Cijena, I.Naziv AS Inaziv, I.Biljeske
FROM Gradovi AS G INNER JOIN Autori AS A
	 ON G.GradID=A.GradID INNER JOIN NasloviAutori AS NA
	 ON A.AutorID = NA.AutorID INNER JOIN Naslovi AS N
	 ON NA.NaslovID = N.NaslovID INNER JOIN Izdavaci AS I
	 ON I.IzdavacID = N.IzdavacID
WHERE N.Cijena IS NOT NULL AND N.Cijena>10 AND I.Naziv LIKE '%&%' AND G.Naziv = 'San Francisco'

SELECT * FROM view_trecizad

--4

ALTER TABLE Autori
ADD Email NVARCHAR(100) DEFAULT NULL

--5

CREATE PROCEDURE proc_sf AS
BEGIN
	UPDATE Autori
	SET Email = Ime+'.'+Prezime+'@fit.ba'
	WHERE GradID = (SELECT GradID FROM Gradovi WHERE Naziv='San Francisco')
END

EXEC proc_sf

SELECT * FROM Autori

CREATE PROCEDURE proc_berk AS
BEGIN
	UPDATE Autori
	SET Email = Prezime+'.'+Ime+'@fit.ba'
	WHERE GradID = (SELECT GradID FROM Gradovi WHERE Naziv='Berkeley')
END

EXEC proc_berk

SELECT * FROM Autori

--6


SELECT ISNULL(P.Title, 'N/A') AS Titula, P.LastName, P.FirstName, EA.EmailAddress, PP.PhoneNumber, CC.CardNumber, P.FirstName+'.'+P.LastName AS Username, 
	   REPLACE(LOWER(LEFT(NEWID(),16)),'-',7) AS Password
INTO #Anes
FROM AdventureWorks2017.Person.Person AS P INNER JOIN AdventureWorks2017.Person.EmailAddress AS EA
	 ON P.BusinessEntityID = EA.BusinessEntityID INNER JOIN AdventureWorks2017.Person.PersonPhone AS PP
	 ON P.BusinessEntityID = PP.BusinessEntityID LEFT JOIN AdventureWorks2017.Sales.PersonCreditCard AS PCC
	 ON P.BusinessEntityID = PCC.BusinessEntityID LEFT JOIN AdventureWorks2017.Sales.CreditCard AS CC
	 ON PCC.CreditCardID = CC.CreditCardID
ORDER BY P.LastName, P.FirstName

--7

CREATE NONCLUSTERED INDEX ix_index
ON #Anes (Username)
INCLUDE (LastName, FirstName)


SELECT * FROM #Anes
WHERE LastName LIKE '%a%' AND FirstName NOT LIKE 'B%' AND Username NOT LIKE 'A%'

--8

CREATE PROCEDURE proc_brisanjebezkartice AS
BEGIN
	DELETE
	FROM #Anes
	WHERE CardNumber IS NULL
END

EXEC proc_brisanjebezkartice

SELECT * FROM #Anes


--9


BACKUP DATABASE IB160061_Sept2018A
TO DISK = 'IB160061_Sept2018A.bak'

DROP TABLE #Anes

--10a

CREATE PROCEDURE proc_brisanje AS
BEGIN
	ALTER TABLE Autori
	DROP CONSTRAINT fk_grad

	ALTER TABLE Naslovi
	DROP CONSTRAINT fk_izdavac

	ALTER TABLE NasloviAutori
	DROP CONSTRAINT fk_autor

	ALTER TABLE NasloviAutori
	DROP CONSTRAINT fk_naslov

	DELETE FROM Autori
	DELETE FROM Naslovi
	DELETE FROM NasloviAutori
	DELETE FROM Izdavaci
	DELETE FROM Gradovi
END

EXEC proc_brisanje

SELECT * FROM Autori
SELECT * FROM Izdavaci
SELECT * FROM Naslovi
SELECT * FROM NasloviAutori
SELECT * FROM Gradovi

--10b

USE master

RESTORE DATABASE IB160061_Sept2018A 
FROM DISK = 'IB160061_Sept2018A.bak'
 WITH REPLACE

 USE IB160061_Sept2018A

 SELECT * FROM Autori
 SELECT * FROM Izdavaci
 SELECT * FROM Naslovi
 SELECT * FROM NasloviAutori
 SELECT * FROM Gradovi