# Daily Report Generator

Aplikasi web untuk membuat laporan harian berdasarkan data dari Google Sheets.

## Fitur

- Mengambil data dari Google Sheets
- Menghasilkan laporan dalam format DOCX
- Mengkonversi laporan ke format PDF
- Antarmuka web yang mudah digunakan

## Persyaratan Sistem

- Linux Ubuntu (18.04 atau lebih baru)
- Python 3.7 atau lebih baru
- LibreOffice (untuk konversi PDF)
- Koneksi internet (untuk mengakses data dari Google Sheets)

## Instalasi di Linux Ubuntu

### 1. Update sistem dan instal paket yang diperlukan

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv libreoffice
```

### 2. Siapkan direktori aplikasi

```bash
mkdir -p ~/daily_report_app
cp streamlit.py ~/daily_report_app/
cp "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ~/daily_report_app/
```

### 3. Buat dan aktifkan virtual environment

```bash
cd ~/daily_report_app
python3 -m venv venv
source venv/bin/activate
```

### 4. Instal library Python yang diperlukan

```bash
pip install streamlit python-docx pandas requests
```

## Menjalankan Aplikasi

### Metode 1: Langsung dari Terminal

```bash
cd ~/daily_report_app
source venv/bin/activate
streamlit run streamlit.py --server.address=0.0.0.0 --server.port=8501
```

### Metode 2: Sebagai Layanan Systemd

1. Buat file service systemd:

```bash
sudo nano /etc/systemd/system/daily-report.service
```

2. Salin konfigurasi berikut (ganti `<username>` dengan nama pengguna Anda):

```
[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=<username>
WorkingDirectory=/home/<username>/daily_report_app
ExecStart=/home/<username>/daily_report_app/venv/bin/streamlit run streamlit.py --server.address=0.0.0.0 --server.port=8501
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

3. Aktifkan dan jalankan service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable daily-report
sudo systemctl start daily-report
```

4. Cek status service:

```bash
sudo systemctl status daily-report
```

## Akses Aplikasi

Buka browser web dan akses aplikasi di alamat:

```
http://<IP-SERVER>:8501
```

Ganti `<IP-SERVER>` dengan alamat IP komputer/server Ubuntu Anda.

### Membuka Firewall (jika diperlukan)

Jika menggunakan UFW firewall, buka port 8501 dengan perintah:

```bash
sudo ufw allow 8501/tcp
```

## Pemecahan Masalah

1. Jika aplikasi tidak dapat diakses dari jaringan, pastikan:
   - Alamat server sudah dikonfigurasi dengan benar (`--server.address=0.0.0.0`)
   - Port 8501 sudah terbuka di firewall
   - Server dan klien berada dalam jaringan yang sama

2. Jika konversi PDF gagal, pastikan:
   - LibreOffice terinstal dengan benar
   - Template dokumen Word berada di direktori yang sama dengan aplikasi

## Konversi PDF

Aplikasi ini mendukung konversi dokumen Word (DOCX) ke PDF menggunakan library `docx2pdf`. Library ini memerlukan Java Runtime Environment (JRE) untuk berfungsi dengan baik.

### Prasyarat untuk Konversi PDF

1. Java Runtime Environment (JRE) terinstal di sistem
2. Library Python `docx2pdf` terinstal

### Instalasi Dependensi

Untuk menginstal semua dependensi yang diperlukan, jalankan:

```bash
sudo bash install_docx2pdf.sh
```

### Troubleshooting Konversi PDF

Jika konversi PDF gagal, coba langkah-langkah berikut:

1. Pastikan Java terinstal:
   ```bash
   java -version
   ```

2. Instal JRE jika belum ada:
   ```bash
   sudo apt-get install -y default-jre
   ```

3. Verifikasi bahwa docx2pdf dapat menemukan Java:
   ```bash
   python3 -c "import os; print('JAVA_HOME:', os.environ.get('JAVA_HOME'))"
   ```

4. Setel JAVA_HOME secara manual jika diperlukan:
   ```bash
   export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
   ```

## Penggunaan

1. Buka aplikasi di browser
2. Pilih tanggal untuk laporan
3. Centang opsi "Buat juga versi PDF" jika ingin mengunduh PDF
4. Klik "Generate Report"
5. Klik link yang muncul untuk mengunduh file DOCX dan PDF
