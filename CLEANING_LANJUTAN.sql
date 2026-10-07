
-- A. DATA PROFILING

-- Jumlah baris: raw vs staging2
SELECT
    (SELECT COUNT(*) FROM world_layoffs.layoffs) AS raw_rows,
    (SELECT COUNT(*) FROM world_layoffs.layoffs_staging2) AS cleaned_rows;
-- Selisih jumlah : 366 (setelah dibersihkan)

-- Hitung NULL / blank per kolom
SELECT
    COUNT(*) AS total_rows,
    SUM(company IS NULL OR TRIM(company) = '') AS null_company,
    SUM(location IS NULL OR TRIM(location) = '') AS null_location,
    SUM(industry IS NULL OR TRIM(industry) = '') AS null_industry,
    SUM(total_laid_off IS NULL) AS null_total_laid_off,
    SUM(percentage_laid_off IS NULL
        OR percentage_laid_off IN ('', 'NULL')) AS null_percentage,
    SUM(`date` IS NULL) AS null_date,
    SUM(stage IS NULL OR TRIM(stage) = '') AS null_stage,
    SUM(country IS NULL OR TRIM(country) = '') AS null_country,
    SUM(funds_raised_millions IS NULL) AS null_funds
FROM world_layoffs.layoffs_staging2;
-- raw : 2361, final :1995, hapus: 366


-- B. TRIM SPASI BERLEBIH DI KOLOM TEKS
-- Cek ada berapa baris yang punya spasi di awal/akhir
SELECT COUNT(*) AS rows_with_extra_spaces
FROM world_layoffs.layoffs_staging2
WHERE company <> TRIM(company)
   OR location<> TRIM(location)
   OR industry<> TRIM(industry)
   OR stage   <> TRIM(stage)
   OR country <> TRIM(country);
-- tidak ada spasi berlebih

UPDATE world_layoffs.layoffs_staging2
SET company  = TRIM(company),
    location = TRIM(location),
    industry = TRIM(industry),
    stage    = TRIM(stage),
    country  = TRIM(country); -- Gunakan ini kalau ada spasi berlebih



-- C. STANDARDISASI KOLOM LAIN (location, stage)
-- Cek variasi penulisan lokasi
SELECT DISTINCT location
FROM world_layoffs.layoffs_staging2
ORDER BY location;
-- Ada lokasi yang punya nama aneh

UPDATE world_layoffs.layoffs_staging2
SET location = CONVERT(CAST(CONVERT(location USING latin1) AS BINARY) USING utf8mb4)
WHERE location LIKE '%Ã%';

-- Cek lagi
SELECT DISTINCT location
FROM world_layoffs.layoffs_staging2
ORDER BY location;

-- Cek stage: ada 'Unknown' dan NULL yang artinya sama
SELECT stage, COUNT(*) AS jumlah
FROM world_layoffs.layoffs_staging2
GROUP BY stage
ORDER BY jumlah DESC;

-- Samakan NULL stage jadi 'Unknown' supaya group by lebih rapi
UPDATE world_layoffs.layoffs_staging2
SET stage = 'Unknown'
WHERE stage IS NULL OR TRIM(stage) = '';

-- Cek inkonsistensi huruf besar/kecil pada industry & country
-- (kalau hasil > 1 untuk satu nama, berarti ada duplikat versi huruf)
SELECT LOWER(industry) AS industry_lower, COUNT(DISTINCT industry) AS variasi
FROM world_layoffs.layoffs_staging2
GROUP BY LOWER(industry)
HAVING COUNT(DISTINCT industry) > 1;

-- Tidak adaa

SELECT LOWER(country) AS country_lower, COUNT(DISTINCT country) AS variasi
FROM world_layoffs.layoffs_staging2
GROUP BY LOWER(country)
HAVING COUNT(DISTINCT country) > 1;

-- D. UBAH TIPE DATA percentage_laid_off (TEXT  ke DECIMAL)
-- Supaya bisa dihitung langsung (AVG, perkalian, dll) tanpa CAST

-- Ubah string kosong / 'NULL' jadi NULL asli
UPDATE world_layoffs.layoffs_staging2
SET percentage_laid_off = NULL
WHERE percentage_laid_off IN ('', 'NULL');

ALTER TABLE world_layoffs.layoffs_staging2
MODIFY COLUMN percentage_laid_off DECIMAL(5,4);



-- E. VALIDASI NILAI (cek logika data, cari outlier / data aneh)

-- Persentase harus di antara 0 dan 1
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE percentage_laid_off < 0 OR percentage_laid_off > 1;

-- Jumlah PHK tidak boleh negatif / nol
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE total_laid_off <= 0;

-- Dana yang dikumpulkan tidak boleh negatif
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE funds_raised_millions < 0;

-- Rentang tanggal masuk akal (tidak ada tanggal di masa depan / terlalu lama)
SELECT MIN(`date`) AS tanggal_awal, MAX(`date`) AS tanggal_akhir
FROM world_layoffs.layoffs_staging2;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE `date` > CURDATE() OR `date` < '2019-01-01';

-- Baris dengan tanggal NULL (cek apakah masih layak dipakai)
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE `date` IS NULL;


-- F. FEATURE ENGINEERING: kolom turunan untuk memudahkan EDA
ALTER TABLE world_layoffs.layoffs_staging2
    ADD COLUMN layoff_year    INT,
    ADD COLUMN layoff_month   VARCHAR(7), -- format 'YYYY-MM'
    ADD COLUMN layoff_quarter VARCHAR(7), -- format 'YYYY-Qn'
    ADD COLUMN est_company_size INT;      -- estimasi jumlah karyawan sebelum PHK

UPDATE world_layoffs.layoffs_staging2
SET layoff_year    = YEAR(`date`),
    layoff_month   = DATE_FORMAT(`date`, '%Y-%m'),
    layoff_quarter = CONCAT(YEAR(`date`), '-Q', QUARTER(`date`)),
    est_company_size = CASE
        WHEN percentage_laid_off > 0
         AND total_laid_off IS NOT NULL
        THEN ROUND(total_laid_off / percentage_laid_off)
        ELSE NULL
    END
WHERE `date` IS NOT NULL;

-- Cek hasilnya
SELECT company, `date`, total_laid_off, percentage_laid_off,
       layoff_year, layoff_month, layoff_quarter, est_company_size
FROM world_layoffs.layoffs_staging2
LIMIT 20;



-- G. INDEX: mempercepat query EDA
CREATE INDEX idx_company  ON world_layoffs.layoffs_staging2 (company(50));
CREATE INDEX idx_industry ON world_layoffs.layoffs_staging2 (industry(50));
CREATE INDEX idx_country  ON world_layoffs.layoffs_staging2 (country(50));
CREATE INDEX idx_date     ON world_layoffs.layoffs_staging2 (`date`);

-- H. FINAL: bikin tabel bersih + data quality summary
-- Tabel final yang dipakai untuk EDA & visualisasi
DROP TABLE IF EXISTS world_layoffs.layoffs_clean;

CREATE TABLE world_layoffs.layoffs_clean AS
SELECT * FROM world_layoffs.layoffs_staging2;

-- Ringkasan hasil cleaning
SELECT
    (SELECT COUNT(*) FROM world_layoffs.layoffs)       AS raw_rows,
    (SELECT COUNT(*) FROM world_layoffs.layoffs_clean) AS final_rows,
    (SELECT COUNT(*) FROM world_layoffs.layoffs)
      - (SELECT COUNT(*) FROM world_layoffs.layoffs_clean) AS rows_removed;
      
      
      
      