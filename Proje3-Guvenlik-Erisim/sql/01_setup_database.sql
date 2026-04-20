/* ============================================================================
   Proje 3 - Adım 01: Güvenlik Projesi Veritabanı Kurulumu
   ----------------------------------------------------------------------------
   Amaç : Hassas veri içeren (TC Kimlik No, Maaş, İletişim) örnek bir kurum
          personel veritabanı oluşturmak. Tüm güvenlik senaryoları bu DB
          üzerinde denenecek.
   ============================================================================ */

USE master;
GO

IF DB_ID(N'PersonelDB') IS NOT NULL
BEGIN
    ALTER DATABASE PersonelDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PersonelDB;
END
GO

CREATE DATABASE PersonelDB;
GO

USE PersonelDB;
GO

/* Departman tablosu */
CREATE TABLE dbo.Departman
(
    DepartmanID  INT IDENTITY(1,1) PRIMARY KEY,
    DepartmanAdi NVARCHAR(80) NOT NULL UNIQUE
);

/* Personel tablosu - hassas bilgiler içerir */
CREATE TABLE dbo.Personel
(
    PersonelID    INT IDENTITY(1,1) PRIMARY KEY,
    TCKimlikNo    NVARCHAR(11) NOT NULL,    -- hassas
    Ad            NVARCHAR(50) NOT NULL,
    Soyad         NVARCHAR(50) NOT NULL,
    Email         NVARCHAR(120) NOT NULL,
    Telefon       NVARCHAR(20) NULL,
    Maas          DECIMAL(12,2) NOT NULL,    -- hassas
    IseBaslamaTarihi DATE NOT NULL,
    DepartmanID   INT NOT NULL REFERENCES dbo.Departman(DepartmanID)
);

/* Audit edilecek işlem tablosu */
CREATE TABLE dbo.IslemLog
(
    LogID       BIGINT IDENTITY(1,1) PRIMARY KEY,
    Zaman       DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    Kullanici   SYSNAME NOT NULL DEFAULT SUSER_SNAME(),
    Islem       NVARCHAR(20) NOT NULL,
    Aciklama    NVARCHAR(400) NULL
);
GO

INSERT INTO dbo.Departman (DepartmanAdi) VALUES
 (N'İnsan Kaynakları'),
 (N'Yazılım Geliştirme'),
 (N'Muhasebe'),
 (N'Pazarlama');

INSERT INTO dbo.Personel (TCKimlikNo, Ad, Soyad, Email, Telefon, Maas, IseBaslamaTarihi, DepartmanID) VALUES
 (N'12345678901', N'Ahmet',  N'Yılmaz',  N'ahmet@sirket.com',  N'5551112233', 85000.00, '2020-03-01', 2),
 (N'23456789012', N'Ayşe',   N'Kaya',    N'ayse@sirket.com',   N'5551112234', 62000.00, '2021-06-15', 1),
 (N'34567890123', N'Mehmet', N'Demir',   N'mehmet@sirket.com', N'5551112235', 95000.00, '2019-01-10', 2),
 (N'45678901234', N'Fatma',  N'Şahin',   N'fatma@sirket.com',  N'5551112236', 70000.00, '2022-09-01', 3),
 (N'56789012345', N'Ali',    N'Çelik',   N'ali@sirket.com',    N'5551112237', 55000.00, '2023-02-20', 4);
GO

PRINT '>>> PersonelDB hazır.';
SELECT COUNT(*) AS PersonelSayisi FROM dbo.Personel;
GO
