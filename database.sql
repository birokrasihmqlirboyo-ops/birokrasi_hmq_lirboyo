-- 1. Buat Jenis Seksi (Enum)
CREATE TYPE seksi_enum AS ENUM ('MUHAFADZOH', 'UJIAN', 'KORBUK', 'MUSYLAIL', 'DNA');

-- 2. Buat Tabel Utama Transactions
CREATE TABLE transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  seksi seksi_enum NOT NULL,
  tanggal_pembelian DATE NOT NULL,
  tanggal_input TIMESTAMPTZ DEFAULT NOW(),
  nama_toko TEXT NOT NULL,
  foto_barang_url TEXT,
  foto_nota_url TEXT,
  nama_kegiatan TEXT
);

-- 3. Buat Tabel Detail Barang
CREATE TABLE transaction_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE NOT NULL,
  nama_barang TEXT NOT NULL,
  jumlah INT NOT NULL DEFAULT 1,
  harga_satuan BIGINT NOT NULL DEFAULT 0,
  has_discount BOOLEAN DEFAULT FALSE,
  diskon_nominal BIGINT DEFAULT 0
);

-- 4. Aktifkan Row Level Security (RLS)
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;

-- Policy: Publik BISA Input (INSERT), tapi TIDAK BISA Lihat/Ubah/Hapus
CREATE POLICY "Publik bisa simpan nota" ON transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Publik bisa simpan item" ON transaction_items FOR INSERT WITH CHECK (true);

-- Policy: Admin (User terotentikasi) BISA Akses Semua (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Admin full akses transactions" ON transactions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admin full akses items" ON transaction_items FOR ALL USING (auth.role() = 'authenticated');

-- 5. Buat Storage Bucket untuk Foto Nota & Barang
INSERT INTO storage.buckets (id, name, public) VALUES ('nota-photos', 'nota-photos', true);

-- Policy Storage: Publik bisa upload foto, Admin bisa kelola
CREATE POLICY "Publik upload foto" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'nota-photos');
CREATE POLICY "Publik baca foto" ON storage.objects FOR SELECT USING (bucket_id = 'nota-photos');
