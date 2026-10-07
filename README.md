# SQL_Layoffs_Project
End-to-end MySQLproject: cleaning and analyzing a global layoffs dataset to uncover trends by company, industry, and country.


# Layoffs Analysis with MySQL

Analisis data PHK perusahaan di seluruh dunia (2020-2023) menggunakan MySQL

## Dataset
Kolom : company, location, industry,
total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions.

## Yang Saya Lakukan
- Hapus duplikat pakai ROW_NUMBER()
- Standarisasi industry & country, perbaiki encoding 
- Analisis tren per bulan, industri, negara, dan perusahaan

## Temuan utama
- Perusahaan dengan PHK terbanyak: Amazon paling banyak melakukan PHK dengan kontribusi 4.73% dari total PHK
- Industri paling terdampak: Industri consumer dengan total persentase PHK 11.67%
- Tahun dengan PHK tertinggi: PHK terbanyak terjadi pada tahun 2022 dengan total 180661
- Negara yang paling terdampak : United State dengan persentase total 66.87%

