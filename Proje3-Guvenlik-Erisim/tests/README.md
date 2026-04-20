# Proje 3 — Otomatik Test Runner

Bu klasör, `sql/` altındaki script'leri otomatik olarak çalıştırıp doğrulayan PowerShell runner'larını içerir.

## Ön Koşullar

1. SQL Server servisi çalışıyor olmalı (yönetici olarak):
   ```powershell
   net start MSSQLSERVER
   ```
2. `sqlcmd` yüklü olmalı (SQL Server kurulumu ile gelir).
3. PowerShell 5.1+ (Windows 10/11 varsayılan).

## Kullanım

### 1. Tüm script'leri sırayla çalıştır (kurulum + test)

```powershell
cd Proje3-Guvenlik-Erisim\tests
.\run-all.ps1
```

- 9 SQL script'i sırasıyla `sqlcmd` ile çalıştırılır.
- Her script'in tam çıktısı `tests\output\run_YYYYMMDD_HHMMSS\<dosya>.log` dosyasına kaydedilir.
- Sonda PASS/FAIL tablosu ve `SUMMARY.txt` üretilir.
- `01_setup_database.sql` başarısız olursa kalanlar atlanır.

### 2. Sadece yetki testlerini tekrar çalıştır

```powershell
.\run-all.ps1 -OnlyTest
```

Setup zaten yapılmışsa sadece `09_test_permissions.sql` koşar.

### 3. Davranışsal doğrulama (assertion tests)

```powershell
.\verify-security.ps1
```

`run-all.ps1` script'lerin **hatasız çalıştığını** doğrular. `verify-security.ps1` ise **güvenlik kurallarının gerçekten uygulandığını** doğrular:

| Test | Beklenen |
|------|----------|
| T1 | `ik_okuyucu` → `vw_PersonelIK` SELECT = **OK** |
| T2 | `ik_okuyucu` → `Personel` SELECT = **DENY** |
| T3 | `muh_yazar` → `vw_PersonelMaas` SELECT = **OK** |
| T4 | `muh_yazar` → `Personel.TCKimlikNo` SELECT = **DENY** |
| T5 | `muh_yazar` → `Personel` INSERT = **DENY** |
| T6 | `yazilim_sef` → `Personel` COUNT < 5 (RLS) |
| T7 | SQL Injection girdisi — güvenli sp'de 0 satır döner |

### 4. Farklı sunucu / instance

```powershell
.\run-all.ps1 -Server "MAKINE\SQLEXPRESS"
```

## Tipik Sorunlar

- **"Could not open a connection to SQL Server [2]"** → Servis durmuş.
  `net start MSSQLSERVER` (yönetici).
- **"CREATE LOGIN ... parola politikasına uymuyor"** → Windows parola politikası sert.
  `02_auth_modes.sql` içindeki parolaları güçlendir.
- **TDE sertifikası hatası** → `04_tde_encryption.sql` her koşuda yeni sertifika üretir; önceki `PersonelDB` şifreli kalırsa `DROP DATABASE` adımında takılır. İlk koşuda sorun olmaz, tekrar koşularda `master` üzerinde eski sertifikayı manuel düşürmek gerekebilir.

## Çıktılar (örnek)

```
tests/
└── output/
    └── run_20260420_143022/
        ├── 01_setup_database.log
        ├── 02_auth_modes.log
        ├── ...
        ├── 09_test_permissions.log
        └── SUMMARY.txt
```

`output/` klasörü `.gitignore` ile dışlanır.
