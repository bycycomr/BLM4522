/* ============================================================================
   Proje 2 - Adım 01: Veritabanı Hazırlığı
   ----------------------------------------------------------------------------
   Amaç : Yedekleme/kurtarma senaryolarını deneyeceğimiz örnek bir veritabanı
          oluşturmak.
   Not  : Point-in-time restore ve log backup'ın çalışabilmesi için veritabanı
          RECOVERY MODEL = FULL olmalıdır. SIMPLE modda log backup alınamaz.
   Çalıştırma: sqlcmd -S . -E -C -i 01_setup_database.sql
   ============================================================================ */

USE master;
GO

/* Var olan test DB'sini temizle (yalnızca test ortamı için!) */
IF DB_ID(N'OkulDB') IS NOT NULL
BEGIN
    ALTER DATABASE OkulDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OkulDB;
END
GO

/* Veritabanını oluştur */
CREATE DATABASE OkulDB
ON PRIMARY
(
    NAME     = N'OkulDB_Data',
    FILENAME = N'C:\SQLData\OkulDB.mdf',
    SIZE     = 64 MB,
    FILEGROWTH = 16 MB
)
LOG ON
(
    NAME     = N'OkulDB_Log',
    FILENAME = N'C:\SQLData\OkulDB_log.ldf',
    SIZE     = 16 MB,
    FILEGROWTH = 8 MB
);
GO

/* Recovery model'i FULL yap (log backup + point-in-time restore için şart) */
ALTER DATABASE OkulDB SET RECOVERY FULL;
GO

USE OkulDB;
GO

/* Örnek tablolar */
CREATE TABLE dbo.Ogrenci
(
    OgrenciID   INT IDENTITY(1,1) PRIMARY KEY,
    Ad          NVARCHAR(50) NOT NULL,
    Soyad       NVARCHAR(50) NOT NULL,
    Numara      NVARCHAR(20) NOT NULL UNIQUE,
    Bolum       NVARCHAR(60) NOT NULL,
    KayitTarihi DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Ders
(
    DersID    INT IDENTITY(1,1) PRIMARY KEY,
    DersKodu  NVARCHAR(10) NOT NULL UNIQUE,
    DersAdi   NVARCHAR(100) NOT NULL,
    Kredi     TINYINT NOT NULL CHECK (Kredi BETWEEN 1 AND 10)
);

CREATE TABLE dbo.Not
(
    NotID       INT IDENTITY(1,1) PRIMARY KEY,
    OgrenciID   INT NOT NULL REFERENCES dbo.Ogrenci(OgrenciID),
    DersID      INT NOT NULL REFERENCES dbo.Ders(DersID),
    Vize        TINYINT NULL CHECK (Vize BETWEEN 0 AND 100),
    Final       TINYINT NULL CHECK (Final BETWEEN 0 AND 100),
    Ortalama    AS (CAST(ISNULL(Vize,0) * 0.4 + ISNULL(Final,0) * 0.6 AS DECIMAL(5,2))) PERSISTED
);
GO

/* Seed verisi */
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'Ahmet',   N'Yılmaz',  N'20200001', N'Bilgisayar Mühendisliği'),
 (N'Ayşe',    N'Kaya',    N'20200002', N'Bilgisayar Mühendisliği'),
 (N'Mehmet',  N'Demir',   N'20200003', N'Elektrik Elektronik'),
 (N'Fatma',   N'Şahin',   N'20200004', N'Bilgisayar Mühendisliği'),
 (N'Ali',     N'Çelik',   N'20200005', N'Endüstri Mühendisliği');

INSERT INTO dbo.Ders (DersKodu, DersAdi, Kredi) VALUES
 (N'BLM4522', N'Ağ Tabanlı Paralel Dağıtım Sistemleri', 3),
 (N'BLM3211', N'Veritabanı Yönetim Sistemleri',         4),
 (N'BLM2411', N'Veri Yapıları',                         4);

INSERT INTO dbo.Not (OgrenciID, DersID, Vize, Final) VALUES
 (1, 1, 70, 85), (1, 2, 60, 72),
 (2, 1, 90, 88), (2, 3, 75, 80),
 (3, 2, 55, 60),
 (4, 1, 82, 79), (4, 2, 88, 92),
 (5, 3, 40, 55);
GO

/* Yedekleme klasörünü garanti altına almak için (yoksa oluştur) */
EXEC xp_create_subdir N'C:\SQLBackups';
GO

PRINT '>>> OkulDB oluşturuldu. Recovery model = FULL. Seed verisi yüklendi.';
SELECT name, recovery_model_desc, state_desc FROM sys.databases WHERE name = N'OkulDB';
GO
