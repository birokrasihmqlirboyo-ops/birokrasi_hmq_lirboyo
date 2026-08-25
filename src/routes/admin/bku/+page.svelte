<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { Button } from '$lib/components/ui/button';
  import * as Table from '$lib/components/ui/table';
  import { Plus, Download, Settings, Trash2, ArrowLeft, ChevronDown, Loader2 } from 'lucide-svelte';
  import * as XLSX from 'xlsx';

  // State Data
  let transactions: any[] = $state([]);
  let pemasukanList: any[] = $state([]);
  let loading = $state(true);
  
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
    pemasukanList.forEach(p => {
      if (p.tanggal) years.add(p.tanggal.split('-')[0]);
    });
    
    return Array.from(years).sort((a, b) => parseInt(b) - parseInt(a));
  });



  // State Modal Settings (Tanda Tangan)
  let showSettingsModal = $state(false);
  let bkuConfig = $state({
    namaSekolah: 'SPM ULA AL-HIDAYAH HMQ PUTRI LIRBOYO',
    desaKecamatan: 'LIRBOYO/MOJOROTO',
    kabupaten: 'KOTA KEDIRI',
    provinsi: 'JAWA TIMUR',
    namaKepala: 'AHMAD',
    namaBendahara: 'ABDUROHMAN'
  });

  // Unified & Sorted Entries
  let bkuEntries = $derived.by(() => {
    const entries: any[] = [];
    
    // Process Pemasukan
    pemasukanList.forEach(p => {
      entries.push({
        id: p.id,
        type: 'pemasukan',
        tanggal: p.tanggal,
        no_kode: p.no_kode || '-',
        no_bukti: p.no_bukti || '-',
        uraian: p.uraian,
        penerimaan: p.nominal,
        pengeluaran: 0
      });
    });

    // Process Pengeluaran (Transactions)
    transactions.forEach(tx => {
      // Calculate Total Pengeluaran
      const totalBelanja = tx.transaction_items.reduce((sum: number, item: any) => sum + ((item.jumlah * item.harga_satuan) - item.diskon_nominal), 0);
      
      // Build Uraian (Barang-barang)
      let uraianText = tx.nama_kegiatan ? `${tx.nama_kegiatan}\n` : '';
      if(tx.nama_toko) uraianText += `${tx.nama_toko}\n`;
      
      tx.transaction_items.forEach((item: any) => {
        const subtotal = (item.jumlah * item.harga_satuan) - item.diskon_nominal;
        uraianText += `- ${item.nama_barang} (${item.jumlah}x @ Rp ${item.harga_satuan.toLocaleString('id-ID')}) = Rp ${subtotal.toLocaleString('id-ID')}\n`;
      });

      entries.push({
        id: tx.id,
        type: 'pengeluaran',
        tanggal: tx.tanggal_pembelian,
        no_kode: tx.seksi || '-',
        no_bukti: '-',
        uraian: uraianText.trim(),
        penerimaan: 0,
        pengeluaran: totalBelanja
      });
    });

    // Sort ALL entries by Tanggal Ascending first
    entries.sort((a, b) => new Date(a.tanggal).getTime() - new Date(b.tanggal).getTime());

    let saldoAwal = 0;
    const filtered: any[] = [];

    entries.forEach(e => {
      const parts = e.tanggal.split('-');
      const yyyy = parts[0];
      const mm = parseInt(parts[1], 10).toString();
      
      const matchBulan = filterBulan === 'semua' || mm === filterBulan;
      const matchTahun = filterTahun === 'semua' || yyyy === filterTahun;
      
      if (matchBulan && matchTahun) {
        filtered.push(e);
      } else {
        // Accumulate saldo for previous months
        let isBefore = false;
        if (filterTahun !== 'semua') {
          if (parseInt(yyyy) < parseInt(filterTahun)) {
            isBefore = true;
          } else if (yyyy === filterTahun && filterBulan !== 'semua' && parseInt(mm) < parseInt(filterBulan)) {
            isBefore = true;
          }
        }
        
        if (isBefore) {
          saldoAwal += (e.penerimaan - e.pengeluaran);
        }
      }
    });

    // Inject Saldo Awal row if a specific period is selected
    if (filterTahun !== 'semua' || filterBulan !== 'semua') {
      let dummyYear = filterTahun !== 'semua' ? filterTahun : new Date().getFullYear().toString();
      let dummyMonth = filterBulan !== 'semua' ? filterBulan.padStart(2, '0') : '01';
      
      filtered.unshift({
        id: 'saldo-awal',
        type: 'saldo-awal',
        tanggal: `${dummyYear}-${dummyMonth}-01`,
        no_kode: '-',
        no_bukti: '-',
        uraian: 'Saldo Bulan Sebelumnya',
        penerimaan: saldoAwal > 0 ? saldoAwal : 0,
        pengeluaran: saldoAwal < 0 ? Math.abs(saldoAwal) : 0,
        saldo: 0
      });
    }

    // Calculate Running Saldo
    let currentSaldo = 0;
    return filtered.map(e => {
      currentSaldo = currentSaldo + e.penerimaan - e.pengeluaran;
      return { ...e, saldo: currentSaldo };
    });
  });

  let totalPenerimaan = $derived(bkuEntries.reduce((sum, e) => sum + e.penerimaan, 0));
  let totalPengeluaran = $derived(bkuEntries.reduce((sum, e) => sum + e.pengeluaran, 0));
  let saldoAkhir = $derived(bkuEntries.length > 0 ? bkuEntries[bkuEntries.length - 1].saldo : 0);

  onMount(() => {
    // Load config
    const savedConfig = localStorage.getItem('bkuConfigHMQ');
    if (savedConfig) {
      try { bkuConfig = JSON.parse(savedConfig); } catch (e) {}
    }
    
    fetchData();
  });

  async function fetchData() {
    loading = true;
    
    // 1. Fetch Pengeluaran (transactions)
    const { data: txData, error: txError } = await supabase
      .from('transactions')
      .select('id, seksi, tanggal_pembelian, nama_toko, nama_kegiatan, transaction_items(nama_barang, jumlah, harga_satuan, diskon_nominal)');
    
    if (txError) console.error("Error fetching transactions:", txError);
    else transactions = txData || [];

    // 2. Fetch Pemasukan
    const { data: inData, error: inError } = await supabase
      .from('pemasukan')
      .select('*');
    
    if (inError) {
      // Tabel mungkin belum dibuat, abaikan error untuk pengeluaran saja
      console.warn("Tabel pemasukan belum ada atau error:", inError);
      pemasukanList = [];
    } else {
      pemasukanList = inData || [];
    }

    loading = false;
  }



  function simpanPengaturan() {
    localStorage.setItem('bkuConfigHMQ', JSON.stringify(bkuConfig));
    showSettingsModal = false;
    alert('Pengaturan BKU berhasil disimpan!');
  }

  function formatRupiah(val: number) {
    return new Intl.NumberFormat('id-ID', { maximumFractionDigits: 0 }).format(val);
  }

  let isGeneratingWord = $state(false);
  async function exportToWord() {
    isGeneratingWord = true;
    try {
      await new Promise(r => setTimeout(r, 100));
      if (bkuEntries.length === 0) {
        alert('Tidak ada data untuk di-export.');
        return;
      }

    let html = `
    <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
    <head><meta charset='utf-8'><title>BKU Export</title>
    <style>
      @page WordSection1 {
          size: 841.9pt 595.3pt; /* A4 Landscape */
          mso-page-orientation: landscape;
          margin: 0.5in 0.5in 0.5in 0.5in;
      }
      div.WordSection1 { page: WordSection1; }
      body, table, td, th, p, div { 
          font-family: 'Times New Roman', serif; 
          font-size: 11pt; 
          margin: 0;
          mso-margin-top-alt: 0;
          mso-margin-bottom-alt: 0;
      }
      h2 { text-align: center; margin-bottom: 5px; margin-top: 0; }
      .periode-title { text-align: center; font-weight: bold; text-transform: uppercase; margin-bottom: 20px; font-size: 11pt; }
      table { width: 100%; border-collapse: collapse; margin-top: 10px; }
      th, td { border: 1px solid black; padding: 3px 5px; text-align: left; vertical-align: top; }
      th { text-align: center; font-weight: bold; vertical-align: middle; }
      .text-center { text-align: center; }
      .text-right { text-align: right; }
      .no-border { border: none !important; }
      .no-border td { border: none !important; padding: 0px 2px; }
      .signature-table { width: 100%; border: none; margin-top: 40px; }
      .signature-table td { border: none; text-align: center; padding: 0; }
    </style>
    </head>
    <body>
      <div class="WordSection1">
      <h2>BUKU KAS UMUM</h2>
      ${(filterBulan !== 'semua' || filterTahun !== 'semua') ? `<div class="periode-title">${filterBulan !== 'semua' ? monthNames[filterBulan] : ''} ${filterTahun !== 'semua' ? filterTahun : ''}</div>` : ''}
      
      <table class="no-border" style="width: auto; margin-bottom: 15px;">
        <tr><td style="width: 150px;">Nama Sekolah</td><td>: ${bkuConfig.namaSekolah}</td></tr>
        <tr><td>Desa / Kecamatan</td><td>: ${bkuConfig.desaKecamatan}</td></tr>
        <tr><td>Kabupaten</td><td>: ${bkuConfig.kabupaten}</td></tr>
        <tr><td>Provinsi</td><td>: ${bkuConfig.provinsi}</td></tr>
      </table>

      <table>
        <thead>
          <tr>
            <th style="width: 40px;">NO</th>
            <th style="width: 80px;">TANGGAL</th>
            <th style="width: 90px;">NO. KODE</th>
            <th style="width: 80px;">NO. BUKTI</th>
            <th>URAIAN</th>
            <th style="width: 120px;">PENERIMAAN<br>(DEBET)</th>
            <th style="width: 120px;">PENGELUARAN<br>(KREDIT)</th>
            <th style="width: 120px;">SALDO</th>
          </tr>
          <tr>
            <th>1</th><th>2</th><th>3</th><th>4</th><th>5</th><th>6</th><th>7</th><th>8</th>
          </tr>
        </thead>
        <tbody>
    `;

    bkuEntries.forEach((entry, idx) => {
      let uraianHtml = entry.uraian.replace(/\n/g, '<br/>');
      html += `
        <tr>
          <td style="text-align: center; vertical-align: middle;">${idx + 1}</td>
          <td style="text-align: center; vertical-align: middle;">${new Date(entry.tanggal).toLocaleDateString('id-ID', {day: '2-digit', month:'2-digit', year:'numeric'}).replace(/\//g, '-')}</td>
          <td style="text-align: center; vertical-align: middle;">${entry.no_kode}</td>
          <td style="text-align: center; vertical-align: middle;">${entry.no_bukti}</td>
          <td style="vertical-align: top;">${uraianHtml}</td>
          <td style="text-align: right; vertical-align: middle;">${entry.penerimaan > 0 ? formatRupiah(entry.penerimaan) : ''}</td>
          <td style="text-align: right; vertical-align: middle;">${entry.pengeluaran > 0 ? formatRupiah(entry.pengeluaran) : ''}</td>
          <td style="text-align: right; vertical-align: middle;">${formatRupiah(entry.saldo)}</td>
        </tr>
      `;
    });

    html += `
          <tr>
            <td colspan="5" class="text-center font-bold" style="text-align: center; font-weight: bold;">JUMLAH</td>
            <td class="text-right font-bold" style="text-align: right; font-weight: bold;">${formatRupiah(totalPenerimaan)}</td>
            <td class="text-right font-bold" style="text-align: right; font-weight: bold;">${formatRupiah(totalPengeluaran)}</td>
            <td class="text-right font-bold" style="text-align: right; font-weight: bold;">${formatRupiah(saldoAkhir)}</td>
          </tr>
        </tbody>
      </table>

      <br/><br/>

      <table class="signature-table">
        <tr>
          <td style="width: 50%;">
            Mengetahui<br/>
            Kepala ${bkuConfig.namaSekolah}<br/><br/><br/><br/><br/><br/>
            <b><u>${bkuConfig.namaKepala}</u></b>
          </td>
          <td style="width: 50%;">
            Dibuat oleh<br/>
            Bendahara ${bkuConfig.namaSekolah}<br/><br/><br/><br/><br/><br/>
            <b><u>${bkuConfig.namaBendahara}</u></b>
          </td>
        </tr>
      </table>
      </div>
    </body>
    </html>
    `;

    const blob = new Blob(['\ufeff', html], {
      type: 'application/msword'
    });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    let filename = `BKU_${filterBulan !== 'semua' ? monthNames[filterBulan] : 'Semua'}_${filterTahun}.doc`;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    } catch (e) {
      alert('Terjadi kesalahan saat mencetak Word: ' + e);
    } finally {
      isGeneratingWord = false;
    }
  }
</script>

<div class="p-4 sm:p-8 w-full max-w-[1600px] mx-auto space-y-6">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
    <div>
      <h1 class="text-2xl font-bold tracking-tight text-gray-900 mb-1">Buku Kas Umum (BKU)</h1>
      <p class="text-sm text-gray-500">Rekapitulasi total Penerimaan dan Pengeluaran.</p>
    </div>
    
    <div class="flex flex-wrap items-center gap-3 w-full sm:w-auto mt-4 sm:mt-0">
      <div class="relative">
        <select bind:value={filterBulan} class="appearance-none p-2.5 pl-3 pr-8 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm w-36 outline-none focus:border-primary focus:ring-4 focus:ring-primary/20 hover:border-gray-300 transition-all shadow-sm text-gray-700 cursor-pointer">
          <option value="semua">Semua Bulan</option>
          {#each availableMonths as m}
            <option value={m}>{monthNames[m]}</option>
          {/each}
        </select>
        <ChevronDown class="w-4 h-4 text-gray-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
      </div>

      <div class="relative">
        <select bind:value={filterTahun} class="appearance-none p-2.5 pl-3 pr-8 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm w-32 outline-none focus:border-primary focus:ring-4 focus:ring-primary/20 hover:border-gray-300 transition-all shadow-sm text-gray-700 cursor-pointer">
          <option value="semua">Semua Tahun</option>
          {#each availableYears as t}
            <option value={t}>{t}</option>
          {/each}
        </select>
        <ChevronDown class="w-4 h-4 text-gray-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
      </div>

      <button type="button" onclick={() => showSettingsModal = true} class="p-2.5 border-2 border-gray-200 rounded-xl bg-white hover:bg-gray-50 hover:border-gray-300 transition-all shadow-sm text-gray-700 focus:ring-4 focus:ring-primary/20 outline-none" title="Pengaturan BKU">
        <Settings class="w-5 h-5" />
      </button>

      <button type="button" onclick={exportToWord} disabled={isGeneratingWord} class="p-2.5 bg-blue-600 text-white rounded-xl shadow-sm hover:bg-blue-700 transition-colors focus:ring-4 focus:ring-blue-600/20 outline-none disabled:opacity-50 disabled:cursor-not-allowed" title="Cetak Word">
        {#if isGeneratingWord}
          <Loader2 class="w-5 h-5 animate-spin" />
        {:else}
          <Download class="w-5 h-5" />
        {/if}
      </button>
    </div>
  </div>

  <!-- BKU Table -->
  <div class="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm">
    <!-- Identitas Sekolah BKU -->
    <div class="p-6 border-b border-gray-200 bg-gray-50/30">
      <div class="text-center mb-6">
        <h2 class="font-bold text-lg tracking-widest uppercase">Buku Kas Umum</h2>
        {#if filterBulan !== 'semua' || filterTahun !== 'semua'}
          <p class="text-sm font-semibold text-gray-600 mt-1 uppercase">
            {filterBulan !== 'semua' ? monthNames[filterBulan] : ''} {filterTahun !== 'semua' ? filterTahun : ''}
          </p>
        {/if}
      </div>
      <div class="grid grid-cols-[150px_10px_1fr] gap-y-1 text-sm font-medium text-gray-700">
        <div>Nama Sekolah</div><div>:</div><div>{bkuConfig.namaSekolah}</div>
        <div>Desa / Kecamatan</div><div>:</div><div>{bkuConfig.desaKecamatan}</div>
        <div>Kabupaten</div><div>:</div><div>{bkuConfig.kabupaten}</div>
        <div>Provinsi</div><div>:</div><div>{bkuConfig.provinsi}</div>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        <thead class="text-xs text-gray-700 uppercase bg-gray-100 border-b-2 border-gray-300">
          <tr>
            <th class="px-4 py-3 text-center border-r border-gray-200 w-12">No</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 whitespace-nowrap">Tanggal</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 whitespace-nowrap">No. Kode</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 whitespace-nowrap">No. Bukti</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 w-[30%]">Uraian</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 bg-emerald-50/50 text-emerald-800">Penerimaan (Debet)</th>
            <th class="px-4 py-3 text-center border-r border-gray-200 bg-red-50/50 text-red-800">Pengeluaran (Kredit)</th>
            <th class="px-4 py-3 text-center bg-blue-50/50 text-blue-800">Saldo</th>
          </tr>
          <!-- Nomor Kolom Bawah -->
          <tr class="bg-gray-50 border-t border-gray-200 text-gray-400">
            <th class="py-1 text-center border-r font-normal">1</th>
            <th class="py-1 text-center border-r font-normal">2</th>
            <th class="py-1 text-center border-r font-normal">3</th>
            <th class="py-1 text-center border-r font-normal">4</th>
            <th class="py-1 text-center border-r font-normal">5</th>
            <th class="py-1 text-center border-r font-normal">6</th>
            <th class="py-1 text-center border-r font-normal">7</th>
            <th class="py-1 text-center font-normal">8</th>
          </tr>
        </thead>
        <tbody>
          {#if loading}
            <tr><td colspan="8" class="text-center py-12 text-muted-foreground animate-pulse font-medium">Memuat dan menghitung BKU...</td></tr>
          {:else if bkuEntries.length === 0}
            <tr><td colspan="8" class="text-center py-12 text-muted-foreground">Tidak ada data BKU pada periode ini.</td></tr>
          {:else}
            {#each bkuEntries as entry, i}
              <tr class="border-b border-gray-100 hover:bg-gray-50/50 group">
                <td class="px-4 py-3 text-center border-r">{i + 1}</td>
                <td class="px-4 py-3 text-center border-r whitespace-nowrap">{new Date(entry.tanggal).toLocaleDateString('id-ID', {day:'2-digit', month:'2-digit', year:'numeric'}).replace(/\//g, '-')}</td>
                <td class="px-4 py-3 text-center border-r">{entry.no_kode}</td>
                <td class="px-4 py-3 text-center border-r">{entry.no_bukti}</td>
                <td class="px-4 py-3 border-r">
                  <div class="whitespace-pre-wrap leading-relaxed font-medium text-gray-700">{entry.uraian}</div>
                </td>
                <td class="px-4 py-3 text-right border-r font-semibold text-emerald-600">{entry.penerimaan > 0 ? formatRupiah(entry.penerimaan) : ''}</td>
                <td class="px-4 py-3 text-right border-r font-semibold text-red-600">{entry.pengeluaran > 0 ? formatRupiah(entry.pengeluaran) : ''}</td>
                <td class="px-4 py-3 text-right font-bold text-gray-900 bg-blue-50/10">{formatRupiah(entry.saldo)}</td>
              </tr>
            {/each}
            
            <!-- Footer Row (Jumlah) -->
            <tr class="bg-gray-100 border-t-2 border-gray-300">
              <td colspan="5" class="px-4 py-4 text-center border-r font-black text-gray-800 uppercase tracking-widest">JUMLAH</td>
              <td class="px-4 py-4 text-right border-r font-black text-emerald-700 text-base">{formatRupiah(totalPenerimaan)}</td>
              <td class="px-4 py-4 text-right border-r font-black text-red-700 text-base">{formatRupiah(totalPengeluaran)}</td>
              <td class="px-4 py-4 text-right font-black text-blue-800 text-base">{formatRupiah(saldoAkhir)}</td>
            </tr>
          {/if}
        </tbody>
      </table>
    </div>

    <!-- Tanda Tangan Preview -->
    {#if !loading && bkuEntries.length > 0}
      <div class="p-8 grid grid-cols-2 mt-8 text-center text-sm font-medium text-gray-800">
        <div class="space-y-20">
          <div>Mengetahui<br>Kepala {bkuConfig.namaSekolah}</div>
          <div class="font-bold underline uppercase">{bkuConfig.namaKepala}</div>
        </div>
        <div class="space-y-20">
          <div>Dibuat oleh<br>Bendahara {bkuConfig.namaSekolah}</div>
          <div class="font-bold underline uppercase">{bkuConfig.namaBendahara}</div>
        </div>
      </div>
    {/if}
  </div>
</div>



<!-- Modal Pengaturan -->
{#if showSettingsModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showSettingsModal = false}>
    <div class="relative max-w-2xl w-full bg-white rounded-2xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b bg-gray-50">
        <h3 class="font-bold text-lg flex items-center gap-2"><Settings class="w-5 h-5"/> Pengaturan Tanda Tangan BKU</h3>
      </div>
      <div class="p-5 overflow-y-auto max-h-[70vh] space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-sm font-semibold mb-1">Nama Sekolah (Header)</label>
            <input type="text" bind:value={bkuConfig.namaSekolah} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Desa / Kecamatan</label>
            <input type="text" bind:value={bkuConfig.desaKecamatan} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Kabupaten</label>
            <input type="text" bind:value={bkuConfig.kabupaten} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-semibold mb-1">Provinsi</label>
            <input type="text" bind:value={bkuConfig.provinsi} class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-primary" />
          </div>
        </div>
        <hr class="my-4 border-dashed" />
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold mb-1 text-primary">Nama Kepala SPM</label>
            <input type="text" bind:value={bkuConfig.namaKepala} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold uppercase outline-none focus:border-primary" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1 text-primary">Nama Bendahara SPM</label>
            <input type="text" bind:value={bkuConfig.namaBendahara} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold uppercase outline-none focus:border-primary" />
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
