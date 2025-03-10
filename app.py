from docx import Document
from datetime import datetime
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

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

# Ambil tanggal saat ini
sekarang = datetime.now()
nama_hari = hari[sekarang.strftime("%A")]
nama_bulan = bulan[sekarang.strftime("%B")]
tanggal = sekarang.strftime("%d")
tahun = sekarang.strftime("%Y")
waktu_laporan = f"{nama_hari}, {tanggal} {nama_bulan} {tahun}"

# Input keterangan baru
keterangan = input("Masukkan keterangan baru: ")

# Data baru untuk tabel
data_baru = [
    (1, "Mengupdate API baru", "10 Maret 2025", "Dalam Pengerjaan", "-"),
    (2, "Fixing bug upload file", "9 Maret 2025", "Sedang di Optimalisasi", "9 Maret 2025"),
    (3, "Dokumentasi instalasi server", "8 Maret 2025", "Selesai", "8 Maret 2025"),
    (4, "Menambah fitur pencarian", "7 Maret 2025", "Selesai", "7 Maret 2025")
]

# Baca dokumen yang sudah ada
doc = Document("Weekly Daily Report Wildan Dzaky Ramadhani.docx")

# Update Waktu Laporan saja (Catatan dihapus)
for para in doc.paragraphs:
    if "Waktu Laporan" in para.text:
        para.text = f"Waktu Laporan\t: {waktu_laporan}"

# Hapus paragraf Catatan jika ada
for i, para in enumerate(doc.paragraphs):
    if "Catatan" in para.text:
        doc.element.body.remove(para._element)
        break

# Temukan tabel lama
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
    print("Tabel tidak ditemukan dalam dokumen. Menambahkan tabel baru di akhir.")
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

# Tambahkan Keterangan setelah tabel (selalu tambah baru, bukan update)
doc.add_paragraph(f"{keterangan}")

# Simpan dokumen yang sudah diubah
doc.save("laporan_pekerjaan_updated.docx")
print("Dokumen telah diperbarui dan disimpan sebagai 'laporan_pekerjaan_updated.docx'")