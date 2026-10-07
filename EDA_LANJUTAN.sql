
-- 02b. EXPLORATORY DATA ANALYSIS (EXTENDED)
USE world_layoffs;


-- 1. OVERVIEW

-- Gambaran besar dataset
SELECT
    COUNT(*)                 AS total_events,
    COUNT(DISTINCT company)  AS total_companies,
    COUNT(DISTINCT country)  AS total_countries,
    COUNT(DISTINCT industry) AS total_industries,
    SUM(total_laid_off)      AS total_laid_off,
    ROUND(AVG(total_laid_off))  AS avg_laid_off_per_event,
    MIN(`date`)                 AS first_event,
    MAX(`date`)                 AS last_event
FROM layoffs_clean;

-- INSIGHT: Terdapat 1995 event, 1628 perusahaan, 51 negara, 31 industri dengan total PHK 383659, 
-- dengan rata-rata 237 PHK per event sejak 2020 hingga 2023

-- 2. SIAPA YANG PALING TERDAMPAK?

-- Top 10 perusahaan + persentase kontribusi terhadap total PHK
SELECT
    company,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(100 * SUM(total_laid_off) / (SELECT SUM(total_laid_off) FROM layoffs_clean), 2) AS pct_of_total
FROM layoffs_clean
GROUP BY company
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC
LIMIT 10;
-- INSIGHT: Amazon paling banyak melakukan PHK dengan kontribusi 4.73% dari total PHK


-- Industri paling terdampak + share-nya
SELECT
    industry,
    COUNT(*)            AS jumlah_event,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(100 * SUM(total_laid_off) / (SELECT SUM(total_laid_off) FROM layoffs_clean), 2) AS pct_of_total
FROM layoffs_clean
WHERE industry IS NOT NULL
GROUP BY industry
ORDER BY total_laid_off DESC;
-- INSIGHT: Industri yang paling terdampak adalah industri consumer dengan total persentase PHK 11.67%

-- 10 Negara paling terdampak + share-nya
SELECT
    country,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(100 * SUM(total_laid_off) / (SELECT SUM(total_laid_off) FROM layoffs_clean), 2) AS pct_of_total
FROM layoffs_clean
GROUP BY country
ORDER BY total_laid_off DESC
LIMIT 10;
-- INSIGHT: United State dengan persentase total 66.87%

-- 10 Kota (location) dengan PHK terbanyak
SELECT location, SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY location
HAVING total_laid_off IS NOT NULL
ORDER BY total_laid_off DESC
LIMIT 10;
-- INSIGHT: SF Bay Area dengan total PHK 125631

-- 3. TREN WAKTU
-- Total PHK per tahun
SELECT layoff_year, COUNT(*) AS jumlah_event, SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE layoff_year IS NOT NULL
GROUP BY layoff_year
ORDER BY total_laid_off DESC;
-- INSIGHT: PHK terbanyak terjadi pada tahun 2022 dengan total 180661

-- Industri apa yang paling terdampak di setiap tahun?
WITH industry_year AS (
    SELECT industry, layoff_year, SUM(total_laid_off) AS total
    FROM layoffs_clean
    WHERE industry IS NOT NULL AND layoff_year IS NOT NULL
    GROUP BY industry, layoff_year
), ranked AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY layoff_year ORDER BY total DESC) AS ranking
    FROM industry_year
    WHERE total IS NOT NULL
)
SELECT * FROM ranked WHERE ranking <= 1 ORDER BY layoff_year, ranking;
-- INSIGHT: 2020 : Transportation, 2021 : Consumer, 2022 : Retail, 2023 : Lainnya

-- 4. POLA PERUSAHAAN
-- Perusahaan yang PHK berkali-kali (lebih dari 2 putaran)
SELECT
    company,
    COUNT(*)            AS jumlah_putaran,
    SUM(total_laid_off) AS total_laid_off,
    MIN(`date`)         AS pertama,
    MAX(`date`)         AS terakhir
FROM layoffs_clean
GROUP BY company
HAVING COUNT(*) > 2
ORDER BY jumlah_putaran DESC, total_laid_off DESC;
-- INSIGHT: Terdapat 61 perusahaan yang melakukan PHK berkali-kali dengan Loft merupakan perusahaan yang melakukan 6 kali putaran PHK

-- Perusahaan yang PHK 100% karyawan (tutup), kelompokkan per industri
SELECT industry, COUNT(*) AS jumlah_perusahaan_tutup
FROM layoffs_clean
WHERE percentage_laid_off = 1
GROUP BY industry
ORDER BY jumlah_perusahaan_tutup DESC;
-- INSIGHT: terdapat 25 industry yang melalukan PHK 100% dengan total perusahaan yang tutup terbanyak berjumlah 13 dari industry retail

-- Startup tutup dengan dana terbesar (uang investor yang "hilang")
SELECT company, industry, stage, country, funds_raised_millions
FROM layoffs_clean
WHERE percentage_laid_off = 1
  AND funds_raised_millions IS NOT NULL
ORDER BY funds_raised_millions DESC
LIMIT 1;
-- INSIGHT: Perusahaan Britishvolt dengan total dana 2400
	
-- Ukuran perusahaan (estimasi) yang paling sering PHK
SELECT
    CASE
        WHEN est_company_size IS NULL   THEN 'Unknown'
        WHEN est_company_size < 100     THEN 'Kecil (< 100)'
        WHEN est_company_size < 1000    THEN 'Menengah (100 - 999)'
        WHEN est_company_size < 10000   THEN 'Besar (1.000 - 9.999)'
        ELSE 'Raksasa (>= 10.000)'
    END AS company_size,
    COUNT(*)            AS jumlah_event,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY company_size
ORDER BY total_laid_off DESC;
-- INSIGHT: Paling banyak PHK pada perusahaan raksasa, tren phk meningkat seiring ukuran perusahaan 

-- 5. QUERY UNTUK VISUALISASI (export ke CSV -> Tableau / Power BI / Excel)

-- Dataset ringkas per bulan x industri x negara
SELECT layoff_month, industry, country,
       COUNT(*) AS jumlah_event,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE layoff_month IS NOT NULL
GROUP BY layoff_month, industry, country
ORDER BY layoff_month;