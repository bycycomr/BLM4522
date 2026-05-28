# Proje 1 — Veritabanı Performans Optimizasyonu ve İzleme

**Ders:** BLM4522 — Ağ Tabanlı Paralel Dağıtım Sistemleri
**Öğrenci:** Ömer Doğan
**Platform:** Microsoft SQL Server
**Örnek Veritabanı:** `SatisDB` (proje kapsamında üretilen ~270.000 satırlık e-ticaret simülasyonu)

---

## 1. Amaç ve Gereksinim Karşılığı

Bu proje, büyük bir veritabanında **performans darboğazlarını ölç → analiz et → iyileştir → tekrar ölç** döngüsünü uçtan uca uygular. Ödevin 6 gereksinimi, 5 SQL script'i ile birebir karşılanır:

| # | Resmî Gereksinim | Nerede |
|---|------------------|--------|
| 1 | Büyük veritabanı + performans teknikleri | Tüm script'ler ([`sql/`](./sql)) |
| 2 | Sorgu optimizasyonu, disk alanı, veri yoğunluğu | [`04_disk_ve_yogunluk.sql`](./sql/04_disk_ve_yogunluk.sql) |
| 3 | SQL Profiler / DMV ile izleme | [`02_izleme_ve_analiz.sql`](./sql/02_izleme_ve_analiz.sql) |
| 4 | Doğru indeksleme + gereksiz indeks kaldırma | [`03_indeksleme.sql`](./sql/03_indeksleme.sql) |
| 5 | Uzun süren sorgu analizi ve iyileştirme | `02` (analiz) → `03` (iyileştirme) |
| 6 | Farklı roller için erişim yönetimi | [`05_roller_ve_erisim.sql`](./sql/05_roller_ve_erisim.sql) |

## 2. Ortam ve Çalıştırma

- **DBMS:** Microsoft SQL Server, **Araç:** `sqlcmd` / SSMS, **OS:** Windows 11
- Önce servis başlatılır (yönetici PowerShell): `net start MSSQLSERVER`
- Tüm script'leri sırayla çalıştırmak için:
  ```powershell
  cd Proje1-Performans-Optimizasyonu\tests
  .\run-all.ps1
  ```
- Veya tek tek: `sqlcmd -S . -E -C -I -b -i sql\01_setup_database.sql`

## 3. Veritabanı Şeması ([`01_setup_database.sql`](./sql/01_setup_database.sql))

E-ticaret satış modeli; en büyük tablo `SiparisDetay` ~200.000 satır:

```
Kategori (20) ─< Urun (500) ─< SiparisDetay (200.000) >─ Siparis (50.000) >─ Musteri (20.000)
```

**Tasarım kararı (önemli):** Tablolar **kasıtlı olarak sub-optimal** kurulur — sadece PRIMARY KEY'ler vardır, sorgularda kullanılan filtre/join sütunlarında (`MusteriID`, `SiparisID`, `Sehir`, `SiparisTarihi`) indeks **yoktur**. Ayrıca iş yükünde hiç kullanılmayan 3 **gereksiz/duplike indeks** eklenir. Böylece sonraki adımlar gerçek bir "önce/sonra" iyileştirmesi gösterebilir.

## 4. İzleme ve Analiz ([`02_izleme_ve_analiz.sql`](./sql/02_izleme_ve_analiz.sql)) — Gereksinim 3 & 5

İndeks **öncesi** temsili bir rapor sorgusu (İstanbul'lu müşterilerin 2025 cirosu) `SET STATISTICS IO/TIME` ile ölçülür. İndeks olmadığı için sorgu büyük tabloları **tarar (scan)** → yüksek *logical reads*.

Kullanılan DMV'ler:

| DMV | Ne gösterir |
|-----|-------------|
| `sys.dm_db_missing_index_*` | Optimizer'ın önerdiği eksik indeksler |
| `sys.dm_exec_query_stats` + `dm_exec_sql_text` | En pahalı (en çok okuma yapan) sorgular |
| `sys.dm_os_wait_stats` | Sistem neyi bekliyor (CPU / disk / kilit) |
| `sys.dm_db_index_usage_stats` | İndeks okuma/güncelleme sayıları (ölü indeks tespiti) |

**SQL Profiler notu:** Profiler bir GUI aracıdır; modern ve düşük maliyetli eşdeğeri **Extended Events**'tir. 100 ms'den uzun süren sorguları yakalayan hazır bir XEvents oturumu script'in sonunda (yorum bloğunda) verilmiştir.

## 5. İndeksleme ([`03_indeksleme.sql`](./sql/03_indeksleme.sql)) — Gereksinim 4

**A) Doğru indeksler** (02'deki önerilere göre):

| İndeks | Tür | Amaç |
|--------|-----|------|
| `IX_Siparis_MusteriID` | Nonclustered + INCLUDE | Müşteri-Sipariş join'i (covering) |
| `IX_Siparis_Tarih` | Nonclustered | Tarih aralığı filtresi |
| `IX_SiparisDetay_SiparisID` | Nonclustered + INCLUDE | Sipariş-Detay join'i (covering) |
| `IX_Musteri_Sehir` | Nonclustered + INCLUDE | Şehir filtresi (covering) |
| `IX_Siparis_Aktif` | **Filtered** (`Durum <> 'Iptal'`) | Yalnız aktif siparişler — küçük & hızlı |

**B) Sonuç (ölçülen):** Aynı sorgu tekrar ölçülür → scan yerine **index seek**. `tests\run-all.ps1` çıktısından alınan gerçek `logical reads` değerleri:

| Tablo | Baseline (indekssiz) | İndeks sonrası | Kazanç |
|-------|---------:|---------:|--------|
| `Musteri` | 301 | **19** | %94 ↓ (scan → seek) |
| `Siparis` | 212 | **65** | %69 ↓ |
| `SiparisDetay` | 945 | 770 | %19 ↓ |

`Musteri` ve `Siparis` tablolarında tablo taraması ortadan kalkıp index seek'e dönüştüğü için okuma maliyeti dramatik biçimde düşmüştür.

**C) Gereksiz indekslerin kaldırılması:** `dm_db_index_usage_stats` ile hiç okunmayan (ölü) indeksler ve aynı anahtarlı **duplike** indeksler tespit edilir; `IX_Musteri_Soyad`, `IX_Urun_StokAdedi`, `IX_Musteri_Email_dup` düşürülür (gereksiz indeks = boşa disk + her INSERT/UPDATE'te ek maliyet).

## 6. Disk Alanı ve Veri Yoğunluğu ([`04_disk_ve_yogunluk.sql`](./sql/04_disk_ve_yogunluk.sql)) — Gereksinim 2

- **Disk kullanımı:** tablo bazında ayrılan/kullanılan/veri MB; veri dosyası doluluk/boş alan.
- **Veri yoğunluğu / fragmentasyon:** `sys.dm_db_index_physical_stats` ile `avg_fragmentation_in_percent` ve `avg_page_space_used_in_percent`. Microsoft kuralı: **>%5 → REORGANIZE, >%30 → REBUILD**.
- **Bakım:** `SiparisDetay` clustered indeksi `FILLFACTOR=90` ile REBUILD, `Siparis` REORGANIZE, ardından `UPDATE STATISTICS ... WITH FULLSCAN`.
- **Sıkıştırma:** `sp_estimate_data_compression_savings` ile PAGE sıkıştırma kazancı tahmin edilir, sonra `DATA_COMPRESSION = PAGE` uygulanır → disk + I/O tasarrufu (`sp_spaceused` ile önce/sonra karşılaştırılır).

## 7. Rol Tabanlı Erişim ([`05_roller_ve_erisim.sql`](./sql/05_roller_ve_erisim.sql)) — Gereksinim 6

En az yetki (least privilege) ilkesiyle 3 rol:

| Rol | Login | Yetki |
|-----|-------|-------|
| `rol_rapor_okuyucu` | `rapor_user` | Yalnız `SELECT` (raporlama) |
| `rol_veri_giris` | `giris_user` | `SELECT/INSERT/UPDATE` (operasyon) |
| `rol_perf_izleyici` | `izleme_user` | `VIEW SERVER/DATABASE STATE` (DMV), veriye `DENY` |

`EXECUTE AS USER` ile test edilir: rapor kullanıcısının INSERT denemesi **engellenir**; izleme kullanıcısı DMV görür ama `SiparisDetay` verisine erişimi **DENY** ile reddedilir (DENY her zaman GRANT'i ezer).

## 8. Sonuç

Büyük bir veritabanında darboğaz ölçüldü (DMV + STATISTICS IO/TIME), doğru indekslerle scan→seek dönüşümü ve *logical reads* düşüşü sağlandı, ölü/duplike indeksler temizlendi, fragmentasyon giderilip veri PAGE sıkıştırma ile küçültüldü ve rol tabanlı erişim least-privilege ile kuruldu. Tüm adımlar [`sql/`](./sql) altındaki çalıştırılabilir script'lerde belgelidir.

## 9. Ekran Görüntüleri

`tests\run-all.ps1` çalıştırıldıktan sonra alınan görüntüler [`docs/`](./docs) altına eklenir:

| Dosya | İçerik | Bölüm |
|-------|--------|-------|
| `01-veri-ozeti.png` | Tablo satır sayıları / boyut | §3 |
| `02-baseline-io.png` | İndeks öncesi yüksek logical reads | §4 |
| `03-after-io.png` | İndeks sonrası düşük logical reads (seek) | §5 |
| `04-fragmentasyon.png` | Fragmentasyon / sıkıştırma kazancı | §6 |
| `05-roller-test.png` | EXECUTE AS yetki testleri | §7 |
| `06-test-runner.png` | `run-all.ps1` — 5/5 PASS | — |

## 10. Referanslar

- Monitoring & Tuning — https://learn.microsoft.com/sql/relational-databases/performance/
- Missing Index DMVs — https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details
- Index fragmentation & maintenance — https://learn.microsoft.com/sql/relational-databases/indexes/reorganize-and-rebuild-indexes
- Data Compression — https://learn.microsoft.com/sql/relational-databases/data-compression/data-compression
- Extended Events — https://learn.microsoft.com/sql/relational-databases/extended-events/extended-events
