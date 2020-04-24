--1

CREATE DATABASE IB160061_Sept2018

USE IB160061_Sept2018

--2a

CREATE TABLE Autori
(
	AutorID NVARCHAR(11),
	Prezime NVARCHAR(25) NOT NULL,
	Ime NVARCHAR(25) NOT NULL,
	ZipKod NVARCHAR(5) DEFAULT NULL,
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL,
	CONSTRAINT pk_autori PRIMARY KEY(AutorID)
)

CREATE TABLE Izdavaci
(
	IzdavacID NVARCHAR(4),
	Naziv NVARCHAR(100) NOT NULL CONSTRAINT naziv_uq UNIQUE,
	Biljeske NVARCHAR(1000) DEFAULT 'Lorem Ipsum',
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL,
	CONSTRAINT pk_izdavaci PRIMARY KEY(IzdavacID)
)

CREATE TABLE Naslovi
(
	NaslovID NVARCHAR(6),
	IzdavacID NVARCHAR(4),
	Naslov NVARCHAR(100) NOT NULL,
	Cijena MONEY,
	Biljeske NVARCHAR(200) DEFAULT 'The quick brown fox jumps over the lazy dog',
	DatumIzdavanja DATE NOT NULL DEFAULT GETDATE(),
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL,
	CONSTRAINT pk_naslov PRIMARY KEY(NaslovID),
	CONSTRAINT fk_izdavac FOREIGN KEY(IzdavacID) REFERENCES Izdavaci(IzdavacID)
)

CREATE TABLE NasloviAutori
(
	AutorID NVARCHAR(11),
	NaslovID NVARCHAR(6),
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL,
	CONSTRAINT pk_nasloviautori PRIMARY KEY(AutorID, NaslovID),
	CONSTRAINT fk_autor FOREIGN KEY(AutorID) REFERENCES Autori(AutorID),
	CONSTRAINT fk_naslov FOREIGN KEY(NaslovID) REFERENCES Naslovi(NaslovID)
)

--2b

INSERT INTO Autori (AutorID, Prezime, Ime, ZipKod)
SELECT au_id, au_lname, au_fname, zip
FROM pubs.dbo.authors 
ORDER BY NEWID()

SELECT * FROM Autori

INSERT INTO Izdavaci (IzdavacID, Naziv, Biljeske)
SELECT  P.pub_id, P.pub_name, SUBSTRING(PI.pr_info,0,100)
FROM pubs.dbo.publishers AS P INNER JOIN pubs.dbo.pub_info AS PI
	 ON P.pub_id = PI.pub_id
ORDER BY NEWID()

SELECT * FROM Izdavaci

INSERT INTO Naslovi(NaslovID,IzdavacID, Naslov, Cijena, Biljeske, DatumIzdavanja)
SELECT title_id, pub_id, title, price, notes, pubdate
FROM pubs.dbo.titles
WHERE notes IS NOT NULL

SELECT * FROM Naslovi

INSERT INTO NasloviAutori(AutorID, NaslovID)
SELECT au_id, title_id
FROM pubs.dbo.titleauthor

SELECT * FROM NasloviAutori

--2c

CREATE TABLE Gradovi
(
	GradID INT IDENTITY(1,2) PRIMARY KEY,
	Naziv NVARCHAR(100) NOT NULL UNIQUE,
	DatumKreiranjaZapisa DATE NOT NULL DEFAULT GETDATE(),
	DatumModifikovanjaZapisa DATE DEFAULT NULL
)

INSERT INTO Gradovi(Naziv)
SELECT DISTINCT city
FROM pubs.dbo.authors

ALTER TABLE Autori
ADD GradID INT CONSTRAINT fk_grad FOREIGN KEY(GradID) REFERENCES Gradovi(GradID)


--2d

CREATE PROCEDURE proc_autgrdtoppet AS
BEGIN
	UPDATE TOP(5) Autori
	SET GradID = ( SELECT GradID FROM Gradovi WHERE Naziv='Salt Lake City')	
END

EXEC proc_autgrdtoppet

SELECT TOP(5) * FROM Autori

CREATE PROCEDURE proc_autgrdostali AS
BEGIN
	UPDATE Autori
	SET GradID = (SELECT GradID FROM Gradovi WHERE Naziv='Oakland')
	WHERE GradID IS NULL
END

EXEC proc_autgrdostali

SELECT * FROM Autori

--3

CREATE VIEW view_autorisve AS
SELECT A.Prezime + ' ' + A.Ime AS ImePrezime, G.Naziv, N.Naslov, N.Cijena, N.Biljeske, I.Naziv AS 'Naziv Izdavaca'
FROM Autori AS A INNER JOIN Gradovi AS G
	 ON A.GradID = G.GradID INNER JOIN NasloviAutori AS NA
	 ON A.AutorID = NA.AutorID INNER JOIN Naslovi AS N
	 ON N.NaslovID = NA.NaslovID INNER JOIN Izdavaci AS I
	 ON I.IzdavacID = N.IzdavacID
WHERE N.Cijena IS NOT NULL AND N.Cijena>5 AND I.Naziv NOT LIKE '%&%' AND G.Naziv = 'Salt Lake City'

SELECT * FROM view_autorisve

--4

ALTER TABLE Autori
ADD Email NVARCHAR(100) DEFAULT NULL

--5

CREATE PROCEDURE proc_oak AS
BEGIN
	UPDATE Autori
	SET Email = Prezime+'.'+Ime+'@fit.ba'
	WHERE GradID = (SELECT GradID FROM Gradovi WHERE Naziv='Oakland')
END

EXEC proc_oak

SELECT * FROM Autori

CREATE PROCEDURE proc_slc AS
BEGIN
	UPDATE Autori
	SET Email = Ime + '.' + Prezime + '@fit.ba'
	WHERE GradID = (SELECT GradID FROM Gradovi WHERE Naziv='Salt Lake City')
END

EXEC proc_slc

SELECT * FROM Autori

--6

SELECT ISNULL(P.Title, 'N/A') AS Titula, P.LastName, P.FirstName, EA.EmailAddress, PP.PhoneNumber, CC.CardNumber, P.FirstName+'.'+P.LastName AS Username, 
	   REPLACE(LOWER(LEFT(NEWID(),24)),'-',7) AS Password
INTO #Anes
FROM AdventureWorks2017.Person.Person AS P INNER JOIN AdventureWorks2017.Person.EmailAddress AS EA
	 ON P.BusinessEntityID = EA.BusinessEntityID INNER JOIN AdventureWorks2017.Person.PersonPhone AS PP
	 ON P.BusinessEntityID = PP.BusinessEntityID LEFT JOIN AdventureWorks2017.Sales.PersonCreditCard AS PCC
	 ON P.BusinessEntityID = PCC.BusinessEntityID LEFT JOIN AdventureWorks2017.Sales.CreditCard AS CC
	 ON PCC.CreditCardID = CC.CreditCardID
ORDER BY P.LastName, P.FirstName

SELECT * FROM #Anes

--7

CREATE NONCLUSTERED INDEX ix_index
ON #Anes (LastName, FirstName)
INCLUDE (Username)

SELECT * FROM #Anes
WHERE LastName LIKE '%a%' AND FirstName NOT LIKE 'B%' AND Username NOT LIKE 'A%'

--8

CREATE PROCEDURE proc_brisanjesakarticom AS
BEGIN
	DELETE
	FROM #Anes
	WHERE CardNumber IS NOT NULL
END

EXEC proc_brisanjesakarticom

SELECT * FROM #Anes

--9

BACKUP DATABASE IB160061_Sept2018
TO DISK = 'IB160061_Sept2018.bak'

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

RESTORE DATABASE IB160061_Sept2018 
FROM DISK = 'IB160061_Sept2018.bak'
 WITH REPLACE

 USE IB160061_Sept2018

 SELECT * FROM Autori
 SELECT * FROM Izdavaci
 SELECT * FROM Naslovi
 SELECT * FROM NasloviAutori
 SELECT * FROM Gradovi