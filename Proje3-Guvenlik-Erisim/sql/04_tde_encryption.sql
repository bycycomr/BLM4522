/* ============================================================================
   Proje 3 - Adım 04: Transparent Data Encryption (TDE)
   ----------------------------------------------------------------------------
   Amaç   : Veritabanı dosyaları diskte şifreli durmalı. Birisi .mdf/.ldf/.bak
            dosyalarını çalsa bile içeriği okuyamamalıdır.
   Katman : TDE, sayfa-düzeyinde şifreleme yapar. Uygulama kodu değişmez.
   Hiyerarşi:
            Service Master Key (SMK)           <- sunucu seviyesi (otomatik)
              └─> Database Master Key (DMK)    <- master DB'de
                    └─> Certificate (TDE Cert) <- master DB'de, YEDEK ŞART
                           └─> Database Encryption Key (DEK) <- hedef DB'de
   UYARI : TDE sertifikası kaybolursa veritabanı BİR DAHA AÇILAMAZ.
            Sertifikayı ve private key'ini mutlaka güvenli bir yere yedekleyin.
   ============================================================================ */

USE master;
GO

/* 1) Master key (yoksa oluştur) */
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'Str0ng!MasterKeyPwd_2026';
GO

/* 2) TDE için sertifika */
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'TDE_Cert_PersonelDB')
BEGIN
    CREATE CERTIFICATE TDE_Cert_PersonelDB
    WITH SUBJECT = N'TDE Certificate for PersonelDB - BLM4522';
END
GO

/* 3) Sertifikayı DİSKE YEDEKLE - kritik!
      Idempotent: dosya zaten varsa yedek alma (SQL Server ustune yazmaz). */
DECLARE @pvkExists INT;
EXEC master.dbo.xp_fileexist N'C:\SQLBackups\TDE_Cert_PersonelDB.pvk', @pvkExists OUTPUT;
IF @pvkExists = 0
BEGIN
    BACKUP CERTIFICATE TDE_Cert_PersonelDB
    TO FILE = N'C:\SQLBackups\TDE_Cert_PersonelDB.cer'
    WITH PRIVATE KEY (
        FILE     = N'C:\SQLBackups\TDE_Cert_PersonelDB.pvk',
        ENCRYPTION BY PASSWORD = N'Str0ng!PrivateKeyPwd_2026'
    );
    PRINT N'>>> Sertifika yedeklendi (C:\SQLBackups\TDE_Cert_PersonelDB.*).';
END
ELSE
    PRINT N'>>> Sertifika yedek dosyasi zaten var, atlanildi.';
GO

/* 4) PersonelDB'de Database Encryption Key oluştur */
USE PersonelDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID())
BEGIN
    CREATE DATABASE ENCRYPTION KEY
        WITH ALGORITHM = AES_256
        ENCRYPTION BY SERVER CERTIFICATE TDE_Cert_PersonelDB;
END
GO

/* 5) Şifrelemeyi aç */
ALTER DATABASE PersonelDB SET ENCRYPTION ON;
GO

/* 6) Durumu kontrol et
   encryption_state:
     0 = No key
     1 = Unencrypted
     2 = Encryption in progress
     3 = Encrypted
     4 = Key change in progress
     5 = Decryption in progress
*/
SELECT DB_NAME(database_id) AS DB,
       encryption_state,
       key_algorithm,
       key_length,
       percent_complete
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID(N'PersonelDB');
GO

PRINT '>>> TDE etkinleştirildi. Durum 3 olana kadar arka planda şifreleniyor.';
GO
