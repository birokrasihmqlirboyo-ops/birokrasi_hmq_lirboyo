<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { Button } from '$lib/components/ui/button';
  import { Save, Download, Settings, ArrowLeft } from 'lucide-svelte';

  // State Data
  let transactions: any[] = $state([]);
  let loading = $state(true);
  let saving = $state(false);
  
  // State Filter
  let filterBulan = $state('semua');
  let filterTahun = $state(new Date().getFullYear().toString());

  const monthNames: Record<string, string> = {
    '1': 'Januari', '2': 'Februari', '3': 'Maret', '4': 'April',
    '5': 'Mei', '6': 'Juni', '7': 'Juli', '8': 'Agustus',
    '9': 'September', '10': 'Oktober', '11': 'November', '12': 'Desember'
  };

  const availableMonths = Object.keys(monthNames);
  let availableYears = $derived.by(() => {
    const years = new Set<string>();
    const currentYear = new Date().getFullYear();
    years.add(currentYear.toString());
    years.add((currentYear - 1).toString());
    
    transactions.forEach(tx => {
      if (tx.tanggal_pembelian) years.add(tx.tanggal_pembelian.split('-')[0]);
    });
    
    return Array.from(years).sort((a, b) => parseInt(b) - parseInt(a));
  });

  // Pajak Options
  const jenisPajakOptions = ['-', 'PPh 21', 'PPh 22', 'PPh 23', 'PPN', 'Lainnya'];

  // BPP Configuration
  let showSettingsModal = $state(false);
  let bppConfig = $state({
    namaSekolah: 'MADRASAH HIDAYATUL MUBTADIIN LIRBOYO',
    desaKecamatan: 'Lirboyo / Mojoroto',
    kabupaten: 'Kota Kediri',
    provinsi: 'Jawa Timur',
    namaKepala: 'MUCHAMAD AINUL YAQIN',
    namaBendahara: 'M. MISBAHUL ULUM'
  });

  // Flattened and Filtered Items
  let bppItems = $derived.by(() => {
    let items: any[] = [];
    
    transactions.forEach(tx => {
      const parts = tx.tanggal_pembelian.split('-');
      const yyyy = parts[0];
      const mm = parseInt(parts[1], 10).toString();
      
      const matchBulan = filterBulan === 'semua' || mm === filterBulan;
      const matchTahun = filterTahun === 'semua' || yyyy === filterTahun;
      
      if (matchBulan && matchTahun) {
        tx.transaction_items.forEach((item: any) => {
          items.push({
            tx_id: tx.id,
            item_id: item.id,
            tanggal: tx.tanggal_pembelian,
            no_kode: tx.seksi || '-',
            no_bukti: '-',
            uraian: `${tx.nama_toko ? tx.nama_toko + '\\n' : ''}${item.nama_barang} (${item.jumlah}x @ Rp ${item.harga_satuan.toLocaleString('id-ID')})`,
            pengeluaran: (item.jumlah * item.harga_satuan) - item.diskon_nominal,
            jenis_pajak: item.jenis_pajak || '-',
            pajak_persen: item.pajak_persen || 0,
            pajak_nominal: item.pajak_nominal || 0,
            dbOriginal: {
              jenis_pajak: item.jenis_pajak || '-',
              pajak_persen: item.pajak_persen || 0,
              pajak_nominal: item.pajak_nominal || 0
            }
          });
        });
      }
    });

    items.sort((a, b) => new Date(a.tanggal).getTime() - new Date(b.tanggal).getTime());
    return items;
  });

  // Reactive calculations for modified items
  let totalPengeluaran = $derived(bppItems.reduce((sum, item) => sum + item.pengeluaran, 0));
  let totalPajak = $derived(bppItems.reduce((sum, item) => sum + item.pajak_nominal, 0));

  let hasUnsavedChanges = $derived.by(() => {
    return bppItems.some(item => 
      item.jenis_pajak !== item.dbOriginal.jenis_pajak ||
      item.pajak_persen !== item.dbOriginal.pajak_persen ||
      item.pajak_nominal !== item.dbOriginal.pajak_nominal
    );
  });

  onMount(() => {
    const savedConfig = localStorage.getItem('bppConfigHMQ');
    if (savedConfig) {
      try { bppConfig = JSON.parse(savedConfig); } catch (e) {}
    }
    
    fetchData();
  });

  async function fetchData() {
    loading = true;
    
    const { data: txData, error: txError } = await supabase
      .from('transactions')
      .select('id, seksi, tanggal_pembelian, nama_toko, transaction_items(id, nama_barang, jumlah, harga_satuan, diskon_nominal, jenis_pajak, pajak_persen, pajak_nominal)');
    
    if (txError) console.error("Error fetching transactions:", txError);
    else transactions = txData || [];

    loading = false;
  }

  function handlePersenChange(item: any) {
    if (item.pajak_persen > 0) {
      item.pajak_nominal = (item.pengeluaran * item.pajak_persen) / 100;
      if (item.jenis_pajak === '-') item.jenis_pajak = 'PPh 23'; // Default suggestion
    } else {
      item.pajak_nominal = 0;
      item.jenis_pajak = '-';
    }
  }

  async function simpanPerubahan() {
    saving = true;
    let errors = 0;

    for (const item of bppItems) {
      if (
        item.jenis_pajak !== item.dbOriginal.jenis_pajak ||
        item.pajak_persen !== item.dbOriginal.pajak_persen ||
        item.pajak_nominal !== item.dbOriginal.pajak_nominal
      ) {
        const { error } = await supabase
          .from('transaction_items')
          .update({
            jenis_pajak: item.jenis_pajak === '-' ? null : item.jenis_pajak,
            pajak_persen: item.pajak_persen,
            pajak_nominal: item.pajak_nominal
          })
          .eq('id', item.item_id);
        
        if (error) {
          console.error("Gagal update item:", error);
          errors++;
        }
      }
    }

    if (errors === 0) {
      alert("Perubahan pajak berhasil disimpan!");
      await fetchData(); // Reload to reset dbOriginal states
    } else {
      alert(`Terjadi kesalahan pada ${errors} item saat menyimpan.`);
    }
    saving = false;
  }

  function simpanPengaturan() {
    localStorage.setItem('bppConfigHMQ', JSON.stringify(bppConfig));
    showSettingsModal = false;
    alert('Pengaturan BPP berhasil disimpan!');
  }

  function formatRupiah(val: number) {
    return new Intl.NumberFormat('id-ID', { maximumFractionDigits: 0 }).format(val);
  }

  function exportToWord() {
    if (filterBulan === 'semua' || filterTahun === 'semua') {
      alert('Pilih Bulan dan Tahun yang spesifik untuk mencetak BPP.');
      return;
    }

    // Filter items yang ada pajaknya saja (atau semuanya jika ingin seperti format awal)
    // Berdasarkan request, biasanya buku pembantu pajak berisi rincian yang KENA PAJAK saja.
    // Tapi jika Nihil, kita tetap mencetak tabel kosong.
    const taxedItems = bppItems.filter(item => item.pajak_nominal > 0);
    const isNihil = taxedItems.length === 0;
    
    // Aggregate totals for export
    const exportTotalPengeluaran = taxedItems.reduce((sum, item) => sum + item.pengeluaran, 0);
    const exportTotalPajak = taxedItems.reduce((sum, item) => sum + item.pajak_nominal, 0);

    let html = `
    <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
    <head><meta charset='utf-8'><title>BPP Export</title>
    <style>
      @page WordSection1 {
          size: 841.9pt 595.3pt; /* A4 Landscape */
          mso-page-orientation: landscape;
          margin: 0.5in 0.5in 0.5in 0.5in;
      }
      div.WordSection1 { page: WordSection1; }
      body, table, td, th, p, div { 
          font-family: 'Arial', sans-serif; 
          font-size: 10pt; 
          margin: 0;
          mso-margin-top-alt: 0;
          mso-margin-bottom-alt: 0;
      }
      h2 { text-align: center; margin-bottom: 5px; margin-top: 0; font-size: 12pt; }
      .periode-title { text-align: center; font-weight: bold; margin-bottom: 20px; font-size: 11pt; }
      table.data-table { width: 100%; border-collapse: collapse; margin-top: 10px; }
      table.data-table th, table.data-table td { border: 1px solid black; padding: 4px 6px; text-align: left; vertical-align: middle; }
      table.data-table th { text-align: center; font-weight: bold; }
      .no-border { border: none !important; }
      .no-border td { border: none !important; padding: 2px; }
      
      .watermark-nihil {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%) rotate(-30deg);
        font-size: 120pt;
        color: rgba(200, 200, 200, 0.4);
        font-weight: bold;
        z-index: -1;
        letter-spacing: 10px;
        text-align: center;
        width: 100%;
      }
    </style>
    </head>
    <body>
      <div class="WordSection1">
      
      <h2>BUKU PEMBANTU PAJAK</h2>
      <div class="periode-title">Bulan : ${monthNames[filterBulan]} ${filterTahun}</div>
      
      <table style="width: 100%; margin-bottom: 15px; border: none;">
        <tr>
          <td style="width: 60%; vertical-align: top; border: none;">
            <table class="no-border" style="width: 100%;">
              <tr><td style="width: 120px;">Nama Sekolah</td><td>: ${bppConfig.namaSekolah}</td></tr>
              <tr><td>Desa/ Kecamatan</td><td>: ${bppConfig.desaKecamatan}</td></tr>
              <tr><td>Kabupaten</td><td>: ${bppConfig.kabupaten}</td></tr>
              <tr><td>Provinsi</td><td>: ${bppConfig.provinsi}</td></tr>
            </table>
          </td>
          <td style="width: 40%; vertical-align: top; border: none; text-align: right;">
            <table style="width: 250px; border-collapse: collapse; border: 1px solid black; text-align: center; font-weight: bold; float: right;">
              <tr><td style="border: 1px solid black; padding: 5px;">FORMAT K-2</td></tr>
              <tr><td style="border: 1px solid black; padding: 2px; font-weight: normal;">Diisi Oleh Bendahara SPM</td></tr>
              <tr><td style="border: 1px solid black; padding: 2px; font-weight: normal;">Disimpan di SPM</td></tr>
            </table>
          </td>
        </tr>
      </table>

      ${isNihil ? '<div style="text-align: center; font-size: 80pt; color: #e0e0e0; font-weight: bold; position: absolute; margin-top: 100px; z-index: -1;">Nihil</div>' : ''}

      <table class="data-table">
        <thead>
          <tr>
            <th style="width: 40px;">No.</th>
            <th style="width: 80px;">Tanggal</th>
            <th style="width: 90px;">No. Kode</th>
            <th style="width: 80px;">No. Bukti</th>
            <th>Uraian</th>
            <th style="width: 110px;">Pengeluaran/<br>kredit</th>
            <th style="width: 100px;">Pajak</th>
            <th style="width: 110px;">Jumlah</th>
          </tr>
          <tr>
            <th>1</th><th>2</th><th>3</th><th>4</th><th>5</th><th>6</th><th>7</th><th>8</th>
          </tr>
        </thead>
        <tbody>
    `;

    if (isNihil) {
      // Print empty rows with dashes to match Nihil format
      for(let i=0; i<6; i++) {
        html += `
          <tr>
            <td style="text-align: center;">&nbsp;</td>
            <td style="text-align: center;">&nbsp;</td>
            <td style="text-align: center;">&nbsp;</td>
            <td style="text-align: center;">&nbsp;</td>
            <td>&nbsp;</td>
            <td style="text-align: right;">-</td>
            <td style="text-align: right;">-</td>
            <td style="text-align: right;">-</td>
          </tr>
        `;
      }
    } else {
      taxedItems.forEach((entry, idx) => {
        let uraianHtml = entry.uraian.replace(/\n/g, '<br/>');
        html += `
          <tr>
            <td style="text-align: center;">${idx + 1}</td>
            <td style="text-align: center;">${new Date(entry.tanggal).toLocaleDateString('id-ID', {day: '2-digit', month:'2-digit', year:'numeric'}).replace(/\//g, '-')}</td>
            <td style="text-align: center;">${entry.no_kode}</td>
            <td style="text-align: center;">${entry.no_bukti}</td>
            <td style="vertical-align: top;">${uraianHtml}</td>
            <td style="text-align: right;">${formatRupiah(entry.pengeluaran)}</td>
            <td style="text-align: right;">${entry.jenis_pajak}<br>${formatRupiah(entry.pajak_nominal)}</td>
            <td style="text-align: right;">-</td>
          </tr>
        `;
      });
    }

    html += `
          <tr>
            <td colspan="5" style="text-align: center; font-weight: bold;">Jumlah Penerimaan</td>
            <td style="text-align: right; font-weight: bold;">${isNihil ? '-' : formatRupiah(exportTotalPengeluaran)}</td>
            <td style="text-align: right; font-weight: bold;">${isNihil ? '-' : formatRupiah(exportTotalPajak)}</td>
            <td style="text-align: right; font-weight: bold;">-</td>
          </tr>
        </tbody>
      </table>

      <br/>
      <div style="text-align: right; margin-right: 50px;">
        Kediri, 31 ${monthNames[filterBulan]} ${filterTahun}
      </div>
      <br/><br/>

      <table style="width: 100%; border: none;">
        <tr>
          <td style="width: 50%; text-align: center; border: none;">
            Mengetahui<br/>
            Kepala Sekolah<br/><br/><br/><br/><br/><br/>
            <b><u>${bppConfig.namaKepala}</u></b>
          </td>
          <td style="width: 50%; text-align: center; border: none;">
            Dibuat oleh<br/>
            Bendahara Sekolah<br/><br/><br/><br/><br/><br/>
            <b><u>${bppConfig.namaBendahara}</u></b>
          </td>
        </tr>
      </table>
      </div>
    </body>
    </html>
    `;

    const blob = new Blob(['\ufeff', html], { type: 'application/msword' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    let filename = `BPP_${monthNames[filterBulan]}_${filterTahun}.doc`;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }
</script>

<div class="p-4 sm:p-8 w-full max-w-[1600px] mx-auto space-y-6">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
    <div>
      <div class="flex items-center gap-3 mb-2">
        <a href="/admin" class="p-2 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors text-gray-600">
          <ArrowLeft class="w-5 h-5" />
        </a>
        <h1 class="text-3xl font-bold tracking-tight text-gray-900">Buku Pembantu Pajak (BPP)</h1>
      </div>
      <p class="text-gray-500 pl-14">Catat dan cetak rincian pajak (PPh 21, PPh 23, PPN, dll) untuk setiap pengeluaran.</p>
    </div>
    
    <div class="flex flex-wrap gap-3 w-full sm:w-auto mt-4 sm:mt-0">
      <Button variant="outline" onclick={() => showSettingsModal = true} class="bg-white border-2 hover:bg-gray-50 flex items-center gap-2">
        <Settings class="w-4 h-4" /> Pengaturan BPP
      </Button>

      <Button onclick={exportToWord} class="bg-blue-600 hover:bg-blue-700 text-white shadow-md flex items-center gap-2">
        <Download class="w-4 h-4" /> Cetak Word (K-2)
      </Button>
    </div>
  </div>

  <!-- Filters -->
  <div class="flex flex-wrap gap-4 items-end bg-gray-50/50 p-4 rounded-xl border flex-col sm:flex-row justify-between">
    <div class="flex gap-4">
      <div>
        <label class="block text-xs font-bold text-gray-600 mb-1.5 uppercase tracking-wider">Bulan</label>
        <select bind:value={filterBulan} class="p-2 border-2 rounded-lg bg-white font-semibold text-sm w-36 outline-none focus:border-primary">
          <option value="semua">Semua Bulan</option>
          {#each availableMonths as m}
            <option value={m}>{monthNames[m]}</option>
          {/each}
        </select>
      </div>
      <div>
        <label class="block text-xs font-bold text-gray-600 mb-1.5 uppercase tracking-wider">Tahun</label>
        <select bind:value={filterTahun} class="p-2 border-2 rounded-lg bg-white font-semibold text-sm w-32 outline-none focus:border-primary">
          <option value="semua">Semua Tahun</option>
          {#each availableYears as t}
            <option value={t}>{t}</option>
          {/each}
        </select>
      </div>
    </div>
    
    {#if hasUnsavedChanges}
      <Button onclick={simpanPerubahan} disabled={saving} class="bg-amber-500 hover:bg-amber-600 text-white font-bold animate-pulse flex items-center gap-2">
        <Save class="w-4 h-4"/> {saving ? 'Menyimpan...' : 'Simpan Perubahan Pajak'}
      </Button>
    {/if}
  </div>

  <!-- BPP Table -->
  <div class="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm">
    <div class="p-6 border-b border-gray-200 bg-gray-50/30">
      <div class="text-center mb-6">
        <h2 class="font-bold text-lg tracking-widest uppercase">Buku Pembantu Pajak</h2>
        {#if filterBulan !== 'semua' || filterTahun !== 'semua'}
          <p class="text-sm font-semibold text-gray-600 mt-1 uppercase">
            Bulan : {filterBulan !== 'semua' ? monthNames[filterBulan] : ''} {filterTahun !== 'semua' ? filterTahun : ''}
          </p>
        {/if}
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        <thead class="text-xs text-gray-700 uppercase bg-gray-100 border-b-2 border-gray-300">
          <tr>
            <th class="px-3 py-3 text-center border-r">No</th>
            <th class="px-3 py-3 text-center border-r whitespace-nowrap">Tanggal</th>
            <th class="px-3 py-3 text-center border-r">No Bukti</th>
            <th class="px-3 py-3 text-center border-r w-[25%]">Uraian Barang</th>
            <th class="px-3 py-3 text-center border-r">Pengeluaran</th>
            <th class="px-3 py-3 text-center border-r bg-blue-50">Jenis Pajak</th>
            <th class="px-3 py-3 text-center border-r bg-blue-50">% Pajak</th>
            <th class="px-3 py-3 text-center bg-blue-50">Nominal Pajak</th>
          </tr>
        </thead>
        <tbody>
          {#if loading}
            <tr><td colspan="8" class="text-center py-12 text-muted-foreground animate-pulse font-medium">Memuat rincian barang...</td></tr>
          {:else if bppItems.length === 0}
            <tr><td colspan="8" class="text-center py-12 text-muted-foreground font-bold text-lg opacity-50 tracking-widest">TIDAK ADA DATA</td></tr>
          {:else}
            {#each bppItems as entry, i}
              <tr class="border-b border-gray-100 hover:bg-gray-50/50">
                <td class="px-3 py-3 text-center border-r">{i + 1}</td>
                <td class="px-3 py-3 text-center border-r whitespace-nowrap">{new Date(entry.tanggal).toLocaleDateString('id-ID', {day:'2-digit', month:'2-digit', year:'numeric'}).replace(/\//g, '-')}</td>
                <td class="px-3 py-3 text-center border-r">{entry.no_bukti}</td>
                <td class="px-3 py-3 border-r">
                  <div class="whitespace-pre-wrap leading-relaxed text-xs font-medium text-gray-700">{entry.uraian}</div>
                </td>
                <td class="px-3 py-3 text-right border-r font-semibold">Rp {formatRupiah(entry.pengeluaran)}</td>
                <td class="px-2 py-2 border-r bg-blue-50/30">
                  <select bind:value={entry.jenis_pajak} class="w-full p-1.5 border rounded bg-white text-xs outline-none focus:border-primary">
                    {#each jenisPajakOptions as jp}
                      <option value={jp}>{jp}</option>
                    {/each}
                  </select>
                </td>
                <td class="px-2 py-2 border-r bg-blue-50/30 text-center">
                  <div class="flex items-center gap-1 justify-center">
                    <input type="number" min="0" max="100" bind:value={entry.pajak_persen} oninput={() => handlePersenChange(entry)} class="w-16 p-1.5 border rounded text-center text-xs outline-none focus:border-primary" />
                    <span class="font-bold text-xs">%</span>
                  </div>
                </td>
                <td class="px-3 py-3 text-right font-bold text-blue-700 bg-blue-50/30">
                  Rp {formatRupiah(entry.pajak_nominal)}
                </td>
              </tr>
            {/each}
            
            <tr class="bg-gray-100 border-t-2 border-gray-300">
              <td colspan="4" class="px-4 py-4 text-center border-r font-black text-gray-800 uppercase tracking-widest">JUMLAH</td>
              <td class="px-4 py-4 text-right border-r font-black text-base">Rp {formatRupiah(totalPengeluaran)}</td>
              <td colspan="2" class="border-r bg-blue-100/50"></td>
              <td class="px-4 py-4 text-right font-black text-blue-800 text-base bg-blue-100/50">Rp {formatRupiah(totalPajak)}</td>
            </tr>
          {/if}
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Modal Pengaturan -->
{#if showSettingsModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showSettingsModal = false}>
    <div class="relative max-w-2xl w-full bg-white rounded-2xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b bg-gray-50">
        <h3 class="font-bold text-lg flex items-center gap-2"><Settings class="w-5 h-5"/> Pengaturan Tanda Tangan BPP</h3>
      </div>
      <div class="p-5 space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-sm font-semibold mb-1">Nama Sekolah (Header)</label>
            <input type="text" bind:value={bppConfig.namaSekolah} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Desa / Kecamatan</label>
            <input type="text" bind:value={bppConfig.desaKecamatan} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Kabupaten</label>
            <input type="text" bind:value={bppConfig.kabupaten} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-semibold mb-1">Provinsi</label>
            <input type="text" bind:value={bppConfig.provinsi} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
        </div>
        <hr class="my-4 border-dashed" />
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold mb-1 text-primary">Nama Kepala Sekolah</label>
            <input type="text" bind:value={bppConfig.namaKepala} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold uppercase outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1 text-primary">Nama Bendahara Sekolah</label>
            <input type="text" bind:value={bppConfig.namaBendahara} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold uppercase outline-none focus:border-primary" />
          </div>
        </div>
      </div>
      <div class="p-4 border-t flex justify-end gap-3 bg-gray-50">
        <Button variant="outline" onclick={() => showSettingsModal = false}>Tutup</Button>
        <Button onclick={simpanPengaturan} class="bg-primary hover:bg-primary/90 text-white font-bold">Simpan Pengaturan</Button>
      </div>
    </div>
  </div>
{/if}
