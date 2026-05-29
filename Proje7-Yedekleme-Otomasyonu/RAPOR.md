# Proje 7 — Veritabanı Yedekleme ve Otomasyon Çalışması

**Ders:** BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri
**Öğrenci:** Ömer Doğan
**Platform:** Microsoft SQL Server (+ SQL Server Agent, Database Mail)
**Veritabanı:** `OtomasyonDB` · **Yedek klasörü:** `C:\SQLBackups\Proje7`

---

## 1. Amaç ve Gereksinim Karşılığı

Yedekleme süreçlerini **SQL Server Agent** ile otomatikleştirmek, alınan yedekleri **raporlamak** ve hata durumunda **yöneticiye bildirim** göndermek. 5 SQL script'i = gereksinimler:

| Resmî Gereksinim | Script |
|------------------|--------|
| Yedekleme otomasyonu için SQL Server Agent | [`04_agent_jobs.sql`](./sql/04_agent_jobs.sql) |
| Yedeklerin düzenli alındığını gösteren rapor (T-SQL **veya** PowerShell) | [`05_backup_report.sql`](./sql/05_backup_report.sql) + [`tests/backup-report.ps1`](./tests/backup-report.ps1) |
| Başarısızlıkta yöneticilere bildirim (Alert/Email) | [`03_notifications.sql`](./sql/03_notifications.sql) + job notify (04) |
| (Temel) yeniden kullanılabilir yedekleme | [`02_backup_procedures.sql`](./sql/02_backup_procedures.sql) |

> **Proje 2'den farkı:** Proje 2 yedekleme + felaketten kurtarma + PITR'a odaklanır. Proje 7 ise **otomasyon (zamanlanmış ayrı job'lar), yeniden kullanılabilir prosedürler, raporlama ve bildirim** katmanına odaklanır.

## 2. Çalıştırma

```powershell
net start MSSQLSERVER          # gerekirse (yönetici)
cd Proje7-Yedekleme-Otomasyonu\tests
.\run-all.ps1                  # 5/5 PASS
.\backup-report.ps1            # PowerShell yedek raporu

# Job'ların ZAMANINDA çalışması için (yönetici):
net start SQLSERVERAGENT
```

## 3. Yedekleme Prosedürleri ([`02`](./sql/02_backup_procedures.sql))

Üç yeniden kullanılabilir prosedür — Agent job'ları bunları çağırır (kod tek yerde):

| Prosedür | İşlem | Özellik |
|----------|-------|---------|
| `usp_FullBackup` | `BACKUP DATABASE` | + `RESTORE VERIFYONLY` (bütünlük) |
| `usp_DiffBackup` | `BACKUP ... DIFFERENTIAL` | |
| `usp_LogBackup` | `BACKUP LOG` | |

Hepsi `WITH INIT, COMPRESSION, CHECKSUM` ve zaman damgalı dosya adı kullanır. Hata olursa `THROW` ile job adımı **FAIL** olur → bildirim tetiklenir. **Doğrulandı:** FULL 3.96 MB → sıkıştırılmış 0.52 MB.

## 4. Otomasyon — Agent Job'ları ([`04`](./sql/04_agent_jobs.sql))

Üç ayrı zamanlanmış job (Proje 2'nin tek job'ından farklı, modüler):

| Job | Zamanlama |
|-----|-----------|
| `Proje7_FULL_Backup` | Her gün 02:00 |
| `Proje7_DIFF_Backup` | Her 6 saatte bir |
| `Proje7_LOG_Backup` | Her 15 dakikada bir |

Her job başarısız olursa `@notify_level_email = 2` ile `DBA_Operator`'a e-posta gönderir. Job'lar Agent kapalıyken bile oluşturulur (msdb metadata); zamanlı çalışma için Agent servisi açık olmalıdır.

## 5. Bildirim ([`03`](./sql/03_notifications.sql))

- **Database Mail** etkinleştirilir; `Proje7_Mail` hesabı + `Proje7_Profile` profili oluşturulur.
- **`DBA_Operator`** (e-posta alıcı yönetici) tanımlanır.
- Agent, Database Mail profilini kullanacak şekilde ayarlanır.
- Gerçek e-posta için geçerli bir **SMTP sunucusu** gerekir (`smtp.ornek.com` placeholder ile bırakıldı); SMTP yoksa mail "unsent" kuyruğuna düşer, script hata vermez.

## 6. Raporlama ([`05`](./sql/05_backup_report.sql) + PowerShell)

`msdb.dbo.backupset` geçmişinden:
- Veritabanı başına son Full/Diff/Log zamanı,
- OtomasyonDB için son yedekler (tip, boyut, sıkıştırma, süre, dosya),
- **Yedek sağlık durumu** (FULL > 24 saat veya LOG > 60 dk ise UYARI),
- Proje7 job'larının çalışma geçmişi.

PowerShell sürümü ([`backup-report.ps1`](./tests/backup-report.ps1)) konsola özet ve son FULL kontrolü basar.

## 7. Doğrulama (run-all.ps1 — 5/5 PASS)

3 gerçek yedek alındı ve VERIFYONLY ile doğrulandı; 3 Agent job'ı oluşturuldu; rapor yedekleri listeledi. Çıktılar `tests/output/` altında.

## 8. Ekran Görüntüleri

`docs/` altına: `01-backup-dosyalari.png`, `02-agent-jobs.png` (SSMS Agent), `03-rapor.png`, `04-operator-mail.png`, `05-test-runner.png`.

## 9. Referanslar

- SQL Server Agent Jobs — https://learn.microsoft.com/sql/ssms/agent/sql-server-agent
- Database Mail — https://learn.microsoft.com/sql/relational-databases/database-mail/database-mail
- `BACKUP` — https://learn.microsoft.com/sql/t-sql/statements/backup-transact-sql
- backupset — https://learn.microsoft.com/sql/relational-databases/system-tables/backupset-transact-sql
