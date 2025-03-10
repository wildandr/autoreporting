import streamlit as st
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

# Set page title
st.set_page_config(page_title="Daily Report Generator", layout="wide")
st.title("Daily Report Generator - Wildan Dzaky Ramadhani")

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
            dt = datetime.strptime(tanggal_str.split()[0], "%Y-%m-%d")
            hari = dt.strftime("%d")
            bulan = bulan_dict[dt.strftime("%B")]
            tahun = dt.strftime("%Y")
            return f"{hari} {bulan} {tahun}"
        except ValueError:
            return tanggal_str  # Kembalikan asli jika format tidak sesuai
    return tanggal_str  # Kembalikan asli jika kosong atau bukan string

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

# Fungsi untuk mengubah dokumen Word menjadi file yang dapat diunduh
def create_download_link(docx_file, filename):
    # Simpan dokumen ke BytesIO
    doc_io = io.BytesIO()
    docx_file.save(doc_io)
    doc_io.seek(0)
    
    # Encode untuk download link
    b64 = base64.b64encode(doc_io.read()).decode()
    return f'<a href="data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,{b64}" download="{filename}">Download {filename}</a>'

# Fungsi untuk mengubah dokumen Word menjadi file PDF yang dapat diunduh
def convert_docx_to_pdf(docx_file):
    # Untuk deployment di Streamlit Cloud, konversi PDF dengan LibreOffice tidak tersedia
    # Jadi hanya menyediakan file DOCX
    st.warning("Konversi ke PDF tidak tersedia di server. Hanya file DOCX yang dapat diunduh.")
    return None

# Fungsi untuk membuat link download PDF
def create_pdf_download_link(pdf_data, filename):
    b64 = base64.b64encode(pdf_data).decode()
    return f'<a href="data:application/pdf;base64,{b64}" download="{filename}">Download {filename}</a>'

# Main function untuk streamlit
def generate_report():
    # Ambil tanggal saat ini
    sekarang = datetime.now()
    nama_hari = hari[sekarang.strftime("%A")]
    nama_bulan = bulan[sekarang.strftime("%B")]
    tanggal = sekarang.strftime("%d")
    tahun = sekarang.strftime("%Y")
    waktu_laporan = f"{nama_hari}, {tanggal} {nama_bulan} {tahun}"
    
    # Nama file untuk download
    file_name = f"{tanggal} {nama_bulan} {tahun}_Daily Report Wildan Dzaky Ramadhani.docx"
    
    # Tanggal filter (untuk default gunakan tanggal saat ini)
    filter_date = st.date_input("Pilih tanggal untuk laporan:", sekarang)
    filter_tanggal = filter_date.strftime("%Y-%m-%d")
    
    if st.button("Generate Report"):
        with st.spinner('Generating report...'):
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
                    st.error(f"Gagal mengunduh file: status code {response.status_code}")
                    return
            except Exception as e:
                st.error(f"Gagal mengunduh file: {str(e)}")
                return

            # Filter data berdasarkan tanggal
            df_filtered = df[df['Tanggal'] == filter_tanggal].fillna('')  # Ganti NaN dengan string kosong

            if df_filtered.empty:
                st.warning(f"Tidak ada data untuk tanggal {filter_tanggal}")
                return

            # Konversi data filtered ke format yang sesuai untuk tabel
            data_baru = [
                (
                    idx + 1,  # Override nomor urut agar dimulai dari 1
                    row['Pekerjaan'],
                    format_tanggal(str(row['Batas Waktu']), bulan),
                    row['Status'],
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
                st.error(f"Template file '{template_path}' tidak ditemukan.")
                return
                
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

            # Temukan tabel lama
            if not doc.tables:
                st.error("Tidak dapat menemukan tabel di template dokumen.")
                return
                
            old_table = doc.tables[0]
            table_style = old_table.style  # Simpan gaya tabel
            header_row = [cell.text for cell in old_table.rows[0].cells]  # Simpan header

            # Temukan posisi tabel lama dalam dokumen
            table_index = None
            for i, element in enumerate(doc.element.body):
                if old_table._tbl in element:
                    table_index = i
                    break

            # Jika tabel tidak ditemukan, tambahkan di akhir dokumen
            if table_index is None:
                st.warning("Tabel tidak ditemukan dalam dokumen. Menambahkan tabel baru di akhir.")
                table_index = len(doc.element.body)

            # Hapus tabel lama dari dokumen
            doc.element.body.remove(old_table._tbl)

            # Tambahkan tabel baru di posisi yang sama
            new_table = doc.add_table(rows=1, cols=len(header_row), style=table_style)
            new_table.autofit = True
            doc.element.body.insert(table_index, new_table._tbl)

            # Tambahkan header ke tabel baru, salin pemformatan warna, dan tambahkan garis hitam
            hdr_cells = new_table.rows[0].cells
            for i, header_text in enumerate(header_row):
                hdr_cells[i].text = header_text
                copy_cell_formatting(old_table.rows[0].cells[i], hdr_cells[i])  # Salin warna
                add_black_borders(hdr_cells[i])  # Tambahkan garis hitam

            # Tambahkan data baru ke tabel, salin pemformatan warna, dan tambahkan garis hitam
            for j, (no, pekerjaan, batas_waktu, status, selesai_pada) in enumerate(data_baru):
                row_cells = new_table.add_row().cells
                row_cells[0].text = str(no)
                row_cells[1].text = pekerjaan
                row_cells[2].text = batas_waktu
                row_cells[3].text = status
                row_cells[4].text = selesai_pada
                # Salin pemformatan dari baris data pertama tabel lama (jika ada)
                if len(old_table.rows) > 1:
                    old_row = old_table.rows[1].cells  # Ambil baris data pertama dari tabel lama
                    for i in range(len(row_cells)):
                        copy_cell_formatting(old_row[i], row_cells[i])  # Salin warna
                        add_black_borders(row_cells[i])  # Tambahkan garis hitam
                else:
                    # Jika tidak ada baris data lama, tetap tambahkan garis hitam
                    for i in range(len(row_cells)):
                        add_black_borders(row_cells[i])

            # Tambahkan Keterangan setelah tabel
            doc.add_paragraph(f"Catatan: {keterangan}")

            # Buat download link untuk DOCX
            download_html = create_download_link(doc, file_name)
            st.markdown(download_html, unsafe_allow_html=True)
            st.success(f'Report berhasil dibuat! Klik link di atas untuk mengunduh file DOCX.')

if __name__ == "__main__":
    generate_report()