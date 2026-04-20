/* ============================================================================
   Proje 2 - Adım 08: Otomatik Yedekleme (SQL Server Agent Job)
   ----------------------------------------------------------------------------
   Amaç: Yedekleme sürecini zamanlanmış hale getirmek.
   Strateji (ders kitabı standardı):
      - Haftada bir          : FULL backup     (Pazar 02:00)
      - Her gün              : DIFFERENTIAL   (Pazartesi-Cumartesi 02:00)
      - Her 15 dakikada bir  : LOG backup
   Şart: SQL Server Agent servisi çalışıyor olmalı.
   ============================================================================ */

USE msdb;
GO

/* --- Var olan job'u temizle --- */
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'OkulDB_Backup_Plan')
    EXEC sp_delete_job @job_name = N'OkulDB_Backup_Plan', @delete_history = 1;
GO

/* --- Job oluştur --- */
DECLARE @JobId UNIQUEIDENTIFIER;
EXEC sp_add_job
    @job_name = N'OkulDB_Backup_Plan',
    @description = N'BLM4522 Proje 2 - Otomatik yedekleme planı',
    @enabled = 1,
    @owner_login_name = N'sa',
    @job_id = @JobId OUTPUT;

/* --- Adım 1: Haftalık FULL (yalnızca Pazar) --- */
EXEC sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'Haftalık FULL Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @f NVARCHAR(260) = N''C:\SQLBackups\OkulDB_FULL_'' + FORMAT(SYSDATETIME(),''yyyyMMdd_HHmmss'') + N''.bak'';
IF DATEPART(WEEKDAY, GETDATE()) = 1   -- Pazar (us_english diliyle)
    BACKUP DATABASE OkulDB TO DISK = @f
    WITH INIT, COMPRESSION, CHECKSUM, NAME = N''OkulDB-FULL-Auto'';
',
    @on_success_action = 3,   -- sonraki adıma geç
    @on_fail_action    = 2;   -- job'u fail et

/* --- Adım 2: Günlük DIFF (Pazar hariç) --- */
EXEC sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'Günlük Differential Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @f NVARCHAR(260) = N''C:\SQLBackups\OkulDB_DIFF_'' + FORMAT(SYSDATETIME(),''yyyyMMdd_HHmmss'') + N''.bak'';
IF DATEPART(WEEKDAY, GETDATE()) <> 1
    BACKUP DATABASE OkulDB TO DISK = @f
    WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, NAME = N''OkulDB-DIFF-Auto'';
',
    @on_success_action = 1,
    @on_fail_action    = 2;

/* --- Sunucuya ata --- */
EXEC sp_add_jobserver @job_id = @JobId, @server_name = N'(local)';

/* --- Zamanlama 1: Günlük 02:00 --- */
EXEC sp_add_schedule
    @schedule_name = N'OkulDB_Gunluk_0200',
    @freq_type = 4,           -- günlük
    @freq_interval = 1,
    @active_start_time = 020000;
EXEC sp_attach_schedule @job_name = N'OkulDB_Backup_Plan', @schedule_name = N'OkulDB_Gunluk_0200';

GO

/* --- Ayrı job: Her 15 dakikada LOG backup --- */
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'OkulDB_Log_Backup_15dk')
    EXEC sp_delete_job @job_name = N'OkulDB_Log_Backup_15dk', @delete_history = 1;

DECLARE @LogJobId UNIQUEIDENTIFIER;
EXEC sp_add_job
    @job_name = N'OkulDB_Log_Backup_15dk',
    @description = N'BLM4522 Proje 2 - 15 dakikalık log yedeği',
    @enabled = 1,
    @owner_login_name = N'sa',
    @job_id = @LogJobId OUTPUT;

EXEC sp_add_jobstep
    @job_id = @LogJobId,
    @step_name = N'LOG Backup',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @f NVARCHAR(260) = N''C:\SQLBackups\OkulDB_LOG_'' + FORMAT(SYSDATETIME(),''yyyyMMdd_HHmmss'') + N''.trn'';
BACKUP LOG OkulDB TO DISK = @f
WITH INIT, COMPRESSION, CHECKSUM, NAME = N''OkulDB-LOG-Auto'';
',
    @on_success_action = 1,
    @on_fail_action    = 2;

EXEC sp_add_jobserver @job_id = @LogJobId, @server_name = N'(local)';

EXEC sp_add_schedule
    @schedule_name = N'OkulDB_Log_15dk',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,     -- dakika
    @freq_subday_interval = 15,
    @active_start_time = 0;
EXEC sp_attach_schedule @job_name = N'OkulDB_Log_Backup_15dk', @schedule_name = N'OkulDB_Log_15dk';
GO

PRINT N'>>> Yedekleme job''ları oluşturuldu. SQL Server Agent çalışıyor olmalı.';
SELECT name, enabled, date_created FROM msdb.dbo.sysjobs WHERE name LIKE N'OkulDB_%';
GO
