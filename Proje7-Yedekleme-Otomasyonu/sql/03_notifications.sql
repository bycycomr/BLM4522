/* ============================================================================
   BLM4522 - Proje 7: Yedekleme ve Otomasyon
   ----------------------------------------------------------------------------
   03_notifications.sql
   Amac : Yedekleme job'i BASARISIZ olursa yoneticiye e-posta bildirimi.
   Bilesenler: Database Mail (hesap + profil) + Operator (DBA_Operator).
   NOT : Gercek e-posta gonderimi icin gecerli bir SMTP sunucusu gerekir.
         Burada ornek SMTP ayarlari girilir; SMTP yoksa mail "unsent" kuyruguna
         dusulur (script HATA vermez). Operator ve profil 04'teki job'lar
         tarafindan kullanilir.
   Calistirma: sqlcmd -S . -E -C -I -b -i 03_notifications.sql
   ============================================================================ */
SET NOCOUNT ON;
USE master;
GO

/* --- 1) Database Mail XPs'i etkinlestir --- */
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;     RECONFIGURE;
GO

USE msdb;
GO
/* --- 2) Eski yapilandirmayi temizle (re-runnable) --- */
IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = N'Proje7_Profile')
    EXEC msdb.dbo.sysmail_delete_profile_sp @profile_name = N'Proje7_Profile';
IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name = N'Proje7_Mail')
    EXEC msdb.dbo.sysmail_delete_account_sp @account_name = N'Proje7_Mail';
IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = N'DBA_Operator')
    EXEC msdb.dbo.sp_delete_operator @name = N'DBA_Operator';
GO

/* --- 3) Mail hesabi + profili --- */
EXEC msdb.dbo.sysmail_add_account_sp
    @account_name    = N'Proje7_Mail',
    @description     = N'BLM4522 Proje 7 yedekleme bildirimleri',
    @email_address   = N'dba@ornek.com',
    @display_name    = N'OtomasyonDB Yedekleme',
    @mailserver_name = N'smtp.ornek.com',   -- GERCEK SMTP ile degistirilmeli
    @port            = 587;

EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = N'Proje7_Profile',
    @description  = N'BLM4522 Proje 7 mail profili';

EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = N'Proje7_Profile',
    @account_name = N'Proje7_Mail',
    @sequence_number = 1;
GO

/* --- 4) Operator (bildirim alacak yonetici) --- */
EXEC msdb.dbo.sp_add_operator
    @name         = N'DBA_Operator',
    @enabled      = 1,
    @email_address = N'dba@ornek.com';
GO

/* --- 5) SQL Server Agent'i Database Mail kullanacak sekilde ayarla --- */
-- (Etkinlesmesi icin Agent servisi yeniden baslatilmalidir.)
BEGIN TRY
    EXEC msdb.dbo.sp_set_sqlagent_properties
        @email_save_in_sent_folder = 1,
        @databasemail_profile      = N'Proje7_Profile',
        @use_databasemail          = 1;
    PRINT 'Agent mail profili ayarlandi (Agent yeniden baslatilinca aktif).';
END TRY
BEGIN CATCH
    PRINT CONCAT('Agent mail ayari atlandi: ', ERROR_MESSAGE());
END CATCH
GO

/* --- 6) Test maili (SMTP yoksa kuyruga dusulur, hata vermez) --- */
BEGIN TRY
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = N'Proje7_Profile',
        @recipients   = N'dba@ornek.com',
        @subject      = N'[Proje7] Database Mail test',
        @body         = N'Bu bir test bildirimidir. Yapilandirma calisiyor.';
    PRINT 'Test maili kuyruga alindi (gonderim SMTP ayarina baglidir).';
END TRY
BEGIN CATCH
    PRINT CONCAT('Test maili gonderilemedi: ', ERROR_MESSAGE());
END CATCH
GO

PRINT '== 03_notifications.sql TAMAMLANDI ==';
GO
