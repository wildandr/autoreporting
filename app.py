from flask import Flask, render_template, request, send_file, redirect, url_for
from docx import Document
from datetime import datetime
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import pandas as pd
import requests
import io
import base64
import os
import subprocess
import tempfile

app = Flask(__name__)

# Fungsi untuk menyalin pemformatan warna sel
def copy_cell_formatting(src_cell, dest_cell):
    tcPr = src_cell._tc.get_or_add_tcPr()
    shd = tcPr.first_child_found_in("w:shd")
    if shd is not None:
        new_tcPr = dest_cell._tc.get_or_add_tcPr()
        new_shd = OxmlElement('w:shd')
        new_shd.set(qn('w:fill'), shd.get(qn('w:fill')))
        new_shd.set(qn('w:val'), shd.get(qn('w:val')))
        new_tcPr.append(new_shd)

# Fungsi untuk menambahkan garis hitam pada sel
def add_black_borders(cell):
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for border_name in ['top', 'left', 'bottom', 'right']:
        border = OxmlElement(f'w:{border_name}')
        border.set(qn('w:val'), 'single')  # Tipe garis: single
        border.set(qn('w:sz'), '4')       # Ukuran garis: 4 (1/8 pt, cukup tebal)
        border.set(qn('w:space'), '0')    # Jarak dari teks: 0
        border.set(qn('w:color'), '000000')  # Warna: hitam (RGB: 000000)
        tcBorders.append(border)
    tcPr.append(tcBorders)

# Fungsi untuk mengubah format tanggal
def format_tanggal(tanggal_str, bulan_dict):
    if isinstance(tanggal_str, str) and tanggal_str.strip():
        try:
            # Check for "NaT" string or empty string
            if tanggal_str == "NaT" or tanggal_str == "":
                return ""
                
            dt = datetime.strptime(tanggal_str.split()[0], "%Y-%m-%d")
            hari = dt.strftime("%d")
            bulan = bulan_dict[dt.strftime("%B")]
            tahun = dt.strftime("%Y")
            return f"{hari} {bulan} {tahun}"
        except ValueError:
            # Return empty string for invalid dates
            return ""
    # Return empty string for None or empty
    return ""

# Dictionary untuk hari dan bulan dalam bahasa Indonesia
hari = {
    'Monday': 'Senin', 'Tuesday': 'Selasa', 'Wednesday': 'Rabu', 'Thursday': 'Kamis',
    'Friday': 'Jumat', 'Saturday': 'Sabtu', 'Sunday': 'Minggu'
}
bulan = {
    'January': 'Januari', 'February': 'Februari', 'March': 'Maret', 'April': 'April',
    'May': 'Mei', 'June': 'Juni', 'July': 'Juli', 'August': 'Agustus',
    'September': 'September', 'October': 'Oktober', 'November': 'November', 'December': 'Desember'
}

# Fungsi untuk mengubah dokumen Word menjadi PDF menggunakan LibreOffice
def convert_docx_to_pdf(docx_file):
    try:
        # Simpan dokumen ke file sementara
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as temp_docx:
            docx_file.save(temp_docx.name)
            temp_docx_path = temp_docx.name
        
        # Nama file PDF sementara
        temp_pdf_path = temp_docx_path.replace('.docx', '.pdf')
        
        # Konversi dengan LibreOffice
        subprocess.run([
            'libreoffice', '--headless', '--convert-to', 'pdf', 
            '--outdir', os.path.dirname(temp_pdf_path), temp_docx_path
        ], check=True, timeout=30)
        
        # Baca file PDF yang dihasilkan
        with open(temp_pdf_path, 'rb') as pdf_file:
            pdf_data = pdf_file.read()
        
        # Hapus file sementara
        os.unlink(temp_docx_path)
        os.unlink(temp_pdf_path)
        
        return pdf_data
    except Exception as e:
        print(f"Konversi PDF gagal: {str(e)}")
        
        # Pastikan file sementara dihapus
        if 'temp_docx_path' in locals() and os.path.exists(temp_docx_path):
            try:
                os.unlink(temp_docx_path)
            except:
                pass
        if 'temp_pdf_path' in locals() and os.path.exists(temp_pdf_path):
            try:
                os.unlink(temp_pdf_path)
            except:
                pass
                
        return None

# Fungsi untuk generate report
def generate_report_data(filter_date):
    # Ambil tanggal saat ini
    sekarang = datetime.now()
    nama_hari = hari[sekarang.strftime("%A")]
    nama_bulan = bulan[sekarang.strftime("%B")]
    tanggal = sekarang.strftime("%d")
    tahun = sekarang.strftime("%Y")
    waktu_laporan = f"{nama_hari}, {tanggal} {nama_bulan} {tahun}"
    
    # Format tanggal filter
    filter_tanggal = filter_date.strftime("%Y-%m-%d")
    
    # URL ekspor Google Sheets untuk file Excel
    file_id = "1wJlAUerJDxpaBRxMOLxOmcSzG5LdwUz4K8HJ3uc1v0s"
    export_url = f"https://docs.google.com/spreadsheets/d/{file_id}/export?format=xlsx"

    # Unduh file Excel langsung dari Google Sheets
    try:
        response = requests.get(export_url)
        if response.status_code == 200:
            excel_data = io.BytesIO(response.content)
            df = pd.read_excel(excel_data, sheet_name="New Format")
        else:
            return None, "Gagal mengunduh file dari Google Sheets"
    except Exception as e:
        return None, f"Error: {str(e)}"

    # Filter data berdasarkan tanggal
    df_filtered = df[df['Tanggal'] == filter_tanggal].fillna('')

    if df_filtered.empty:
        return None, f"Tidak ada data untuk tanggal {filter_tanggal}"

    # Konversi data filtered ke format yang sesuai untuk tabel
    data_baru = [
        (
            idx + 1,  # Override nomor urut agar dimulai dari 1
            row['Pekerjaan'] if not pd.isna(row['Pekerjaan']) else "",
            format_tanggal(str(row['Batas Waktu']), bulan),
            row['Status'] if not pd.isna(row['Status']) else "",
            format_tanggal(str(row['Diselesaikan Pada']), bulan)
        )
        for idx, (_, row) in enumerate(df_filtered.iterrows())
    ]

    # Ambil semua keterangan dari data yang difilter dan gabungkan
    keterangan_list = [str(row['Keterangan']).strip() for _, row in df_filtered.iterrows() if str(row['Keterangan']).strip()]
    keterangan = "\n".join(keterangan_list) if keterangan_list else "Tidak ada keterangan untuk hari ini."

    # Cek apakah template dokumen ada
    template_path = "Weekly Daily Report Wildan Dzaky Ramadhani.docx"
    if not os.path.exists(template_path):
        return None, f"Template file '{template_path}' tidak ditemukan."
        
    # Baca dokumen yang sudah ada
    doc = Document(template_path)

    # Update Waktu Laporan saja
    for para in doc.paragraphs:
        if "Waktu Laporan" in para.text:
            para.text = f"Waktu Laporan\t: {waktu_laporan}"

    # Hapus paragraf Catatan jika ada
    paragraphs_to_remove = []
    for i, para in enumerate(doc.paragraphs):
        if "Catatan" in para.text:
            paragraphs_to_remove.append(para)
    
    for para in paragraphs_to_remove:
        doc.element.body.remove(para._element)
        
    # PENDEKATAN BARU: Kita tidak menghapus tabel lama, tapi menggantinya dengan data baru
    if not doc.tables:
        return None, "Tidak dapat menemukan tabel di template dokumen."
        
    table = doc.tables[0]  # Gunakan tabel yang ada
    
    # Pertahankan baris header, hapus semua baris data (baris ke-2 dan seterusnya)
    while len(table.rows) > 1:
        tr = table.rows[1]._tr
        table._tbl.remove(tr)
        
    # Tambahkan data baru ke tabel yang ada
    for no, pekerjaan, batas_waktu, status, selesai_pada in data_baru:
        row_cells = table.add_row().cells
        row_cells[0].text = str(no)
        row_cells[1].text = pekerjaan
        row_cells[2].text = batas_waktu
        row_cells[3].text = status
        row_cells[4].text = selesai_pada
        
        # Tambahkan garis hitam
        for i in range(len(row_cells)):
            add_black_borders(row_cells[i])

    # Tambahkan Keterangan setelah tabel
    doc.add_paragraph(f"{keterangan}")
    
    # Nama file
    file_name = f"{tanggal} {nama_bulan} {tahun}_Daily Report Wildan Dzaky Ramadhani.docx"
    
    return doc, file_name

@app.route('/')
def index():
    # Get today's date in format YYYY-MM-DD for default value in form
    today = datetime.now().strftime('%Y-%m-%d')
    return render_template('index.html', today=today)

@app.route('/generate', methods=['POST'])
def generate_report():
    try:
        # Get selected date from form
        date_str = request.form.get('report_date', '')
        create_pdf = request.form.get('create_pdf') == 'on'
        
        # Parse date
        filter_date = datetime.strptime(date_str, '%Y-%m-%d')
        
        # Generate report
        doc, result = generate_report_data(filter_date)
        
        if doc is None:
            # If error occurred
            return render_template('error.html', error=result)
        
        # Create temporary file
        temp_docx = tempfile.NamedTemporaryFile(delete=False, suffix='.docx')
        temp_docx_path = temp_docx.name
        doc.save(temp_docx_path)
        
        if create_pdf:
            # Convert to PDF
            pdf_data = convert_docx_to_pdf(doc)
            if pdf_data:
                # Save PDF to temp file
                pdf_file_name = result.replace('.docx', '.pdf')
                temp_pdf = tempfile.NamedTemporaryFile(delete=False, suffix='.pdf')
                temp_pdf_path = temp_pdf.name
                with open(temp_pdf_path, 'wb') as f:
                    f.write(pdf_data)
                
                # Send PDF file
                return send_file(
                    temp_pdf_path, 
                    as_attachment=True,
                    download_name=pdf_file_name,
                    mimetype='application/pdf'
                )
                
        # Send DOCX file
        return send_file(
            temp_docx_path, 
            as_attachment=True,
            download_name=result,
            mimetype='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
        
    except Exception as e:
        return render_template('error.html', error=f"Error generating report: {str(e)}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)