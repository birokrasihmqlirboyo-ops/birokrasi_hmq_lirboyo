<script lang="ts">
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { Button } from '$lib/components/ui/button';
  import { Switch } from "$lib/components/ui/switch";
  import { Trash2, Plus } from "lucide-svelte";

  // Opsi Dropdown Tanggal
  const hariList = Array.from({length: 31}, (_, i) => (i + 1).toString());
  const bulanList = [
    { value: '1', label: 'Januari' }, { value: '2', label: 'Februari' }, { value: '3', label: 'Maret' },
    { value: '4', label: 'April' }, { value: '5', label: 'Mei' }, { value: '6', label: 'Juni' },
    { value: '7', label: 'Juli' }, { value: '8', label: 'Agustus' }, { value: '9', label: 'September' },
    { value: '10', label: 'Oktober' }, { value: '11', label: 'November' }, { value: '12', label: 'Desember' }
  ];
  const tahunList = Array.from({length: 5}, (_, i) => (new Date().getFullYear() - 2 + i).toString());

  const txId = $page.params.id;

  let seksi = $state('MUHAFADZOH');
  
  let inputHari = $state(new Date().getDate().toString());
  let inputBulan = $state((new Date().getMonth() + 1).toString());
  let inputTahun = $state(new Date().getFullYear().toString());
  let tanggal = $derived(`${inputTahun}-${inputBulan.padStart(2, '0')}-${inputHari.padStart(2, '0')}`);

  let namaToko = $state('');
  let namaKegiatan = $state('');
  
  let items = $state<{
    id?: string;
    nama_barang: string;
    jumlah: number;
    harga_satuan: number;
    has_discount: boolean;
    diskon_nominal: number;
  }[]>([]);

  let loading = $state(true);
  let saving = $state(false);

  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      goto('/login');
      return;
    }

    const { data, error } = await supabase
      .from('transactions')
      .select('*, transaction_items(*)')
      .eq('id', txId)
      .single();

    if (error || !data) {
      alert('Data tidak ditemukan');
      goto('/admin');
      return;
    }

    seksi = data.seksi;
    if (data.tanggal_pembelian) {
      const parts = data.tanggal_pembelian.split('-');
      if (parts.length === 3) {
        inputTahun = parts[0];
        inputBulan = parseInt(parts[1], 10).toString();
        inputHari = parseInt(parts[2], 10).toString();
      }
    }
    namaToko = data.nama_toko;
    namaKegiatan = data.nama_kegiatan || '';
    items = data.transaction_items || [];
    loading = false;
  });

  function tambahBarang() {
    items.push({ nama_barang: '', jumlah: 1, harga_satuan: 0, has_discount: false, diskon_nominal: 0 });
  }

  function hapusBarang(index: number) {
    items.splice(index, 1);
  }

  async function handleUpdate() {
    if (items.length === 0) {
      alert("Harus ada minimal 1 barang.");
      return;
    }
    saving = true;

    // Update transactions table
    const { error: txError } = await supabase
      .from('transactions')
      .update({
        seksi,
        tanggal_pembelian: tanggal,
        nama_toko: namaToko,
        nama_kegiatan: namaKegiatan || null
      })
      .eq('id', txId);

    if (txError) {
      alert('Gagal update transaksi: ' + txError.message);
      saving = false;
      return;
    }

    // Delete existing items
    await supabase.from('transaction_items').delete().eq('transaction_id', txId);

    // Insert new items
    const newItems = items.map(it => ({
      transaction_id: txId,
      nama_barang: it.nama_barang,
      jumlah: it.jumlah,
      harga_satuan: it.harga_satuan,
      has_discount: it.has_discount,
      diskon_nominal: it.has_discount ? it.diskon_nominal : 0
    }));

    const { error: itemsError } = await supabase.from('transaction_items').insert(newItems);

    if (itemsError) {
      alert('Berhasil update transaksi, namun gagal update rincian barang: ' + itemsError.message);
    } else {
      alert('Data berhasil diperbarui!');
      goto('/admin');
    }
    saving = false;
  }
</script>

<div class="max-w-2xl mx-auto p-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Edit Transaksi</h1>
    <Button variant="outline" href="/admin">Batal</Button>
  </div>

  {#if loading}
    <p class="text-center py-10">Memuat data...</p>
  {:else}
    <form onsubmit={(e) => { e.preventDefault(); handleUpdate(); }} class="space-y-6">
      
      <!-- Informasi Umum -->
      <div class="space-y-4 p-4 border rounded-xl bg-card text-card-foreground shadow-sm">
        <div>
          <label class="block text-sm font-semibold mb-1">Jenis Seksi</label>
          <div class="relative">
            <select bind:value={seksi} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white appearance-none pr-10 focus:outline-none focus:ring-4 focus:ring-primary/20 focus:border-primary font-bold text-gray-800 transition-all cursor-pointer shadow-sm hover:border-gray-300" required>
              <option value="MUHAFADZOH">Muhafadzoh</option>
              <option value="UJIAN">Ujian</option>
              <option value="KORBUK">Korbuk</option>
              <option value="MUSYLAIL">Musylail</option>
              <option value="DNA">DNA</option>
            </select>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3.5 pointer-events-none text-gray-400">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold mb-1">Tanggal Pembelian</label>
          <div class="flex gap-2">
            <div class="relative w-1/4">
              <select bind:value={inputHari} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white appearance-none pr-8 focus:outline-none focus:ring-4 focus:ring-primary/20 focus:border-primary font-bold text-gray-800 transition-all cursor-pointer shadow-sm hover:border-gray-300">
                {#each hariList as h}
                  <option value={h}>{h}</option>
                {/each}
              </select>
              <div class="absolute inset-y-0 right-0 flex items-center pr-2.5 pointer-events-none text-gray-400"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg></div>
            </div>
            <div class="relative w-2/4">
              <select bind:value={inputBulan} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white appearance-none pr-8 focus:outline-none focus:ring-4 focus:ring-primary/20 focus:border-primary font-bold text-gray-800 transition-all cursor-pointer shadow-sm hover:border-gray-300">
                {#each bulanList as b}
                  <option value={b.value}>{b.label}</option>
                {/each}
              </select>
              <div class="absolute inset-y-0 right-0 flex items-center pr-2.5 pointer-events-none text-gray-400"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg></div>
            </div>
            <div class="relative w-1/4">
              <select bind:value={inputTahun} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white appearance-none pr-8 focus:outline-none focus:ring-4 focus:ring-primary/20 focus:border-primary font-bold text-gray-800 transition-all cursor-pointer shadow-sm hover:border-gray-300">
                {#each tahunList as t}
                  <option value={t}>{t}</option>
                {/each}
              </select>
              <div class="absolute inset-y-0 right-0 flex items-center pr-2.5 pointer-events-none text-gray-400"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg></div>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold mb-1">Nama Toko</label>
          <input type="text" bind:value={namaToko} required placeholder="Contoh: Toko Sejahtera" class="w-full p-2.5 border rounded-lg" />
        </div>

        <div>
          <label class="block text-sm font-semibold mb-1">Nama Kegiatan (Khusus Makanan/Minuman)</label>
          <input type="text" bind:value={namaKegiatan} placeholder="Opsional" class="w-full p-2.5 border rounded-lg" />
        </div>
      </div>

      <!-- Rincian Barang -->
      <div class="space-y-3">
        <div class="flex justify-between items-center px-1">
          <h2 class="font-bold text-lg">Rincian Barang ({items.length} Jenis)</h2>
          <Button type="button" size="icon" onclick={tambahBarang} title="Tambah Barang">
            <Plus class="w-5 h-5" />
          </Button>
        </div>

        {#each items as item, index}
          <div class="p-4 border rounded-xl shadow-sm bg-white relative">
            <div class="flex justify-between items-center mb-2">
              <span class="font-bold text-foreground">Barang #{index + 1}</span>
              {#if items.length > 1}
                <button type="button" onclick={() => hapusBarang(index)} class="text-red-500 hover:text-red-700 hover:bg-red-50 p-1.5 rounded-md transition-colors" title="Hapus Barang">
                  <Trash2 class="w-4 h-4" />
                </button>
              {/if}
            </div>

            <div class="space-y-3">
              <div>
                <label class="block text-xs mb-1">Nama Barang</label>
                <input type="text" bind:value={item.nama_barang} required placeholder="Misal: Kertas HVS" class="w-full p-2 border rounded-md text-sm" />
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs mb-1">Jumlah</label>
                  <div class="flex items-center">
                    <button type="button" class="px-2.5 py-1 border bg-card text-card-foreground rounded-l-md" onclick={() => item.jumlah = Math.max(1, item.jumlah - 1)}>-</button>
                    <input type="number" bind:value={item.jumlah} min="1" class="w-full text-center border-y p-1 text-sm" />
                    <button type="button" class="px-2.5 py-1 border bg-card text-card-foreground rounded-r-md" onclick={() => item.jumlah++}>+</button>
                  </div>
                </div>

                <div>
                  <label class="block text-xs mb-1">Harga Satuan (Rp)</label>
                  <input
                    type="text"
                    value={item.harga_satuan === 0 ? '' : item.harga_satuan.toLocaleString('id-ID')}
                    oninput={(e) => {
                      const val = e.currentTarget.value.replace(/\D/g, '');
                      item.harga_satuan = val ? parseInt(val, 10) : 0;
                    }}
                    placeholder="Rp 0"
                    class="w-full p-1.5 border rounded-md text-sm"
                    required
                  />
                </div>
              </div>

              <div class="p-2.5 bg-card text-card-foreground border border-border rounded-lg shadow-sm">
                <div class="flex items-center justify-between">
                  <span class="text-xs font-medium">Ada Diskon?</span>
                  <Switch bind:checked={item.has_discount} />
                </div>
                {#if item.has_discount}
                  <div class="mt-2">
                    <label class="block text-xs mb-1">Nominal Diskon (Rp)</label>
                    <input
                      type="text"
                      value={item.diskon_nominal === 0 ? '' : item.diskon_nominal.toLocaleString('id-ID')}
                      oninput={(e) => {
                        const val = e.currentTarget.value.replace(/\D/g, '');
                        item.diskon_nominal = val ? parseInt(val, 10) : 0;
                      }}
                      placeholder="Rp 0"
                      class="w-full p-1.5 border rounded-md text-sm"
                    />
                  </div>
                {/if}
              </div>
              <div class="text-right pt-2 border-t mt-2">
                <span class="text-xs text-muted-foreground">Subtotal:</span>
                <span class="font-bold text-sm text-primary ml-1">
                  Rp {((item.jumlah * item.harga_satuan) - (item.has_discount ? item.diskon_nominal : 0)).toLocaleString('id-ID')}
                </span>
              </div>
            </div>
          </div>
        {/each}
      </div>

      <div class="p-4 bg-primary/10 border border-primary/20 rounded-xl flex justify-between items-center shadow-sm">
        <span class="font-bold text-foreground">Total Keseluruhan</span>
        <span class="font-black text-xl text-primary">
          Rp {items.reduce((sum, item) => sum + (item.jumlah * item.harga_satuan - (item.has_discount ? item.diskon_nominal : 0)), 0).toLocaleString('id-ID')}
        </span>
      </div>

      <Button type="submit" class="w-full py-6 text-lg font-bold" disabled={saving}>
        {saving ? 'Menyimpan...' : 'Simpan Perubahan'}
      </Button>

    </form>
  {/if}
</div>
