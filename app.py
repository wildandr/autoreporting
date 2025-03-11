from flask import Flask, render_template, request, send_file, Response
from docx import Document
from datetime import datetime
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import pandas as pd
import requests
import io
import base64
import os
from werkzeug.utils import secure_filename
import tempfile
import subprocess

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

def generate_docx_report(filter_date):
    # Ambil tanggal dari parameter
    sekarang = filter_date if filter_date else datetime.now()
    nama_hari = hari[sekarang.strftime("%A")]
    nama_bulan = bulan[sekarang.strftime("%B")]
    tanggal = sekarang.strftime("%d")
    tahun = sekarang.strftime("%Y")
    waktu_laporan = f"{nama_hari}, {tanggal} {nama_bulan} {tahun}"
    
    # Format untuk filter
    filter_tanggal = sekarang.strftime("%Y-%m-%d")
    
    # Nama file untuk download
    file_name = f"{tanggal} {nama_bulan} {tahun}_Daily Report Wildan Dzaky Ramadhani.docx"
    
    # URL ekspor Google Sheets untuk file Excel
    file_id = "1wJlAUerJDxpaBRxMOLxOmcSzG5LdwUz4K8HJ3uc1v0s"
    export_url = f"https://docs.google.com/spreadsheets/d/{file_id}/export?format=xlsx"

    # Unduh file Excel langsung dari Google Sheets
    try:
        response = requests.get(export_url)
        if response.status_code != 200:
            return {"error": f"Gagal mengunduh file: status code {response.status_code}"}, None
        excel_data = io.BytesIO(response.content)
        df = pd.read_excel(excel_data, sheet_name="New Format")
    except Exception as e:
        return {"error": f"Gagal mengunduh file: {str(e)}"}, None

    # Filter data berdasarkan tanggal
    df_filtered = df[df['Tanggal'] == filter_tanggal].fillna('')  # Ganti NaN dengan string kosong

    if df_filtered.empty:
        return {"error": f"Tidak ada data untuk tanggal {filter_tanggal}"}, None

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
        return {"error": f"Template file '{template_path}' tidak ditemukan."}, None
            
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
        return {"error": "Tidak dapat menemukan tabel di template dokumen."}, None
            
    table = doc.tables[0]  # Gunakan tabel yang ada
    
    # Pertahankan baris header, hapus semua baris data (baris ke-2 dan seterusnya)
    # Ini mempertahankan semua format dan style
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

    # Simpan ke BytesIO
    docx_io = io.BytesIO()
    doc.save(docx_io)
    docx_io.seek(0)
    
    return {"success": True, "file_name": file_name}, docx_io

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        filter_date_str = request.form.get('filter_date')
        format_type = request.form.get('format_type', 'docx')  # Get the chosen format
        
        # Parse date string to datetime object
        try:
            filter_date = datetime.strptime(filter_date_str, "%Y-%m-%d")
        except:
            filter_date = datetime.now()
        
        # Generate the DOCX report first
        result, docx_io = generate_docx_report(filter_date)
        
        if 'error' in result:
            return render_template('index.html', error=result['error'], date=datetime.now().strftime("%Y-%m-%d"))
        
        # Generate file name
        nama_hari = hari[filter_date.strftime("%A")]
        nama_bulan = bulan[filter_date.strftime("%B")]
        tanggal = filter_date.strftime("%d")
        tahun = filter_date.strftime("%Y")
        base_filename = f"{tanggal} {nama_bulan} {tahun}_Daily Report Wildan Dzaky Ramadhani"
        
        # Return according to format requested
        if format_type == 'docx':
            # Send the DOCX file directly
            return send_file(
                docx_io, 
                mimetype='application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                as_attachment=True,
                download_name=f"{base_filename}.docx"
            )
        elif format_type == 'pdf':
            # Convert to PDF using LibreOffice
            with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as temp_docx:
                temp_docx.write(docx_io.getvalue())
                temp_docx_path = temp_docx.name
            
            # Output PDF path
            temp_pdf_path = temp_docx_path.replace('.docx', '.pdf')
            
            try:
                # Use LibreOffice for conversion (headless mode)
                subprocess.run([
                    'libreoffice', '--headless', '--convert-to', 'pdf',
                    '--outdir', os.path.dirname(temp_pdf_path),
                    temp_docx_path
                ], check=True)
                
                pdf_output_path = os.path.join(
                    os.path.dirname(temp_docx_path),
                    os.path.basename(temp_docx_path).replace('.docx', '.pdf')
                )
                
                # Send the PDF file
                return send_file(
                    pdf_output_path,
                    mimetype='application/pdf',
                    as_attachment=True,
                    download_name=f"{base_filename}.pdf"
                )
            except Exception as e:
                return render_template('index.html', error=f"Error converting to PDF: {str(e)}", date=datetime.now().strftime("%Y-%m-%d"))
            finally:
                # Clean up temporary files
                if os.path.exists(temp_docx_path):
                    os.unlink(temp_docx_path)
                if os.path.exists(temp_pdf_path) and os.path.isfile(temp_pdf_path):
                    os.unlink(temp_pdf_path)
    
    # GET request or initial page load
    return render_template('index.html', date=datetime.now().strftime("%Y-%m-%d"))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

