# Proje 5 — Veri Temizleme ve ETL Süreçleri Tasarımı

**Ders:** BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri
**Öğrenci:** Ömer Doğan
**Platform:** Microsoft SQL Server
**Veritabanı:** `TemizlemeDB` (proje kapsamında oluşturulan kirli ham veri + hedef)

---

## 1. Amaç ve Gereksinim Karşılığı

İki farklı kaynaktan gelen **kirli ham veriyi** uçtan uca bir **ETL** (Extract-Transform-Load) hattıyla temizleyip standartlaştırarak hedef tabloya yüklemek. 5 SQL script'i = 5 gereksinim:

| # | Resmî Gereksinim | Script |
|---|------------------|--------|
| 1 | Hatalı/eksik/tutarsız ham veri kümesi oluştur | [`01_setup_raw_data.sql`](./sql/01_setup_raw_data.sql) |
| 2 | SQL ile veri temizleme (cleansing) | [`03_transform_clean.sql`](./sql/03_transform_clean.sql) |
| 3 | Farklı kaynakları standartlaştır / dönüştür (transform) | [`03_transform_clean.sql`](./sql/03_transform_clean.sql) |
| 4 | Temiz veriyi hedef tabloya yükle (load) | [`04_load_target.sql`](./sql/04_load_target.sql) |
| 5 | Veri kalitesi raporu | [`02_data_profiling.sql`](./sql/02_data_profiling.sql) (öncesi) + [`05_quality_report.sql`](./sql/05_quality_report.sql) (öncesi/sonrası) |

## 2. Çalıştırma

```powershell
net start MSSQLSERVER         # gerekirse (yönetici)
cd Proje5-ETL-Veri-Temizleme\tests
.\run-all.ps1                 # 5/5 PASS
```

## 3. Ham Veri — İki Kaynak ([`01`](./sql/01_setup_raw_data.sql))

`stg_kaynakA` (1200+) ve `stg_kaynakB` (800+) tabloları, **kasıtlı kirli** ve **farklı formatlı** veriler içerir:

| Alan | Kaynak A | Kaynak B | Kirlilik |
|------|----------|----------|----------|
| telefon | `05XX XXX XX XX` | `+90-5XX-XXXXXXX` | format farkı, NULL, parantez |
| tarih | `GG.AA.YYYY` (str) | `YYYY/AA/GG` (str) | format farkı, geçersiz (`32.13.2020`) |
| cinsiyet | `Erkek/Kadin`, `E`, `kadin` | `E`/`K` | kodlama farkı |
| email | bazı `@` yok / boşluklu / NULL | boşluklu / NULL | geçersiz, eksik |
| ad/sehir | `  Ad  `, `ISTANBUL`, `ist.` | `Istanbul/TR` | boşluk, büyük/küçük, kısaltma |

Ayrıca açık **duplike** ve uç-durum kayıtları (aynı kişi iki kaynakta farklı yazımla).

## 4. Temizleme + Dönüştürme ([`03`](./sql/03_transform_clean.sql)) — Gereksinim 2 & 3

Tek sorguda standartlaştırma:

- **ad/soyad:** `LTRIM/RTRIM` + Proper Case
- **email:** trim + lower + format doğrulama (`LIKE '%_@_%._%'`); geçersizse `NULL`
- **telefon:** `TRANSLATE`+`REPLACE` ile rakam-dışı karakter temizliği → son 10 hane → `+90##########`
- **sehir:** tutarsız yazımları prefix eşleme ile tek standarda (`Istanbul`, `Ankara`, ...)
- **cinsiyet:** ilk harfe göre `Erkek`/`Kadin`
- **tarih:** kaynağa göre `TRY_CONVERT` (A=104, B=111); geçersiz → `NULL`
- **dedup:** normalize email'e göre `ROW_NUMBER() ... PARTITION BY` ile tekrarları ele (email yoksa benzersiz fallback)

## 5. Hedefe Yükleme ([`04`](./sql/04_load_target.sql)) — Gereksinim 4

`DimMusteri` (surrogate `musteri_key` + business key `is_anahtar`) tablosuna **`MERGE` (UPSERT)** ile yükleme: yeni kayıt INSERT, değişen UPDATE. MERGE sayesinde script **tekrar çalıştırıldığında duplike oluşmaz** (idempotent).

## 6. Veri Kalitesi Raporu ([`05`](./sql/05_quality_report.sql)) — Gereksinim 5

`run-all.ps1` çıktısından alınan **gerçek** öncesi/sonrası karşılaştırma:

| Metrik | Öncesi (ham) | Sonrası (hedef) |
|--------|---:|---:|
| Toplam satır | 2006 | 2004 (dedup) |
| Geçerli/dolu email | 1355 | **1672** |
| Baş/son boşluklu ad | 301 | **0** |
| Farklı şehir yazımı (distinct) | 8 | **5** |
| Farklı cinsiyet yazımı (distinct) | 4 | **2** |
| Parse edilemeyen / NULL tarih | 82 | 82 |
| Duplike email | 2 | **0** |

**Tamlık (completeness):** Şehir %100, Tarih %95.9, Telefon %89.7, Email %83.4.

> Not: Geçerli email sayısı 1355 → 1672'ye **yükselir**; çünkü yalnızca boşluk yüzünden geçersiz sayılan ~317 email trim ile kurtarıldı. Parse edilemeyen 82 tarih (örn. `32.13.2020`) gerçekten geçersiz olduğundan `NULL` bırakıldı — bu doğru davranıştır.

## 7. Ekran Görüntüleri

`run-all.ps1` sonrası [`docs/`](./docs) altına: `01-ham-veri.png`, `02-profiling.png`, `03-temiz-ornek.png`, `05-oncesi-sonrasi.png`, `06-test-runner.png`.

## 8. Referanslar

- ETL kavramları — https://learn.microsoft.com/sql/integration-services/
- `TRY_CONVERT` — https://learn.microsoft.com/sql/t-sql/functions/try-convert-transact-sql
- `MERGE` — https://learn.microsoft.com/sql/t-sql/statements/merge-transact-sql
- `TRANSLATE` — https://learn.microsoft.com/sql/t-sql/functions/translate-transact-sql
