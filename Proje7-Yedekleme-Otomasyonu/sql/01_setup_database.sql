/* ============================================================================
   BLM4522 - Proje 7: Veritabani Yedekleme ve Otomasyon Calismasi
   ----------------------------------------------------------------------------
   01_setup_database.sql
   Amac : Otomatik yedeklenecek ornek veritabanini (OtomasyonDB) kurar ve
          yedek klasorunu olusturur.
   Not  : Log yedegi alinabilmesi icin RECOVERY FULL secilir.
          (Proje 2'den FARKLI bir DB ve klasor kullanilir: OtomasyonDB,
           C:\SQLBackups\Proje7)
   Calistirma: sqlcmd -S . -E -C -I -b -i 01_setup_database.sql
   ============================================================================ */
SET NOCOUNT ON;
GO
USE master;
GO

/* --- Yedek klasorunu olustur (sysadmin) --- */
EXEC master.dbo.xp_create_subdir N'C:\SQLBackups\Proje7';
GO

/* --- Veritabanini sifirdan olustur --- */
IF DB_ID(N'OtomasyonDB') IS NOT NULL
BEGIN
    ALTER DATABASE OtomasyonDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OtomasyonDB;
END
GO
CREATE DATABASE OtomasyonDB;
GO
-- Log yedegi icin FULL recovery sart
ALTER DATABASE OtomasyonDB SET RECOVERY FULL;
GO

USE OtomasyonDB;
GO
CREATE TABLE dbo.Islem (
    IslemID   INT IDENTITY(1,1) PRIMARY KEY,
    Aciklama  NVARCHAR(200) NOT NULL,
    Tutar     DECIMAL(12,2) NOT NULL,
    Zaman     DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);
GO
-- Baslangic verisi
INSERT INTO dbo.Islem (Aciklama, Tutar)
SELECT CONCAT(N'Islem-', n), n * 10.5
FROM (SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
      FROM sys.all_objects a, sys.all_objects b) x;
GO
DECLARE @n INT = (SELECT COUNT(*) FROM dbo.Islem);
PRINT CONCAT('OtomasyonDB hazir. Islem satir: ', @n);
GO
PRINT '== 01_setup_database.sql TAMAMLANDI ==';
GO
