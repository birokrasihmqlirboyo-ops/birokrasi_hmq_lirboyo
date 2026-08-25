<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { Button } from '$lib/components/ui/button';
  import * as Table from '$lib/components/ui/table';
  import { Document, Packer, Paragraph, TextRun, ImageRun, Table as DocxTable, TableRow, TableCell, BorderStyle, WidthType, AlignmentType, PageBreak } from 'docx';
  import { saveAs } from 'file-saver';
  import * as XLSX from 'xlsx';
  import { Eye, FileDown, Pencil, Trash2, Filter, Loader2, Search, Plus, ChevronDown } from "lucide-svelte";
  import ColumnFilter from '$lib/components/ColumnFilter.svelte';
  import { terbilang } from '$lib/utils';

  let transactions: any[] = $state([]);
  let loading = $state(true);
  
  let filterBulan = $state('semua');
  let filterTahun = $state('semua');

  const monthNames: Record<string, string> = {
    '1': 'Januari', '2': 'Februari', '3': 'Maret', '4': 'April',
    '5': 'Mei', '6': 'Juni', '7': 'Juli', '8': 'Agustus',
    '9': 'September', '10': 'Oktober', '11': 'November', '12': 'Desember'
  };

  let availableMonths = $derived.by(() => {
    const months = new Set<string>();
    transactions.forEach(tx => {
      if (tx.tanggal_pembelian) months.add(parseInt(tx.tanggal_pembelian.split('-')[1], 10).toString());
    });
    return Array.from(months).sort((a, b) => parseInt(a) - parseInt(b));
  });

  let availableYears = $derived.by(() => {
    const years = new Set<string>();
    transactions.forEach(tx => {
      if (tx.tanggal_pembelian) years.add(tx.tanggal_pembelian.split('-')[0]);
    });
    return Array.from(years).sort((a, b) => parseInt(b) - parseInt(a));
  });

  let searchQuery = $state('');
  let columnFilters = $state<Record<string, string>>({});

  let uniqueColumnValues = $derived({
    'Seksi': Array.from(new Set(transactions.map(tx => tx.seksi).filter(Boolean))).sort(),
    'Nama Toko': Array.from(new Set(transactions.map(tx => tx.nama_toko).filter(Boolean))).sort()
  });

  let filteredTransactions = $derived(
    transactions.filter(tx => {
      if (!tx.tanggal_pembelian) return false;
      const parts = tx.tanggal_pembelian.split('-');
      const yyyy = parts[0];
      const mm = parseInt(parts[1], 10).toString();
      
      const matchBulan = filterBulan === 'semua' || mm === filterBulan;
      const matchTahun = filterTahun === 'semua' || yyyy === filterTahun;
      if (!matchBulan || !matchTahun) return false;

      // Global search
      if (searchQuery) {
        const term = searchQuery.toLowerCase();
        const searchableText = `${tx.seksi} ${tx.nama_toko} ${tx.tanggal_pembelian} ${tx.nama_kegiatan || ''}`.toLowerCase();
        const itemsText = tx.transaction_items?.map((item: any) => item.nama_barang).join(' ').toLowerCase() || '';
        
        if (!searchableText.includes(term) && !itemsText.includes(term)) {
          return false;
        }
      }

      // Column filters
      if (columnFilters['Seksi'] && tx.seksi !== columnFilters['Seksi']) return false;
      if (columnFilters['Nama Toko'] && tx.nama_toko !== columnFilters['Nama Toko']) return false;

      return true;
    })
  );

  // Popup Excel State
  let showExcelModal = $state(false);
  let excelBulan = $state('semua');
  let excelTahun = $state('semua');

  // Popup Filter State
  let showFilterModal = $state(false);

  // Word Config Modal State
  let showWordModal = $state(false);
  let selectedTxsForWord = $state<any[]>([]);
  let selectedTransactions = $state<string[]>([]);
  let wordConfig = $state({
    nomorBukti: '',
    sumberDana: 'Dana BOS Periode Juli s.d September 2025',
    sudahTerimaDari: 'Kepala MTs. Husnul Khatimah',
    madrasah: 'MTs. Husnul Khatimah',
    desaKecamatan: 'Tirto - Pekalongan',
    kabupaten: 'Pekalongan',
    provinsi: 'Jawa Tengah',
    kepalaMadrasah: 'H. Habiburokhman, S.Ag',
    bendaharaMadrasah: 'Cici Ulya, S.Pd'
  });

  // Popup Image State
  let selectedImageUrl = $state<string | null>(null);
  let selectedImageTitle = $state('');

  function openImagePopup(url: string, title: string) {
    selectedImageUrl = url;
    selectedImageTitle = title;
  }

  function closeImagePopup() {
    selectedImageUrl = null;
  }

  async function downloadSelectedImage() {
    if (!selectedImageUrl) return;
    try {
      const response = await fetch(selectedImageUrl);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${selectedImageTitle.replace(/\s+/g, '_')}_${Date.now()}.jpg`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
    } catch (e) {
      alert("Gagal mendownload gambar.");
    }
  }

  onMount(() => {
    fetchData();
    
    const savedConfig = localStorage.getItem('wordConfigHMQ');
    if (savedConfig) {
      try {
        wordConfig = JSON.parse(savedConfig);
      } catch (e) {}
    }
  });

  async function fetchData() {
    loading = true;
    const { data, error } = await supabase
      .from('transactions')
      .select(`
        id,
        seksi,
        tanggal_pembelian,
        tanggal_input,
        nama_toko,
        nama_kegiatan,
        foto_barang_url,
        foto_nota_url,
        transaction_items (
          id,
          nama_barang,
          jumlah,
          harga_satuan,
          diskon_nominal
        )
      `)
      .order('tanggal_input', { ascending: false });

    if (error) {
      alert('Gagal mengambil data: ' + error.message);
    } else {
      transactions = data || [];
    }
    loading = false;
  }

  async function handleLogout() {
    await supabase.auth.signOut();
    goto('/login');
  }

  function formatRupiah(val: number) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(val);
  }

  async function deleteTransaction(id: string) {
    if (!confirm('Yakin ingin menghapus transaksi ini? Data rincian akan ikut terhapus permanen.')) return;
    loading = true;
    const { error } = await supabase.from('transactions').delete().eq('id', id);
    if (error) {
      alert('Gagal menghapus data: ' + error.message);
      loading = false;
    } else {
      await fetchData(); // refresh data
    }
  }

  function openWordModal(tx: any | any[]) {
    selectedTxsForWord = Array.isArray(tx) ? tx : [tx];
    showWordModal = true;
  }

  async function fetchImageAsBuffer(url: string): Promise<ArrayBuffer> {
    const response = await fetch(url);
    if (!response.ok) throw new Error('Gagal mengunduh gambar');
    return await response.arrayBuffer();
  }

  async function getImageDataAndSize(url: string): Promise<{ buffer: ArrayBuffer, width: number, height: number }> {
    const buffer = await fetchImageAsBuffer(url);
    return new Promise((resolve, reject) => {
      const blob = new Blob([buffer]);
      const blobUrl = URL.createObjectURL(blob);
      const img = new Image();
      img.onload = () => {
        URL.revokeObjectURL(blobUrl);
        const MAX_WIDTH = 500;
        let w = img.width;
        let h = img.height;
        if (w > MAX_WIDTH) {
          h = (MAX_WIDTH / w) * h;
          w = MAX_WIDTH;
        }
        resolve({ buffer, width: w, height: h });
      };
      img.onerror = () => reject(new Error('Gagal memuat info gambar'));
      img.src = blobUrl;
    });
  }

  async function generateWordDocument() {
    if (!selectedTxsForWord || selectedTxsForWord.length === 0) return;
    
    // Simpan pengaturan untuk transaksi berikutnya
    localStorage.setItem('wordConfigHMQ', JSON.stringify(wordConfig));

    const children: any[] = [];
    const NO_BORDER = { top: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" }, bottom: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" }, left: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" }, right: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" } };

    for (let i = 0; i < selectedTxsForWord.length; i++) {
      const tx = selectedTxsForWord[i];
      const dateObj = new Date(tx.tanggal_pembelian);
      const tahunAnggaran = dateObj.getFullYear().toString();
      const formattedDate = dateObj.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });

      const totalBelanja = tx.transaction_items.reduce((sum: number, item: any) => sum + ((item.jumlah * item.harga_satuan) - item.diskon_nominal), 0);
      const totalTerbilang = terbilang(totalBelanja) + " Rupiah";

      const rincianItems = tx.transaction_items.map((item: any) => `${item.nama_barang}, ${item.jumlah}x @ Rp ${item.harga_satuan.toLocaleString('id-ID')}`);

      // Header Format K-14
      children.push(
        new DocxTable({
          width: { size: 100, type: WidthType.PERCENTAGE },
          borders: NO_BORDER,
          rows: [
            new TableRow({
              children: [
                new TableCell({ children: [], width: { size: 70, type: WidthType.PERCENTAGE }, borders: NO_BORDER }),
                new TableCell({
                  width: { size: 30, type: WidthType.PERCENTAGE },
                  borders: {
                    top: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
                    bottom: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
                    left: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
                    right: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
                  },
                  children: [
                    new Paragraph({ children: [new TextRun({ text: "FORMAT K-14", bold: true })], alignment: AlignmentType.CENTER }),
                    new Paragraph({ children: [new TextRun({ text: "Diisi oleh Madrasah", italics: true })], alignment: AlignmentType.CENTER })
                  ]
                })
              ]
            })
          ]
        })
      );

      children.push(new Paragraph({ text: "", spacing: { after: 200 } }));

      const kuitansiContent = [
        new Paragraph({ children: [new TextRun({ text: "KUITANSI / BUKTI PEMBAYARAN", bold: true, size: 28 })], alignment: AlignmentType.CENTER, spacing: { after: 400 } }),
        
        new DocxTable({
          width: { size: 100, type: WidthType.PERCENTAGE },
          borders: NO_BORDER,
          rows: [
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ children: [new TextRun("Tahun Anggaran")], alignment: AlignmentType.RIGHT })], width: { size: 70, type: WidthType.PERCENTAGE }, borders: NO_BORDER }),
                new TableCell({ children: [new Paragraph({ children: [new TextRun(" : " + tahunAnggaran)] })], width: { size: 30, type: WidthType.PERCENTAGE }, borders: NO_BORDER }),
              ]
            }),
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ children: [new TextRun("Nomor Bukti")], alignment: AlignmentType.RIGHT })], borders: NO_BORDER }),
                new TableCell({ children: [new Paragraph({ children: [new TextRun(" : " + wordConfig.nomorBukti)] })], borders: NO_BORDER }),
              ]
            })
          ]
        }),

        new Paragraph({ text: "", spacing: { after: 200 } }),

        new DocxTable({
          width: { size: 100, type: WidthType.PERCENTAGE },
          borders: NO_BORDER,
          rows: [
            ["Sudah terima dari", wordConfig.sudahTerimaDari],
            ["Madrasah", wordConfig.madrasah],
            ["Desa/Kecamatan", wordConfig.desaKecamatan],
            ["Kabupaten", wordConfig.kabupaten],
            ["Provinsi", wordConfig.provinsi],
            ["Jumlah Uang", `Rp. ${totalBelanja.toLocaleString('id-ID')},-`],
            ["Terbilang", totalTerbilang],
            ["Untuk pembayaran", rincianItems],
            ["Sumber Dana", wordConfig.sumberDana]
          ].map(row => new TableRow({
            children: [
              new TableCell({ children: [new Paragraph({ text: row[0] as string })], width: { size: 25, type: WidthType.PERCENTAGE }, borders: NO_BORDER }),
              new TableCell({ 
                children: [
                  new Paragraph({ 
                    children: [
                      new TextRun({ text: ": " }),
                      ...(Array.isArray(row[1])
                        ? row[1].map((text: string, idx: number) => new TextRun({ text: idx === 0 ? text : `  ${text}`, break: idx === 0 ? 0 : 1 }))
                        : [new TextRun({ text: (row[1] as string), italics: row[0] === "Terbilang", bold: row[0] === "Jumlah Uang" })])
                    ] 
                  })
                ], 
                width: { size: 75, type: WidthType.PERCENTAGE }, borders: NO_BORDER 
              }),
            ]
          }))
        }),
        
        new Paragraph({ text: "", spacing: { after: 600 } }),

        new Paragraph({ children: [new TextRun("Penerima Uang,")], alignment: AlignmentType.RIGHT, indent: { right: 1000 } }),
        new Paragraph({ text: "", spacing: { after: 1000 } }),
        new Paragraph({ children: [new TextRun({ text: tx.nama_toko, bold: true })], alignment: AlignmentType.RIGHT, indent: { right: 1000 } }),
        
        new Paragraph({ text: "", spacing: { after: 200 } }),

        new Paragraph({ children: [new TextRun(`Lunas dibayar tanggal : ${formattedDate}`)], alignment: AlignmentType.CENTER }),
        new Paragraph({
          children: [new TextRun({ text: "__________________________________________________________________________________" })],
          alignment: AlignmentType.CENTER,
          spacing: { after: 200 }
        }),

        new DocxTable({
          width: { size: 100, type: WidthType.PERCENTAGE },
          borders: NO_BORDER,
          rows: [
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ children: [new TextRun("Kepala Madrasah,")], alignment: AlignmentType.CENTER })], borders: NO_BORDER, width: { size: 50, type: WidthType.PERCENTAGE } }),
                new TableCell({ children: [new Paragraph({ children: [new TextRun("Bendahara Madrasah,")], alignment: AlignmentType.CENTER })], borders: NO_BORDER, width: { size: 50, type: WidthType.PERCENTAGE } }),
              ]
            }),
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ text: "", spacing: { after: 1000 } })], borders: NO_BORDER }),
                new TableCell({ children: [new Paragraph({ text: "", spacing: { after: 1000 } })], borders: NO_BORDER }),
              ]
            }),
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: wordConfig.kepalaMadrasah, bold: true })], alignment: AlignmentType.CENTER })], borders: NO_BORDER }),
                new TableCell({ children: [new Paragraph({ children: [new TextRun({ text: wordConfig.bendaharaMadrasah, bold: true })], alignment: AlignmentType.CENTER })], borders: NO_BORDER }),
              ]
            })
          ]
        })
      ];

      children.push(
        new DocxTable({
          width: { size: 100, type: WidthType.PERCENTAGE },
          borders: {
            top: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
            bottom: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
            left: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
            right: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
          },
          margins: { top: 300, bottom: 300, left: 300, right: 300 },
          rows: [
            new TableRow({
              children: [
                new TableCell({ 
                  borders: {
                    top: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
                    bottom: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
                    left: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
                    right: { style: BorderStyle.SINGLE, size: 6, color: "000000" },
                  },
                  children: kuitansiContent 
                })
              ]
            })
          ]
        })
      );

      // Halaman 2: Foto Barang
      if (tx.foto_barang_url) {
        children.push(new Paragraph({ children: [new PageBreak()] }));
        children.push(new Paragraph({ children: [new TextRun({ text: "FOTO BARANG", bold: true, size: 28 })], alignment: AlignmentType.CENTER, spacing: { after: 400 } }));
        try {
          const imgData = await getImageDataAndSize(tx.foto_barang_url);
          children.push(new Paragraph({
            children: [new ImageRun({ data: new Uint8Array(imgData.buffer), transformation: { width: imgData.width, height: imgData.height }, type: "png" })],
            alignment: AlignmentType.CENTER
          }));
        } catch (e) {}
      }

      // Halaman 3: Foto Nota
      if (tx.foto_nota_url) {
        children.push(new Paragraph({ children: [new PageBreak()] }));
        children.push(new Paragraph({ children: [new TextRun({ text: "FOTO NOTA", bold: true, size: 28 })], alignment: AlignmentType.CENTER, spacing: { after: 400 } }));
        try {
          const imgData = await getImageDataAndSize(tx.foto_nota_url);
          children.push(new Paragraph({
            children: [new ImageRun({ data: new Uint8Array(imgData.buffer), transformation: { width: imgData.width, height: imgData.height }, type: "png" })],
            alignment: AlignmentType.CENTER
          }));
        } catch (e) {}
      }

      // Berikan Page Break di akhir K-14 transaksi ini jika ada transaksi selanjutnya
      if (i < selectedTxsForWord.length - 1) {
        children.push(new Paragraph({ children: [new PageBreak()] }));
      }
    }

    const doc = new Document({
      sections: [{ properties: {}, children: children }]
    });

    try {
      const blob = await Packer.toBlob(doc);
      let filename = selectedTxsForWord.length > 1 
        ? `Kuitansi_Gabungan_${selectedTxsForWord.length}Toko_${Date.now()}.docx` 
        : `Kuitansi_${selectedTxsForWord[0].nama_toko}_${selectedTxsForWord[0].tanggal_pembelian}.docx`;
      saveAs(blob, filename);
      showWordModal = false;
      selectedTransactions = []; // Reset setelah download
    } catch (err: any) {
      alert("Gagal membuat dokumen Word: " + err.message);
    }
  }

  let isGeneratingExcel = $state(false);
  async function executeDownloadExcel() {
    isGeneratingExcel = true;
    try {
      // Allow UI to update loading state
      await new Promise(r => setTimeout(r, 100));
      const dataToDownload = transactions.filter(tx => {
        if (!tx.tanggal_pembelian) return false;
        
        const parts = tx.tanggal_pembelian.split('-');
        if (parts.length !== 3) return false;
        
        const yyyy = parts[0];
        const mm = parseInt(parts[1], 10).toString();
        
        const matchBulan = excelBulan === 'semua' || mm === excelBulan;
        const matchTahun = excelTahun === 'semua' || yyyy === excelTahun;
        
        return matchBulan && matchTahun;
      });

      if (dataToDownload.length === 0) {
        alert('Tidak ada data pada periode ini untuk di-download.');
        return;
      }

      const excelRows: any[] = [];
      dataToDownload.forEach((tx: any) => {
        tx.transaction_items.forEach((item: any) => {
          const totalHarga = (item.jumlah * item.harga_satuan) - item.diskon_nominal;
          excelRows.push({
            'Seksi': tx.seksi,
            'Tanggal Pembelian': tx.tanggal_pembelian,
            'Tanggal Input': new Date(tx.tanggal_input).toLocaleString('id-ID'),
            'Nama Toko': tx.nama_toko,
            'Nama Kegiatan': tx.nama_kegiatan || '-',
            'Nama Barang': item.nama_barang,
            'Jumlah': item.jumlah,
            'Harga Satuan': item.harga_satuan,
            'Diskon Nominal': item.diskon_nominal,
            'Total Harga': totalHarga,
            'Link Bukti Barang': tx.foto_barang_url || '-',
            'Link Bukti Nota': tx.foto_nota_url || '-'
          });
        });
      });

      const worksheet = XLSX.utils.json_to_sheet(excelRows);
      const workbook = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(workbook, worksheet, 'Laporan Pleno');
      
      let filename = 'Laporan_Pleno';
      if (excelBulan !== 'semua') filename += `_Bulan_${excelBulan}`;
      if (excelTahun !== 'semua') filename += `_Tahun_${excelTahun}`;
      filename += `_${new Date().toISOString().split('T')[0]}.xlsx`;

      XLSX.writeFile(workbook, filename);
      showExcelModal = false;
    } catch (error: any) {
      alert('Terjadi kesalahan saat download excel: ' + error.message);
    } finally {
      isGeneratingExcel = false;
    }
  }

  function openExcelModal() {
    excelBulan = filterBulan;
    excelTahun = filterTahun === 'semua' ? new Date().getFullYear().toString() : filterTahun;
    showExcelModal = true;
  }
</script>

<div class="p-4 sm:p-8 w-full max-w-[1600px] mx-auto space-y-6">
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
    <div class="flex items-center gap-4">
      <div>
        <h1 class="text-3xl font-bold tracking-tight text-foreground">Dashboard Admin</h1>
        <p class="text-muted-foreground">Data rincian pembelian (Pleno).</p>
      </div>
    </div>
    <div class="flex flex-wrap gap-2 sm:gap-4 items-center">
      {#if filterBulan !== 'semua' || filterTahun !== 'semua'}
        <div class="flex items-center gap-1.5 text-sm font-bold text-primary px-3 py-1.5 bg-primary/10 rounded-full">
          <span>{filterBulan !== 'semua' ? monthNames[filterBulan] : ''} {filterTahun !== 'semua' ? filterTahun : ''}</span>
          <button type="button" onclick={() => { filterBulan = 'semua'; filterTahun = 'semua'; }} class="hover:bg-primary/20 text-primary p-0.5 rounded-full transition-colors" title="Hapus Filter">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
          </button>
        </div>
      {/if}
      
      <!-- Global Search -->
      <div class="relative w-full sm:w-64">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <input 
          type="text" 
          bind:value={searchQuery}
          placeholder="Cari transaksi..." 
          class="pl-9 w-full p-2.5 bg-white border-2 border-gray-200 rounded-xl text-sm focus:ring-4 focus:ring-primary/20 outline-none hover:border-gray-300 transition-all shadow-sm text-gray-800"
        />
      </div>

      <button type="button" onclick={() => showFilterModal = true} class="p-2.5 border-2 border-gray-200 rounded-xl bg-white hover:bg-gray-50 hover:border-gray-300 transition-all shadow-sm text-gray-700 focus:ring-4 focus:ring-primary/20 outline-none" title="Filter Data">
        <Filter class="w-5 h-5" />
      </button>

      <button type="button" onclick={openExcelModal} class="p-2.5 bg-emerald-600 text-white rounded-xl shadow-sm hover:bg-emerald-700 transition-colors focus:ring-4 focus:ring-emerald-600/20 outline-none" title="Download Excel">
        <FileDown class="w-5 h-5" />
      </button>

      <a href="/" class="p-2.5 bg-white border-2 border-gray-200 text-gray-700 rounded-xl shadow-sm hover:bg-gray-50 hover:border-gray-300 transition-colors focus:ring-4 focus:ring-primary/20 outline-none" title="Ke Halaman Input">
        <Plus class="w-5 h-5" />
      </a>
    </div>
  </div>

  {#if selectedTransactions.length > 0}
    <div class="mb-4 p-4 bg-primary/10 border border-primary/20 rounded-xl flex items-center justify-between shadow-sm">
      <span class="font-bold text-primary">{selectedTransactions.length} Transaksi Terpilih</span>
      <Button onclick={() => {
        const txs = filteredTransactions.filter(t => selectedTransactions.includes(t.id));
        openWordModal(txs);
      }} class="bg-primary hover:bg-primary/90 text-white font-bold shadow-lg">
        Gabung Terpilih ke Word
      </Button>
    </div>
  {/if}

  <div class="border rounded-md">
    <Table.Root>
      <Table.Header>
        <Table.Row class="bg-gray-100/50">
          <Table.Head class="w-10 border-r border-gray-200 text-center align-middle">
            <input type="checkbox"
              checked={filteredTransactions.length > 0 && selectedTransactions.length === filteredTransactions.length}
              onchange={(e) => {
                if (e.currentTarget.checked) {
                  selectedTransactions = filteredTransactions.map(t => t.id);
                } else {
                  selectedTransactions = [];
                }
              }}
              class="w-4 h-4 rounded text-primary focus:ring-primary/20 cursor-pointer" />
          </Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Tanggal</Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Seksi</Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Nama Toko</Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Total Barang</Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Total Belanja</Table.Head>
          <Table.Head class="border-r border-gray-200 text-center font-semibold text-gray-700">Lampiran</Table.Head>
          <Table.Head class="text-center font-semibold text-gray-700">Aksi</Table.Head>
        </Table.Row>
        <Table.Row class="bg-gray-50">
          <Table.Head class="border-r border-gray-200"></Table.Head>
          <Table.Head class="border-r border-gray-200"></Table.Head>
          <Table.Head class="p-1 border-r border-gray-200">
            <ColumnFilter options={uniqueColumnValues['Seksi']} bind:value={columnFilters['Seksi']} placeholder="Semua Seksi" />
          </Table.Head>
          <Table.Head class="p-1 border-r border-gray-200">
            <ColumnFilter options={uniqueColumnValues['Nama Toko']} bind:value={columnFilters['Nama Toko']} placeholder="Semua Toko" />
          </Table.Head>
          <Table.Head class="border-r border-gray-200"></Table.Head>
          <Table.Head class="border-r border-gray-200"></Table.Head>
          <Table.Head class="border-r border-gray-200"></Table.Head>
          <Table.Head></Table.Head>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {#if loading}
          <Table.Row>
            <Table.Cell colspan={8} class="text-center py-10">Memuat data...</Table.Cell>
          </Table.Row>
        {:else if filteredTransactions.length === 0}
          <Table.Row>
            <Table.Cell colspan={8} class="text-center py-10">Belum ada data transaksi untuk filter ini.</Table.Cell>
          </Table.Row>
        {:else}
          {#each filteredTransactions as tx}
            {@const totalBelanja = tx.transaction_items.reduce((sum: number, item: any) => sum + ((item.jumlah * item.harga_satuan) - item.diskon_nominal), 0)}
            <Table.Row class="hover:bg-primary/5 transition-colors group">
              <Table.Cell class="border-r border-gray-200 text-center align-middle">
                <input type="checkbox"
                  checked={selectedTransactions.includes(tx.id)}
                  onchange={(e) => {
                    if (e.currentTarget.checked) {
                      selectedTransactions = [...selectedTransactions, tx.id];
                    } else {
                      selectedTransactions = selectedTransactions.filter(id => id !== tx.id);
                    }
                  }}
                  class="w-4 h-4 rounded text-primary focus:ring-primary/20 cursor-pointer" />
              </Table.Cell>
              <Table.Cell class="border-r border-gray-200 text-center align-middle font-medium">{new Date(tx.tanggal_pembelian).toLocaleDateString('id-ID')}</Table.Cell>
              <Table.Cell class="border-r border-gray-200 text-center align-middle">{tx.seksi}</Table.Cell>
              <Table.Cell class="border-r border-gray-200 text-center align-middle">
                <div class="font-medium">{tx.nama_toko}</div>
                {#if tx.nama_kegiatan}
                  <div class="text-xs text-muted-foreground">{tx.nama_kegiatan}</div>
                {/if}
              </Table.Cell>
              <Table.Cell class="border-r border-gray-200 align-middle">
                <div class="flex flex-col gap-1.5">
                  {#each tx.transaction_items as item}
                    {@const subtotal = (item.jumlah * item.harga_satuan) - item.diskon_nominal}
                    <span class="text-xs text-muted-foreground whitespace-normal leading-tight">
                      • {item.nama_barang} ({item.jumlah}x @ {formatRupiah(item.harga_satuan)}) 
                      {#if item.diskon_nominal > 0}
                        <span class="text-red-500"> - Diskon {formatRupiah(item.diskon_nominal)}</span>
                      {/if}
                      = <span class="font-semibold text-foreground">{formatRupiah(subtotal)}</span>
                    </span>
                  {/each}
                </div>
              </Table.Cell>
              <Table.Cell class="border-r border-gray-200 text-center align-middle font-semibold text-gray-700">{formatRupiah(totalBelanja)}</Table.Cell>
              <Table.Cell class="border-r border-gray-200 text-center align-middle">
                <div class="flex gap-2 justify-center">
                  {#if tx.foto_nota_url}
                    <button type="button" onclick={() => openImagePopup(tx.foto_nota_url, 'Nota ' + tx.nama_toko)} class="p-2 bg-blue-50 text-blue-600 rounded-md hover:bg-blue-100 transition-colors" title="Lihat Nota">
                      <Eye class="w-4 h-4" />
                    </button>
                  {/if}
                  {#if tx.foto_barang_url}
                    <button type="button" onclick={() => openImagePopup(tx.foto_barang_url, 'Barang ' + tx.nama_toko)} class="p-2 bg-blue-50 text-blue-600 rounded-md hover:bg-blue-100 transition-colors" title="Lihat Barang">
                      <Eye class="w-4 h-4" />
                    </button>
                  {/if}
                  {#if tx.foto_nota_url || tx.foto_barang_url}
                    <button type="button" class="p-2 bg-emerald-50 text-emerald-600 rounded-md hover:bg-emerald-100 transition-colors" title="Cetak Kuitansi Word" onclick={() => openWordModal(tx)}>
                      <FileDown class="w-4 h-4" />
                    </button>
                  {/if}
                </div>
              </Table.Cell>
              <Table.Cell class="text-center align-middle">
                <div class="flex gap-2 justify-center">
                  <a href={`/admin/edit/${tx.id}`} class="p-2 bg-amber-50 text-amber-600 rounded-md hover:bg-amber-100 transition-colors" title="Edit Transaksi">
                    <Pencil class="w-4 h-4" />
                  </a>
                  <button type="button" class="p-2 bg-red-50 text-red-600 rounded-md hover:bg-red-100 transition-colors" title="Hapus Transaksi" onclick={() => deleteTransaction(tx.id)}>
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </Table.Cell>
            </Table.Row>
          {/each}
        {/if}
      </Table.Body>
    </Table.Root>
  </div>
</div>

{#if selectedImageUrl}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4" onclick={closeImagePopup}>
    <div class="relative max-w-4xl w-full bg-white rounded-xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-4 border-b flex justify-between items-center bg-gray-50">
        <h3 class="font-bold text-lg">{selectedImageTitle}</h3>
        <button type="button" onclick={closeImagePopup} class="text-gray-500 hover:text-red-500 text-3xl font-bold leading-none px-2">&times;</button>
      </div>
      <div class="p-4 flex-1 flex items-center justify-center bg-gray-100 overflow-auto" style="max-height: 70vh;">
        <img src={selectedImageUrl} alt={selectedImageTitle} class="max-w-full max-h-full object-contain shadow-sm rounded-lg" />
      </div>
      <div class="p-4 border-t bg-gray-50 flex justify-end gap-3">
        <Button variant="outline" onclick={closeImagePopup}>Tutup</Button>
        <Button onclick={downloadSelectedImage} class="flex items-center gap-2">
          <FileDown class="w-4 h-4" /> Download Gambar
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showExcelModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showExcelModal = false}>
    <div class="relative max-w-sm w-full bg-white rounded-xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b">
        <h3 class="font-bold text-lg">Pilih Periode Download</h3>
        <p class="text-sm text-muted-foreground mt-1">Pilih bulan dan tahun data laporan yang ingin Anda unduh.</p>
      </div>
      
      <div class="p-5 space-y-4">
        <div>
          <label class="block text-sm font-semibold mb-1.5">Bulan</label>
          <div class="relative">
            <select bind:value={excelBulan} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm cursor-pointer appearance-none focus:ring-4 focus:ring-primary/20 outline-none hover:border-gray-300 transition-all text-gray-800">
              <option value="semua">Semua Bulan</option>
              {#each availableMonths as m}
                <option value={m}>{monthNames[m]}</option>
              {/each}
            </select>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3.5 pointer-events-none text-gray-400">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold mb-1.5">Tahun</label>
          <div class="relative">
            <select bind:value={excelTahun} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm cursor-pointer appearance-none focus:ring-4 focus:ring-primary/20 outline-none hover:border-gray-300 transition-all text-gray-800">
              <option value="semua">Semua Tahun</option>
              {#each availableYears as t}
                <option value={t}>{t}</option>
              {/each}
            </select>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3.5 pointer-events-none text-gray-400">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </div>
          </div>
        </div>
      </div>

      <div class="p-4 border-t bg-gray-50 flex justify-end gap-3">
        <Button variant="outline" onclick={() => showExcelModal = false} disabled={isGeneratingExcel}>Batal</Button>
        <Button onclick={executeDownloadExcel} disabled={isGeneratingExcel} class="bg-emerald-600 hover:bg-emerald-700 text-white border-0 flex items-center gap-2 min-w-[140px] justify-center">
          {#if isGeneratingExcel}
            <Loader2 class="w-4 h-4 animate-spin" /> Menyusun...
          {:else}
            <FileDown class="w-4 h-4" /> Download
          {/if}
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showFilterModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showFilterModal = false}>
    <div class="relative max-w-sm w-full bg-white rounded-xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b">
        <h3 class="font-bold text-lg flex items-center gap-2"><Filter class="w-5 h-5 text-primary" /> Filter Data Tabel</h3>
        <p class="text-sm text-muted-foreground mt-1">Hanya bulan dan tahun yang memiliki transaksi yang akan muncul di bawah ini.</p>
      </div>
      
      <div class="p-5 space-y-4">
        <div>
          <label class="block text-sm font-semibold mb-1.5">Bulan</label>
          <div class="relative">
            <select bind:value={filterBulan} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm cursor-pointer appearance-none focus:ring-4 focus:ring-primary/20 outline-none hover:border-gray-300 transition-all text-gray-800">
              <option value="semua">Semua Bulan</option>
              {#each availableMonths as m}
                <option value={m}>{monthNames[m]}</option>
              {/each}
            </select>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3.5 pointer-events-none text-gray-400">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold mb-1.5">Tahun</label>
          <div class="relative">
            <select bind:value={filterTahun} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white font-semibold text-sm cursor-pointer appearance-none focus:ring-4 focus:ring-primary/20 outline-none hover:border-gray-300 transition-all text-gray-800">
              <option value="semua">Semua Tahun</option>
              {#each availableYears as t}
                <option value={t}>{t}</option>
              {/each}
            </select>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3.5 pointer-events-none text-gray-400">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
            </div>
          </div>
        </div>
      </div>

      <div class="p-4 border-t bg-gray-50 flex justify-end gap-3">
        <Button class="bg-primary hover:bg-primary/90 text-white border-0 w-full" onclick={() => showFilterModal = false}>
          Terapkan Filter
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showWordModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showWordModal = false}>
    <div class="relative max-w-2xl w-full bg-white rounded-xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b bg-gray-50">
        <h3 class="font-bold text-lg">Pengaturan Cetak Kuitansi K-14</h3>
        <p class="text-sm text-muted-foreground mt-1">Isi data di bawah ini. Data akan otomatis tersimpan untuk cetakan berikutnya.</p>
      </div>
      
      <div class="p-5 overflow-auto max-h-[60vh] space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold mb-1">Nomor Bukti</label>
            <input type="text" bind:value={wordConfig.nomorBukti} placeholder="Misal: C_ULYA_176" class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Sumber Dana</label>
            <input type="text" bind:value={wordConfig.sumberDana} placeholder="Misal: Dana BOS..." class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Sudah Terima Dari</label>
            <input type="text" bind:value={wordConfig.sudahTerimaDari} class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Madrasah</label>
            <input type="text" bind:value={wordConfig.madrasah} class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Kepala Madrasah</label>
            <input type="text" bind:value={wordConfig.kepalaMadrasah} class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">Bendahara Madrasah</label>
            <input type="text" bind:value={wordConfig.bendaharaMadrasah} class="w-full p-2.5 border-2 rounded-xl text-sm" />
          </div>
          <div class="sm:col-span-2 grid grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-semibold mb-1">Desa/Kec</label>
              <input type="text" bind:value={wordConfig.desaKecamatan} class="w-full p-2.5 border-2 rounded-xl text-sm" />
            </div>
            <div>
              <label class="block text-sm font-semibold mb-1">Kabupaten</label>
              <input type="text" bind:value={wordConfig.kabupaten} class="w-full p-2.5 border-2 rounded-xl text-sm" />
            </div>
            <div>
              <label class="block text-sm font-semibold mb-1">Provinsi</label>
              <input type="text" bind:value={wordConfig.provinsi} class="w-full p-2.5 border-2 rounded-xl text-sm" />
            </div>
          </div>
        </div>
      </div>

      <div class="p-4 border-t bg-gray-50 flex justify-end gap-3">
        <Button variant="outline" onclick={() => showWordModal = false}>Batal</Button>
        <Button onclick={generateWordDocument} class="bg-blue-600 hover:bg-blue-700 text-white border-0 flex items-center gap-2">
          <FileDown class="w-4 h-4" /> Buat Kuitansi Word
        </Button>
      </div>
    </div>
  </div>
{/if}
