/* ============================================================================
   BLM4522 - Proje 7: Yedekleme ve Otomasyon
   ----------------------------------------------------------------------------
   02_backup_procedures.sql
   Amac : Yeniden kullanilabilir yedekleme prosedurleri (Full / Diff / Log).
          Agent job'lari bu proc'lari cagirir -> kod tek yerde, bakimi kolay.
   Ozellikler: zaman damgali dosya adi, WITH CHECKSUM + COMPRESSION + INIT,
          FULL sonrasi RESTORE VERIFYONLY (yedek dogrulama), hata olursa THROW
          (job adimi FAIL olur -> bildirim tetiklenir).
   Calistirma: sqlcmd -S . -E -C -I -b -i 02_backup_procedures.sql
   ============================================================================ */
SET NOCOUNT ON;
USE OtomasyonDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_FullBackup
    @DatabaseName SYSNAME,
    @Klasor       NVARCHAR(260) = N'C:\SQLBackups\Proje7'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @dosya NVARCHAR(400) =
            CONCAT(@Klasor, N'\', @DatabaseName, N'_FULL_',
                   FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'), N'.bak');
        BACKUP DATABASE @DatabaseName TO DISK = @dosya
            WITH INIT, COMPRESSION, CHECKSUM, NAME = N'Proje7-FULL-Auto';
        RESTORE VERIFYONLY FROM DISK = @dosya WITH CHECKSUM;  -- yedek bütünlügü
        PRINT CONCAT('FULL backup OK -> ', @dosya);
    END TRY
    BEGIN CATCH
        DECLARE @m NVARCHAR(2000) = CONCAT('FULL backup HATA: ', ERROR_MESSAGE());
        THROW 50001, @m, 1;   -- job adimini FAIL et -> bildirim
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_DiffBackup
    @DatabaseName SYSNAME,
    @Klasor       NVARCHAR(260) = N'C:\SQLBackups\Proje7'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @dosya NVARCHAR(400) =
            CONCAT(@Klasor, N'\', @DatabaseName, N'_DIFF_',
                   FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'), N'.bak');
        BACKUP DATABASE @DatabaseName TO DISK = @dosya
            WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, NAME = N'Proje7-DIFF-Auto';
        PRINT CONCAT('DIFF backup OK -> ', @dosya);
    END TRY
    BEGIN CATCH
        DECLARE @m NVARCHAR(2000) = CONCAT('DIFF backup HATA: ', ERROR_MESSAGE());
        THROW 50002, @m, 1;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_LogBackup
    @DatabaseName SYSNAME,
    @Klasor       NVARCHAR(260) = N'C:\SQLBackups\Proje7'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @dosya NVARCHAR(400) =
            CONCAT(@Klasor, N'\', @DatabaseName, N'_LOG_',
                   FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'), N'.trn');
        BACKUP LOG @DatabaseName TO DISK = @dosya
            WITH INIT, COMPRESSION, CHECKSUM, NAME = N'Proje7-LOG-Auto';
        PRINT CONCAT('LOG backup OK -> ', @dosya);
    END TRY
    BEGIN CATCH
        DECLARE @m NVARCHAR(2000) = CONCAT('LOG backup HATA: ', ERROR_MESSAGE());
        THROW 50003, @m, 1;
    END CATCH
END
GO

/* --- Proc'lari bir kez calistir: gercek yedek gecmisi olussun --- */
PRINT '--- Ilk yedekler aliniyor (Full -> Diff -> Log) ---';
EXEC dbo.usp_FullBackup @DatabaseName = N'OtomasyonDB';
EXEC dbo.usp_DiffBackup @DatabaseName = N'OtomasyonDB';
EXEC dbo.usp_LogBackup  @DatabaseName = N'OtomasyonDB';
GO

PRINT '== 02_backup_procedures.sql TAMAMLANDI ==';
GO
