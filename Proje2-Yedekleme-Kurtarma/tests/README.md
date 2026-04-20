# Proje 2 — Test ve Demo Runner'ları

Bu klasör, yedekleme/kurtarma zincirini uçtan uca demo eden PowerShell script'lerini içerir.

## Ön Koşullar

1. SQL Server servisi çalışıyor olmalı (yönetici olarak):
   ```powershell
   net start MSSQLSERVER
   net start SQLSERVERAGENT
   ```
2. `C:\SQLBackups` ve `C:\SQLData` klasörleri yazılabilir (script'ler auto-create ediyor).
3. PowerShell 5.1+ ve `sqlcmd` (SQL Server kurulumu ile geliyor).

## Disaster-Recovery Demo

Tek komutla, tüm felaket-kurtarma senaryosunu canlandırır:

```powershell
cd Proje2-Yedekleme-Kurtarma\tests
.\disaster-recovery-demo.ps1
```

### Akış (9 adım)

| # | Ne olur | Beklenen |
|---|---------|----------|
| 1 | `OkulDB` kurulur (5 öğrenci) | Satır = 5 |
| 2 | FULL backup alınır | `.bak` oluşur |
| 3 | 2 yeni öğrenci eklenir, DIFF backup | Satır = 7 |
| 4 | 2 yeni öğrenci eklenir, LOG backup | Satır = 9 |
| 5 | Güvenli zaman damgası `@StopAt` kaydedilir | ISO 8601 timestamp |
| 6 | **FELAKET**: `DELETE FROM dbo.Ogrenci` | Satır = 0 |
| 7 | Tail-log backup (silme log'u) | `*_TAIL.trn` |
| 8 | PITR: FULL + DIFF + LOG'lar + son LOG STOPAT ile | — |
| 9 | Doğrulama: satır sayısı = 9 mı? | **PASS** ✓ |

### Çıktılar

```
tests/output/demo_YYYYMMDD_HHMMSS/
├── 01_setup.log      02_full.log
├── 03a_insert.log    03b_diff.log
├── 04a_insert.log    04b_log.log
├── 05_stopat.log     05_count.log
├── 06_disaster.log   06_after.log
├── 07_tail.log
├── 08_pitr.log
└── 09_verify.log
```

`output/` klasörü `.gitignore`'da dışlanır.

### Başarı kriteri

Script şu çıktıyı üretirse demo başarılı:

```
================================================================
 SONUC
================================================================
 Felaket oncesi  : 9 satir
 Felaket sonrasi : 0 satir
 Kurtarma sonrasi: 9 satir

+ BASARILI: Tum veri @StopAt anina geri getirildi.
```

## Tipik Sorunlar

- **"Could not open a connection to SQL Server [2]"** — Servis durmuş.
  `net start MSSQLSERVER` (admin PowerShell).
- **`C:\SQLBackups` izin hatası** — `01_setup_database.sql` içindeki `xp_create_subdir` komutu SQL Server servis hesabıyla çalışır; bu hesabın klasöre yazma yetkisi olması gerekir. Alternatif: klasörü manuel oluştur ve **Everyone → Modify** ver (yalnızca lab ortamı).
- **"BACKUP LOG cannot be performed because there is no current database backup"** — Önce FULL alınmalı. Demo script'i bu sırayı zaten uygular; manuel koşuda sırayı atlamayın.
- **Recovery model SIMPLE** — `01_setup_database.sql` DB'yi FULL'a çeviriyor. Başka bir DB'ye uyarlarken `ALTER DATABASE ... SET RECOVERY FULL` atlanmamalı.

## Manuel Adımlar (demo yerine)

Demo script'ini çalıştırmak istemezseniz, `sql/` klasöründeki script'leri sırasıyla çalıştırabilirsiniz:

```powershell
cd ..\sql
sqlcmd -S . -E -C -i 01_setup_database.sql
sqlcmd -S . -E -C -i 02_full_backup.sql
sqlcmd -S . -E -C -i 07_accidental_delete_scenario.sql
# 06'daki @StopAt değerini 07'nin çıktısındaki zaman damgasıyla güncelleyin
sqlcmd -S . -E -C -i 06_restore_point_in_time.sql
sqlcmd -S . -E -C -i 09_verify_backups.sql
```
