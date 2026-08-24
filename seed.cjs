const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://hwqcpyfngesvlasluxcn.supabase.co',
  'sb_publishable_GFO7TrOD68YaUOcU--zD_Q_QSRsnRhT'
);

async function seed() {
  console.log('Seeding Pemasukan...');
  
  const pemasukanData = [
    { tanggal: '2026-01-10', uraian: 'Dana BOS Tahap 1', nominal: 150000000, no_kode: 'BOS-01' },
    { tanggal: '2026-04-10', uraian: 'Dana BOS Tahap 2', nominal: 150000000, no_kode: 'BOS-02' },
    { tanggal: '2026-07-10', uraian: 'Dana BOS Tahap 3', nominal: 150000000, no_kode: 'BOS-03' },
    { tanggal: '2026-10-10', uraian: 'Dana BOS Tahap 4', nominal: 150000000, no_kode: 'BOS-04' }
  ];
  
  const { error: pErr } = await supabase.from('pemasukan').insert(pemasukanData);
  if(pErr) console.error('Pemasukan Error:', pErr);
  
  console.log('Seeding Pengeluaran...');
  
  const months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  for (const m of months) {
    for (let i=1; i<=2; i++) {
       const { data: tx, error: tErr } = await supabase.from('transactions').insert({
         seksi: 'MUHAFADZOH',
         tanggal_pembelian: `2026-${m}-15`,
         nama_toko: 'Toko Buku ' + i,
         nama_kegiatan: 'Operasional Bulan ' + m
       }).select().single();
       
       if (tErr) { console.error('TX Error:', tErr); continue; }
       
       const { error: iErr } = await supabase.from('transaction_items').insert([
         { transaction_id: tx.id, nama_barang: 'Kertas HVS', jumlah: 10, harga_satuan: 55000, diskon_nominal: 0 },
         { transaction_id: tx.id, nama_barang: 'Tinta Printer', jumlah: 2, harga_satuan: 120000, diskon_nominal: 0 }
       ]);
       
       if(iErr) console.error('Item Error:', iErr);
    }
  }
  console.log('Done Seeding!');
}

seed();
