<script lang="ts">
  import { supabase } from '$lib/supabaseClient';

  let status = $state('');

  async function seedData() {
    // Bersihkan data lama di tahun 2026 agar tidak dobel
    status = 'Menghapus data 2026 lama...';
    await supabase.from('pemasukan').delete().gte('tanggal', '2026-01-01');
    await supabase.from('transactions').delete().gte('tanggal_pembelian', '2026-01-01');

    status = 'Memulai proses seeding Pemasukan...';
    
    // 1. Pemasukan
    const pemasukanData = [
      { tanggal: '2026-01-10', uraian: 'Dana BOS Tahap 1', nominal: 150000000, no_kode: 'BOS-01' },
      { tanggal: '2026-04-10', uraian: 'Dana BOS Tahap 2', nominal: 150000000, no_kode: 'BOS-02' },
      { tanggal: '2026-07-10', uraian: 'Dana BOS Tahap 3', nominal: 150000000, no_kode: 'BOS-03' },
      { tanggal: '2026-10-10', uraian: 'Dana BOS Tahap 4', nominal: 150000000, no_kode: 'BOS-04' }
    ];
    
    const { error: pErr } = await supabase.from('pemasukan').insert(pemasukanData);
    if(pErr) {
      status = 'Pemasukan Error: ' + pErr.message;
      return;
    }
    
    status = 'Pemasukan berhasil diinput. Memulai Pengeluaran...';
    
    const months = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
    const seksiList = ['MUHAFADZOH', 'MADRASAH', 'KEAMANAN', 'KESEHATAN'];
    
    for (const m of months) {
      for (let i = 0; i < 4; i++) {
        const seksi = seksiList[i % seksiList.length];
        const { data: tx, error: tErr } = await supabase.from('transactions').insert({
          seksi: seksi,
          tanggal_pembelian: `2026-${m}-${10 + i}`,
          nama_toko: 'Toko Dummy ' + (i + 1),
          nama_kegiatan: 'Kegiatan ' + seksi + ' Bulan ' + m
        }).select().single();
        
        if (tErr) { 
          status = 'TX Error di bulan ' + m + ': ' + tErr.message; 
          return;
        }
        
        const { error: iErr } = await supabase.from('transaction_items').insert([
          { transaction_id: tx.id, nama_barang: 'Barang A', jumlah: 5, harga_satuan: 100000, diskon_nominal: 0 },
          { transaction_id: tx.id, nama_barang: 'Barang B', jumlah: 10, harga_satuan: 50000, diskon_nominal: 0 }
        ]);
        
        if(iErr) {
          status = 'Item Error di bulan ' + m + ': ' + iErr.message;
          return;
        }
      }
    }
    status = 'Selesai! Data dummy selama setahun berhasil diinput.';
  }
</script>

<div class="p-8">
  <h1 class="text-2xl font-bold mb-4">Seeder Data 2026</h1>
  <button onclick={seedData} class="px-6 py-2 bg-emerald-600 text-white rounded font-bold">
    Klik untuk Masukkan Data Dummy
  </button>
  <p class="mt-4 font-mono text-gray-700">{status}</p>
</div>
