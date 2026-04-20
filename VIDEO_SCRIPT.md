# BLM4522 — Video Çekim Senaryosu

**Öğrenci:** Ömer Doğan
**Ders:** BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri
**Süre hedefi:** 12–15 dakika (min. 10 dk)
**Kayıt aracı:** OBS Studio / Xbox Game Bar (`Win+G`) / ShareX
**Ses:** Mikrofon açık, ekranda tek pencere (1920×1080)
**Ön hazırlık:** SQL Server servisi çalışır durumda, SSMS açık, proje klasörü VS Code'da açık, `tests/output/` altında son başarılı run hazır olsun.

---

## Dakika dökümü (özet)

| Bölüm | Süre | İçerik |
|-------|------|--------|
| 0. Giriş | 0:00 – 0:45 | Kendini ve projeyi tanıt |
| 1. Proje yapısı | 0:45 – 1:45 | Repo gezinti, iki alt proje |
| **PROJE 2 — Yedekleme & Kurtarma** | **1:45 – 7:00** | |
| 2.1 Rapor özet | 1:45 – 2:30 | RAPOR.md §1–3 |
| 2.2 Script'ler | 2:30 – 4:00 | 01–05 SQL dosyaları |
| 2.3 Demo runner | 4:00 – 6:00 | disaster-recovery-demo.ps1 canlı |
| 2.4 Agent & verify | 6:00 – 7:00 | 04, 05 + ekran görüntüleri |
| **PROJE 3 — Güvenlik & Erişim** | **7:00 – 13:00** | |
| 3.1 Rapor özet | 7:00 – 7:45 | RAPOR.md §1–3 |
| 3.2 Auth + RBAC | 7:45 – 9:00 | 02, 03 SQL dosyaları |
| 3.3 TDE | 9:00 – 10:00 | 04 + sertifika |
| 3.4 SQL Injection | 10:00 – 11:15 | 05 canlı demo |
| 3.5 Audit + RLS | 11:15 – 12:15 | 06, 07, 08 |
| 3.6 Test runner | 12:15 – 13:00 | run-all.ps1 9/9 |
| 4. Kapanış | 13:00 – 13:30 | Özet + teşekkür |

---

## 0. Giriş (0:00 – 0:45)

**Ekran:** Masaüstü veya proje README'si.

> "Merhaba, ben Ömer Doğan. BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri dersi kapsamında hazırladığım iki proje ödevini anlatacağım. Birincisi *Veritabanı Yedekleme ve Felaket Kurtarma*, ikincisi *Veritabanı Güvenliği ve Erişim Kontrolü*. Her iki projede de Microsoft SQL Server 2025 kullandım; tüm adımları T-SQL script'lerine döktüm ve uçtan uca PowerShell ile otomatikleştirdim. Şimdi sırayla gösteriyorum."

---

## 1. Proje Yapısı (0:45 – 1:45)

**Ekran:** VS Code'da proje kökü, soldaki dosya ağacı açık.

**Göster:**
- `BLM4522/` klasörünün kökü
- `Proje2-Yedekleme-Kurtarma/` → `sql/`, `tests/`, `RAPOR.md`, `README.md`
- `Proje3-Guvenlik-Erisim/` → `sql/`, `tests/`, `docs/`, `RAPOR.md`

> "Repo iki alt projeden oluşuyor. Her projenin `sql/` klasöründe numaralandırılmış T-SQL script'leri var: 01'den 09'a kadar sırayla çalıştırılıyor. `tests/` klasörü PowerShell otomasyonunu ve çıktı log'larını tutuyor. `docs/` klasöründe ekran görüntüleri, `RAPOR.md` ise projenin yazılı teknik raporu."

> "İki projeyi de `git` ile versiyonladım — her commit atomic ve açıklayıcı."

**İsteğe bağlı:** `git log --oneline` kısaca göster.

---

# PROJE 2 — VERİTABANI YEDEKLEME VE FELAKET KURTARMA

## 2.1 Rapor Özeti (1:45 – 2:30)

**Ekran:** `Proje2-Yedekleme-Kurtarma/RAPOR.md` — Bölüm 1 ve 3.

> "Birinci proje bir okul yönetim sistemi olan `OkulDB` üzerinde yedekleme stratejisi kuruyor. Üç backup türünü kullanıyorum: FULL, DIFFERENTIAL ve TRANSACTION LOG. FULL haftalık, DIFF günlük, LOG ise saatlik çalışacak şekilde tasarlandı. Bu kombinasyon sayesinde RPO yani veri kayıp toleransım 1 saatin altına iniyor, RTO yani kurtarma süresi hedefim 15 dakika."

**Göster:** RAPOR.md'de §3 "Yedekleme Stratejisi" tablosu.

> "Veritabanı RECOVERY MODEL'i FULL; log backup'ın çalışabilmesi için bu zorunlu. Tüm backup'lar `C:\SQLBackups\` altına yazılıyor."

---

## 2.2 SQL Script'leri (2:30 – 4:00)

**Ekran:** `Proje2-Yedekleme-Kurtarma/sql/` klasörü.

Dosyaları sırayla aç ve 10–15 saniye her birini özetle:

**`01_setup_database.sql`**
> "Setup script'i `OkulDB` veritabanını ve üç tabloyu (Ogrenci, Ders, Not) oluşturuyor. Örnek veri basıyor ve RECOVERY MODEL'i FULL'e çekiyor. Başında `xp_create_subdir` ile `C:\SQLData` ve `C:\SQLBackups` klasörlerini garantiliyorum."

**`02_full_backup.sql`**
> "FULL backup. Tüm veritabanını `.bak` dosyasına yazar — tek başına restore edilebilir baseline."

**`03_differential_backup.sql`**
> "DIFF backup. Son FULL'den bu yana değişen page'leri alır; restore sırasında FULL + DIFF sıralaması gerekir."

**`04_log_backup.sql`** ve **`05_point_in_time_restore.sql`**
> "Log backup transaction log'unu alır ve STOPAT parametresi ile istediğim zamana — mesela yanlışlıkla DELETE atılmadan 1 saniye önceye — geri dönmemi sağlar. Proje raporunda bu sürece Point-in-Time Restore deniyor."

---

## 2.3 Disaster Recovery Demo — CANLI (4:00 – 6:00)

**En kritik bölüm.** Burada script'i elle çalıştır.

**Ekran:** Yönetici PowerShell, `Proje2-Yedekleme-Kurtarma/tests/` dizini.

```powershell
cd c:\Users\bycyc\OneDrive\Desktop\BLM4522\Proje2-Yedekleme-Kurtarma\tests
.\disaster-recovery-demo.ps1
```

Script 9 adımda ilerliyor. Her adımda ne olduğunu açıkla:

> "1. Adım veritabanını kuruyor."
> "2. Adım FULL backup alıyor."
> "3. Adım yeni kayıt ekleyip DIFF alıyor."
> "4. Adım bir kayıt daha ekleyip LOG backup alıyor."
> "5. Adım felaket öncesi zamanı `StopAt` olarak kaydediyor — kritik nokta."
> "6. Adım **FELAKET**: `DELETE FROM Not; DELETE FROM Ogrenci` ile tüm veriyi siliyor."

Bu noktada SSMS'te `SELECT COUNT(*) FROM OkulDB.dbo.Ogrenci` yap → 0 gelir.

> "7. Adım **tail-log backup** alıyor — felaketi kaydeden son log. Olmadan STOPAT çalışmaz."
> "8. Adım FULL + DIFF + LOG + tail-log'u sırayla restore ediyor ve `STOPAT = @felaketOncesiZaman` ile tam DELETE'ten 1 saniye önceye geri dönüyor."
> "9. Adım satır sayısını doğruluyor."

Script bittiğinde:
```
>>> TOPLAM SATIR: 12 (Ogrenci + Ders + Not)
>>> BASARIYLA GERI GETIRILDI
```

> "On iki satırın tamamı geri geldi. Felaket öncesi state'e tam olarak döndük."

---

## 2.4 Agent Job + Verify (6:00 – 7:00)

**Ekran:** `Proje2-Yedekleme-Kurtarma/RAPOR.md` — §7 ve §8 + ekran görüntüleri.

> "Manuel backup yeterli değil; otomasyon da şart. `06_sql_agent_backup_job.sql` SQL Server Agent üzerinde üç job oluşturuyor: haftalık FULL, günlük DIFF, saatlik LOG."

Ekran görüntüsünü göster: `docs/05-agent-jobs.png`.

> "`07_verify_backups.sql` her backup için `RESTORE VERIFYONLY` ile bütünlüğü kontrol ediyor ve `msdb.dbo.backupset`'ten geçmişi çekiyor. Backup varsa ama bozuksa buradan anlaşılıyor."

Ekran görüntüsü: `docs/07-verify.png` ve `docs/06-backup-history.png`.

---

# PROJE 3 — VERİTABANI GÜVENLİĞİ VE ERİŞİM KONTROLÜ

## 3.1 Rapor Özeti (7:00 – 7:45)

**Ekran:** `Proje3-Guvenlik-Erisim/RAPOR.md` — §1 ve §2.

> "İkinci proje `PersonelDB` adında bir personel veritabanı üzerinde altı güvenlik katmanını uygulamaya alıyor: kimlik doğrulama, yetkilendirme, şifreleme, SQL injection savunması, audit ve row-level security. Tek bir katmanın yeterli olmadığı defense-in-depth mantığıyla kurgulandı."

Bölüm 2'deki ASCII Defense-in-Depth diyagramını göster.

---

## 3.2 Authentication + RBAC (7:45 – 9:00)

**Ekran:** `sql/02_auth_modes.sql` ve `sql/03_roles_and_permissions.sql`.

> "02 numaralı script üç SQL login oluşturuyor: `ik_okuyucu`, `muh_yazar`, `yazilim_sef`. Her biri `CHECK_POLICY = ON` ile Windows parola politikasına uyumlu."

Ekran görüntüsü: `docs/02-loginler.png`.

> "03 numaralı script Role-Based Access Control uyguluyor. Üç rol, üç view:
> - `vw_PersonelIK` — İK sadece maskelenmiş TC görüyor (ilk 3, son 4)
> - `vw_PersonelMaas` — Muhasebe maaş görüp güncelleyebiliyor ama TC'ye DENY
> - Yazılım şefi tabloya direkt erişiyor ama RLS filtreleri var."

Ekran görüntüsü: `docs/03-roller.png`.

> "Kritik nokta: DENY her zaman GRANT'i ezer. Bu yüzden hassas sütunlarda açık DENY kullandım."

---

## 3.3 Transparent Data Encryption (9:00 – 10:00)

**Ekran:** `sql/04_tde_encryption.sql` + RAPOR.md §6.2 hiyerarşi şeması.

> "TDE, veritabanı sayfalarını diske yazarken AES-256 ile şifreliyor. Birisi `.mdf` veya `.bak` dosyasını çalsa, başka bir sunucuya attach edemez çünkü sertifika orada yok."

Hiyerarşiyi göster:
```
SMK → DMK → Certificate → DEK → AES_256
```

> "Script her adımı idempotent: daha önce çalıştıysa skip ediyor. En önemli kısmı **sertifika yedeği**: `BACKUP CERTIFICATE` ile `.cer` ve `.pvk` dosyalarını `C:\SQLBackups\` altına alıyorum. Bu yedek kaybolursa, TDE etkin veritabanı bir daha açılamaz."

Ekran görüntüleri: `docs/04-tde-aktif.png` (encryption_state=3), `docs/08-tde-sertifika.png`.

---

## 3.4 SQL Injection — CANLI DEMO (10:00 – 11:15)

**Ekran:** SSMS + `sql/05_sql_injection_demo.sql`.

> "Bu projenin en somut saldırı demonstrasyonu. İki prosedür yazdım: biri savunmasız — string concat kullanıyor — diğeri güvenli — `sp_executesql` ile parameterized."

Canlı çalıştır:
```sql
-- Normal giriş
EXEC dbo.usp_AramaSavunmasiz @email = N'ahmet@sirket.com';
-- → 1 satır
```

> "Normal girişte beklediğimiz gibi tek satır dönüyor."

```sql
-- SQL Injection
EXEC dbo.usp_AramaSavunmasiz @email = N'x'' OR 1=1 --';
-- → TÜM tablo!
```

> "Ama saldırgan `x' OR 1=1 --` yazdığında 1=1 tautolojisi WHERE'i geçersizleştiriyor ve **bütün personelin maaş bilgileri dahil her şey sızıyor.**"

Ekran görüntüsü: `docs/05-sql-injection1.png`.

```sql
-- Güvenli prosedür aynı saldırıya
EXEC dbo.usp_AramaGuvenli @email = N'x'' OR 1=1 --';
-- → 0 satır
```

> "Güvenli prosedürde aynı saldırı **sıfır satır** dönüyor. Çünkü `sp_executesql` parametreyi literal string olarak bind ediyor; WHERE Email = `x' OR 1=1 --` diye bakıyor ve tabii ki eşleşme yok."

Ekran görüntüsü: `docs/05-sql-injection2.png`.

> "Üretim kuralı: string concat ile SQL inşa etmek yok; her sorgu parameterized."

---

## 3.5 Audit + Row-Level Security (11:15 – 12:15)

**Ekran:** `sql/06_audit_setup.sql`, `sql/08_row_level_security.sql`.

**Audit:**
> "SQL Server Audit hem server hem database seviyesinde çalışıyor. Login başarı/başarısızlığı, Personel tablosuna her türlü erişim ve rol değişiklikleri `C:\SQLAudit\*.sqlaudit` dosyalarına yazılıyor. `sys.fn_get_audit_file` ile sorguluyorum."

Ekran görüntüsü: `docs/07-audit-klasor.png`.

**RLS:**
> "Row-Level Security çok kiracılı senaryo için: `yazilim_sef` olarak `SELECT * FROM Personel` dediğimde, `sa` olarak beş satır yerine sadece iki satır — kendi departmanı — dönüyor."

RAPOR.md'de §9.3 kod bloğunu göster.

> "FILTER PREDICATE okumayı, BLOCK PREDICATE AFTER INSERT ise şefin başka departmana kayıt eklemesini engelliyor."

---

## 3.6 Test Runner — CANLI (12:15 – 13:00)

**Ekran:** Yönetici PowerShell.

```powershell
cd c:\Users\bycyc\OneDrive\Desktop\BLM4522\Proje3-Guvenlik-Erisim\tests
.\run-all.ps1
```

> "Otomasyon: `run-all.ps1` dokuz SQL script'ini sırayla çalıştırıyor ve her birini log'luyor. Sonunda özet veriyor."

Beklenen çıktı:
```
=====================================================
SUMMARY: 9/9 PASS
=====================================================
```

Ekran görüntüsü olarak da göster: `docs/08-test-runner-9-of-9.png`.

Opsiyonel olarak:
```powershell
.\verify-security.ps1
```

> "`verify-security.ps1` ise EXECUTE AS ile yedi davranışsal test yapıyor: İK'nın DENY'i, Muhasebe'nin TC görememesi, SQL injection'ın boş sonuç dönmesi... Hepsi PASS."

Ekran görüntüsü: `docs/06-yetki-testleri.png`.

---

## 4. Kapanış (13:00 – 13:30)

**Ekran:** İki RAPOR.md yan yana veya repo kökü.

> "Özetle: iki projede de veritabanı yönetiminin iki kritik boyutunu uçtan uca uyguladım. Proje 2'de yedekleme, kurtarma ve noktaya-dönüş testini otomatize ettim; felaket sonrası tüm veriyi kayıpsız geri getirebildiğimi gösterdim. Proje 3'te defense-in-depth prensibini altı katmanda uygulayıp her katmanın çalıştığını canlı test ettim."

> "Tüm kod, rapor ve ekran görüntüleri repo'da mevcut. `RAPOR.md` dosyaları detaylı teknik belgedir. Dinlediğiniz için teşekkür ederim."

---

## Çekim Kontrol Listesi (kayıttan önce)

- [ ] SQL Server servisi: `net start MSSQLSERVER` → running
- [ ] SSMS açık, `sa` veya Windows Auth ile bağlı
- [ ] PowerShell **yönetici** olarak açık, çalışma dizini `BLM4522\`
- [ ] VS Code'da proje açık, `RAPOR.md` preview modunda görünür olsun
- [ ] Tarayıcıda başka sekme yok; bildirimler kapalı (`Win+A` → Focus)
- [ ] Mikrofon test: "1-2-1-2"
- [ ] Ekran çözünürlüğü 1920×1080, tek monitör
- [ ] `tests/output/` altında başarılı bir run var mı? (göstermek için)
- [ ] `docs/` klasöründe 18 PNG mevcut mu?
- [ ] Zamanlayıcı/kronometre görünür (telefonun yanında)

## Kayıt Sonrası

- [ ] Video en az 10 dakika mı?
- [ ] Ses her yerde duyuluyor mu?
- [ ] İki projenin de demo kısmı (Proje2: disaster-recovery, Proje3: SQL injection + test runner) videoda mı?
- [ ] Export: MP4, H.264, 1080p, ~30fps
- [ ] Dosya adı: `BLM4522_OmerDogan_Proje2-3.mp4`
- [ ] eKampüs'e yükle (Nisan sonu son tarih)

---

## İpuçları

- **Acele etme.** Script okuma değil, anlatma. Cümleler arasında bir saniye nefes al.
- **Sayılarla konuş.** "Tüm veri" yerine "12 satırın 12'si". "Backup alındı" yerine "FULL backup 156 KB'lık `.bak` dosyasına yazıldı".
- **Canlı demo'larda hata olursa panik yok.** "Daha önce çalıştırmıştık, log'u burada" diyerek `tests/output/` altındaki son başarılı run'a geç.
- **Ekran geçişlerini yavaş yap.** İzleyen gözü takip edemezse kaybolur.
- **Her bölümün sonunda bir cümleyle bağla:** "Kısacası bu katman X'i çözüyor; şimdi bir sonrakine geçelim."
