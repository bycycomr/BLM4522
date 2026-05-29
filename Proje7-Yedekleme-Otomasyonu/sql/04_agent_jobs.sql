/* ============================================================================
   BLM4522 - Proje 7: Yedekleme ve Otomasyon
   ----------------------------------------------------------------------------
   04_agent_jobs.sql
   Amac : Yedekleme otomasyonu icin SQL Server Agent job'lari ve zamanlamalari.
   Strateji:  FULL  -> her gun 02:00
              DIFF  -> her 6 saatte bir
              LOG   -> her 15 dakikada bir
   Her job 02'deki proc'u cagirir ve BASARISIZ olursa DBA_Operator'a mail atar.
   NOT : Job'lar Agent servisi DURSA BILE olusturulur (msdb metadata). Zamanin
         gelince calismasi icin Agent calismali: (yonetici) net start SQLSERVERAGENT
   Calistirma: sqlcmd -S . -E -C -I -b -i 04_agent_jobs.sql
   ============================================================================ */
SET NOCOUNT ON;
USE msdb;
GO

/* --- Yardimci: eski job ve schedule'lari temizle (re-runnable) --- */
DECLARE @jobs TABLE (ad SYSNAME);
INSERT INTO @jobs VALUES (N'Proje7_FULL_Backup'),(N'Proje7_DIFF_Backup'),(N'Proje7_LOG_Backup');

DECLARE @j SYSNAME;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ad FROM @jobs;
OPEN c; FETCH NEXT FROM c INTO @j;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @j)
        EXEC msdb.dbo.sp_delete_job @job_name = @j, @delete_history = 1;
    FETCH NEXT FROM c INTO @j;
END
CLOSE c; DEALLOCATE c;

DECLARE @sched TABLE (ad SYSNAME);
INSERT INTO @sched VALUES (N'sched_full_gunluk'),(N'sched_diff_6saat'),(N'sched_log_15dk');
DECLARE @s SYSNAME;
DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR SELECT ad FROM @sched;
OPEN c2; FETCH NEXT FROM c2 INTO @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    WHILE EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = @s)
        EXEC msdb.dbo.sp_delete_schedule @schedule_name = @s, @force_delete = 1;
    FETCH NEXT FROM c2 INTO @s;
END
CLOSE c2; DEALLOCATE c2;
GO

/* ===========================================================================
   JOB 1: FULL - her gun 02:00
   =========================================================================== */
EXEC msdb.dbo.sp_add_job @job_name = N'Proje7_FULL_Backup',
     @description = N'OtomasyonDB gunluk full backup', @enabled = 1,
     @owner_login_name = N'sa',
     @notify_level_email = 2,                       -- 2 = basarisiz olunca
     @notify_email_operator_name = N'DBA_Operator';
EXEC msdb.dbo.sp_add_jobstep @job_name = N'Proje7_FULL_Backup',
     @step_name = N'Full Backup', @subsystem = N'TSQL',
     @database_name = N'OtomasyonDB',
     @command = N'EXEC dbo.usp_FullBackup @DatabaseName = N''OtomasyonDB'';',
     @on_success_action = 1, @on_fail_action = 2;
EXEC msdb.dbo.sp_add_schedule @schedule_name = N'sched_full_gunluk',
     @freq_type = 4, @freq_interval = 1, @active_start_time = 020000;  -- gunluk 02:00
EXEC msdb.dbo.sp_attach_schedule @job_name = N'Proje7_FULL_Backup', @schedule_name = N'sched_full_gunluk';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'Proje7_FULL_Backup', @server_name = N'(local)';
GO

/* ===========================================================================
   JOB 2: DIFF - her 6 saatte bir
   =========================================================================== */
EXEC msdb.dbo.sp_add_job @job_name = N'Proje7_DIFF_Backup',
     @description = N'OtomasyonDB differential backup', @enabled = 1,
     @owner_login_name = N'sa',
     @notify_level_email = 2, @notify_email_operator_name = N'DBA_Operator';
EXEC msdb.dbo.sp_add_jobstep @job_name = N'Proje7_DIFF_Backup',
     @step_name = N'Diff Backup', @subsystem = N'TSQL',
     @database_name = N'OtomasyonDB',
     @command = N'EXEC dbo.usp_DiffBackup @DatabaseName = N''OtomasyonDB'';',
     @on_success_action = 1, @on_fail_action = 2;
EXEC msdb.dbo.sp_add_schedule @schedule_name = N'sched_diff_6saat',
     @freq_type = 4, @freq_interval = 1,
     @freq_subday_type = 8, @freq_subday_interval = 6,                 -- her 6 saat
     @active_start_time = 000000;
EXEC msdb.dbo.sp_attach_schedule @job_name = N'Proje7_DIFF_Backup', @schedule_name = N'sched_diff_6saat';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'Proje7_DIFF_Backup', @server_name = N'(local)';
GO

/* ===========================================================================
   JOB 3: LOG - her 15 dakikada bir
   =========================================================================== */
EXEC msdb.dbo.sp_add_job @job_name = N'Proje7_LOG_Backup',
     @description = N'OtomasyonDB transaction log backup', @enabled = 1,
     @owner_login_name = N'sa',
     @notify_level_email = 2, @notify_email_operator_name = N'DBA_Operator';
EXEC msdb.dbo.sp_add_jobstep @job_name = N'Proje7_LOG_Backup',
     @step_name = N'Log Backup', @subsystem = N'TSQL',
     @database_name = N'OtomasyonDB',
     @command = N'EXEC dbo.usp_LogBackup @DatabaseName = N''OtomasyonDB'';',
     @on_success_action = 1, @on_fail_action = 2;
EXEC msdb.dbo.sp_add_schedule @schedule_name = N'sched_log_15dk',
     @freq_type = 4, @freq_interval = 1,
     @freq_subday_type = 4, @freq_subday_interval = 15,                -- her 15 dk
     @active_start_time = 000000;
EXEC msdb.dbo.sp_attach_schedule @job_name = N'Proje7_LOG_Backup', @schedule_name = N'sched_log_15dk';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'Proje7_LOG_Backup', @server_name = N'(local)';
GO

/* --- Olusan job'lari listele --- */
PRINT '--- Olusturulan Proje7 job''lari ---';
SELECT name AS JobAdi, enabled AS Aktif, date_created AS Olusturma
FROM msdb.dbo.sysjobs WHERE name LIKE 'Proje7_%' ORDER BY name;
GO

PRINT '== 04_agent_jobs.sql TAMAMLANDI ==';
GO
