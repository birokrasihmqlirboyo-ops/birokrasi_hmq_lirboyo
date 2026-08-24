<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount, onDestroy } from 'svelte';
  import { Switch } from "$lib/components/ui/switch";
  import { Camera, Trash2, CheckCircle2, Plus } from "lucide-svelte";
  import Cropper from 'cropperjs';
  import 'cropperjs/dist/cropper.css';

  // Opsi Seksi
  const daftarSeksi = ['MUHAFADZOH', 'UJIAN', 'KORBUK', 'MUSYLAIL', 'DNA'];

  // Opsi Dropdown Tanggal
  const hariList = Array.from({length: 31}, (_, i) => (i + 1).toString());
  const bulanList = [
    { value: '1', label: 'Januari' }, { value: '2', label: 'Februari' }, { value: '3', label: 'Maret' },
    { value: '4', label: 'April' }, { value: '5', label: 'Mei' }, { value: '6', label: 'Juni' },
    { value: '7', label: 'Juli' }, { value: '8', label: 'Agustus' }, { value: '9', label: 'September' },
    { value: '10', label: 'Oktober' }, { value: '11', label: 'November' }, { value: '12', label: 'Desember' }
  ];
  const tahunList = Array.from({length: 5}, (_, i) => (new Date().getFullYear() - 2 + i).toString());

  // Form State Utama
  let seksi = $state('MUHAFADZOH');
  
  let inputHari = $state(new Date().getDate().toString());
  let inputBulan = $state((new Date().getMonth() + 1).toString());
  let inputTahun = $state(new Date().getFullYear().toString());
  let tanggalPembelian = $derived(`${inputTahun}-${inputBulan.padStart(2, '0')}-${inputHari.padStart(2, '0')}`);

  let namaToko = $state('');
  let namaKegiatan = $state('');
  
  let fileFotoBarang: File | null = $state(null);
  let fileFotoNota: File | null = $state(null);
  let isSubmitting = $state(false);

  // State Kamera
  let showCamera = $state(false);
  let cameraTarget: 'barang' | 'nota' | null = $state(null);
  let videoElement: HTMLVideoElement | undefined = $state();
  let stream: MediaStream | null = $state(null);

  // Cropper State
  let cropModalOpen = $state(false);
  let cropImageSrc = $state<string | null>(null);
  let cropTarget = $state<'barang' | 'nota' | null>(null);
  let cropperInstance: Cropper | null = null;

  // Popup State
  let showSuccessPopup = $state(false);
  let showErrorPopup = $state(false);
  let errorMessage = $state('');

  // Form State Item Dinamis
  let items = $state([
    { nama_barang: '', jumlah: 1, harga_satuan: 0, has_discount: false, diskon_nominal: 0 }
  ]);

  function setHariIni() {
    const now = new Date();
    inputHari = now.getDate().toString();
    inputBulan = (now.getMonth() + 1).toString();
    inputTahun = now.getFullYear().toString();
  }

  function tambahBarang() {
    items = [...items, { nama_barang: '', jumlah: 1, harga_satuan: 0, has_discount: false, diskon_nominal: 0 }];
  }

  function hapusBarang(index: number) {
    if (items.length > 1) {
      items = items.filter((_, i) => i !== index);
    }
  }

  async function startCamera(target: 'barang' | 'nota') {
    cameraTarget = target;
    showCamera = true;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
      if (videoElement) {
        videoElement.srcObject = stream;
      }
    } catch (err: any) {
      alert("Gagal mengakses kamera: " + err.message);
      closeCamera();
    }
  }

  function closeCamera() {
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
    }
    stream = null;
    showCamera = false;
    cameraTarget = null;
  }

  function capturePhoto() {
    if (!videoElement) return;
    const canvas = document.createElement('canvas');
    canvas.width = videoElement.videoWidth;
    canvas.height = videoElement.videoHeight;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
      canvas.toBlob((blob) => {
        if (blob) {
          const reader = new FileReader();
          reader.onload = (e) => {
            cropImageSrc = e.target?.result as string;
            cropTarget = cameraTarget;
            cropModalOpen = true;
            closeCamera();
          };
          reader.readAsDataURL(blob);
        } else {
          closeCamera();
        }
      }, 'image/jpeg', 1.0);
    }
  }

  function handleFileSelect(e: Event, target: 'barang' | 'nota') {
    const input = e.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      cropImageSrc = ev.target?.result as string;
      cropTarget = target;
      cropModalOpen = true;
      input.value = '';
    };
    reader.readAsDataURL(file);
  }

  function setupCropper(node: HTMLImageElement) {
    cropperInstance = new Cropper(node, {
      aspectRatio: 1,
      viewMode: 1,
      dragMode: 'move',
      autoCropArea: 0.9,
      restore: false,
      guides: true,
      center: true,
      highlight: false,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
    });
    return {
      destroy() {
        if (cropperInstance) {
          cropperInstance.destroy();
          cropperInstance = null;
        }
      }
    };
  }

  function saveCrop() {
    if (!cropperInstance || !cropTarget) return;
    
    cropperInstance.getCroppedCanvas({
      width: 800,
      height: 800,
      fillColor: '#fff',
    }).toBlob((blob: Blob | null) => {
      if (!blob) return;
      
      const file = new File([blob], `cropped_${Date.now()}.png`, { type: 'image/png' });
      
      if (cropTarget === 'barang') fileFotoBarang = file;
      if (cropTarget === 'nota') fileFotoNota = file;
      
      cropModalOpen = false;
      cropImageSrc = null;
      cropTarget = null;
    }, 'image/png', 0.85);
  }

  async function uploadFile(file: File, path: string) {
    const ext = file.name.split('.').pop();
    const fileName = `${path}/${Date.now()}.${ext}`;
    const { data, error } = await supabase.storage.from('nota-photos').upload(fileName, file);
    if (error) throw error;
    
    const { data: publicUrl } = supabase.storage.from('nota-photos').getPublicUrl(fileName);
    return publicUrl.publicUrl;
  }

  async function handleSubmit() {
    if (!namaToko) return alert('Nama Toko wajib diisi!');
    isSubmitting = true;

    try {
      let fotoBarangUrl = '';
      let fotoNotaUrl = '';

      if (fileFotoBarang) fotoBarangUrl = await uploadFile(fileFotoBarang, 'barang');
      if (fileFotoNota) fotoNotaUrl = await uploadFile(fileFotoNota, 'nota');

      const { data: transaction, error: txError } = await supabase
        .from('transactions')
        .insert({
          seksi,
          tanggal_pembelian: tanggalPembelian,
          nama_toko: namaToko,
          nama_kegiatan: namaKegiatan,
          foto_barang_url: fotoBarangUrl,
          foto_nota_url: fotoNotaUrl
        })
        .select()
        .single();

      if (txError) throw txError;

      const formattedItems = items.map(item => ({
        transaction_id: transaction.id,
        nama_barang: item.nama_barang,
        jumlah: item.jumlah,
        harga_satuan: item.harga_satuan,
        has_discount: item.has_discount,
        diskon_nominal: item.has_discount ? item.diskon_nominal : 0
      }));

      const { error: itemError } = await supabase.from('transaction_items').insert(formattedItems);
      if (itemError) throw itemError;

      showSuccessPopup = true;
      setTimeout(() => { showSuccessPopup = false; }, 3000);

      namaToko = '';
      namaKegiatan = '';
      fileFotoBarang = null;
      fileFotoNota = null;
      items = [{ nama_barang: '', jumlah: 1, harga_satuan: 0, has_discount: false, diskon_nominal: 0 }];

    } catch (err: any) {
      errorMessage = 'Gagal menyimpan: ' + err.message;
      showErrorPopup = true;
    } finally {
      isSubmitting = false;
    }
  }

</script>

<main class="max-w-2xl mx-auto p-4 md:p-6 bg-card text-card-foreground min-h-screen">
  <div class="flex flex-col sm:flex-row items-center sm:justify-start gap-4 mb-6">
    <img src="/logo_hmq.png" alt="Logo" class="w-16 h-16 object-contain" />
    <h1 class="text-2xl font-bold text-foreground text-center sm:text-left">BIROKRASI AL HIDAYAH HMQ</h1>
  </div>

  <form on:submit|preventDefault={handleSubmit} class="space-y-5">
    
    <div>
      <label class="block text-sm font-semibold mb-1">Seksi</label>
      <div class="relative">
        <select bind:value={seksi} class="w-full p-3 border-2 border-gray-200 rounded-xl bg-white appearance-none pr-10 focus:outline-none focus:ring-4 focus:ring-primary/20 focus:border-primary font-bold text-gray-800 transition-all cursor-pointer shadow-sm hover:border-gray-300">
          {#each daftarSeksi as s}
            <option value={s}>{s}</option>
          {/each}
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
        <button type="button" on:click={setHariIni} class="px-4 py-3 bg-primary/10 text-primary rounded-xl text-sm font-bold whitespace-nowrap hover:bg-primary/20 transition-colors hidden sm:block shadow-sm">Hari Ini</button>
      </div>
      <button type="button" on:click={setHariIni} class="w-full mt-3 px-4 py-3 bg-primary/10 text-primary rounded-xl text-sm font-bold whitespace-nowrap hover:bg-primary/20 transition-colors sm:hidden shadow-sm">Pilih Hari Ini</button>
    </div>

    <div>
      <label class="block text-sm font-semibold mb-1">Nama Toko</label>
      <input type="text" bind:value={namaToko} placeholder="Masukkan nama toko" class="w-full p-2.5 border rounded-lg" required />
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-semibold mb-1">Foto Barang</label>
        <div class="flex gap-2">
          <label class="flex-1 cursor-pointer bg-white border p-2 rounded-lg text-sm text-center font-medium hover:bg-gray-50 text-muted-foreground flex items-center justify-center transition-colors">
            <input type="file" accept="image/*" on:change={(e) => handleFileSelect(e, 'barang')} class="hidden" />
            Pilih dari Galeri
          </label>
          <button type="button" on:click={() => startCamera('barang')} class="p-2 bg-primary/20 text-primary rounded-lg font-semibold hover:bg-primary/30 flex items-center justify-center aspect-square transition-colors" title="Kamera">
            <Camera class="w-5 h-5" />
          </button>
        </div>
        {#if fileFotoBarang}
          <p class="text-xs text-emerald-500 mt-1 font-medium truncate">Terpilih: {fileFotoBarang.name}</p>
        {/if}
      </div>
      <div>
        <label class="block text-sm font-semibold mb-1">Foto Nota</label>
        <div class="flex gap-2">
          <label class="flex-1 cursor-pointer bg-white border p-2 rounded-lg text-sm text-center font-medium hover:bg-gray-50 text-muted-foreground flex items-center justify-center transition-colors">
            <input type="file" accept="image/*" on:change={(e) => handleFileSelect(e, 'nota')} class="hidden" />
            Pilih dari Galeri
          </label>
          <button type="button" on:click={() => startCamera('nota')} class="p-2 bg-primary/20 text-primary rounded-lg font-semibold hover:bg-primary/30 flex items-center justify-center aspect-square transition-colors" title="Kamera">
            <Camera class="w-5 h-5" />
          </button>
        </div>
        {#if fileFotoNota}
          <p class="text-xs text-emerald-500 mt-1 font-medium truncate">Terpilih: {fileFotoNota.name}</p>
        {/if}
      </div>
    </div>

    <div>
      <label class="block text-sm font-semibold mb-1">Nama Kegiatan (Khusus Makanan/Minuman)</label>
      <input type="text" bind:value={namaKegiatan} placeholder="Opsional" class="w-full p-2.5 border rounded-lg" />
    </div>

    <hr class="my-6" />

    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="font-bold text-lg">Rincian Barang ({items.length} Jenis)</h2>
        <button type="button" on:click={tambahBarang} class="p-2 bg-primary text-white rounded-lg hover:bg-primary/90 transition-colors shadow-sm" title="Tambah Barang">
          <Plus class="w-5 h-5" />
        </button>
      </div>

      {#each items as item, index}
        <div class="p-4 border rounded-xl bg-white relative space-y-3 shadow-sm">
          <div class="flex justify-between items-center">
            <span class="font-semibold text-sm text-foreground">Barang #{index + 1}</span>
            {#if items.length > 1}
              <button type="button" on:click={() => hapusBarang(index)} class="text-red-500 hover:text-red-700 hover:bg-red-50 p-1.5 rounded-md transition-colors" title="Hapus Barang">
                <Trash2 class="w-4 h-4" />
              </button>
            {/if}
          </div>

          <div>
            <input type="text" bind:value={item.nama_barang} placeholder="Nama Barang" class="w-full p-2 border rounded-md text-sm" required />
          </div>

          <div class="grid grid-cols-2 gap-2">
            <div>
              <label class="block text-xs mb-1">Jumlah</label>
              <div class="flex items-center">
                <button type="button" class="px-2.5 py-1 border bg-card text-card-foreground rounded-l-md" on:click={() => item.jumlah = Math.max(1, item.jumlah - 1)}>-</button>
                <input type="number" bind:value={item.jumlah} min="1" class="w-full text-center border-y p-1 text-sm" />
                <button type="button" class="px-2.5 py-1 border bg-card text-card-foreground rounded-r-md" on:click={() => item.jumlah++}>+</button>
              </div>
            </div>

            <div>
              <label class="block text-xs mb-1">Harga Satuan (Rp)</label>
              <input
                type="text"
                value={item.harga_satuan === 0 ? '' : item.harga_satuan.toLocaleString('id-ID')}
                on:input={(e) => {
                  const val = e.currentTarget.value.replace(/\D/g, '');
                  item.harga_satuan = val ? parseInt(val, 10) : 0;
                }}
                placeholder="Rp 0"
                class="w-full p-1.5 border rounded-md text-sm"
                required
              />
            </div>
          </div>

          <div class="pt-2 p-3 bg-card text-card-foreground border border-border rounded-lg shadow-sm">
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
                  on:input={(e) => {
                    const val = e.currentTarget.value.replace(/\D/g, '');
                    item.diskon_nominal = val ? parseInt(val, 10) : 0;
                  }}
                  placeholder="Rp 0"
                  class="w-full p-1.5 border rounded-md text-sm"
                />
              </div>
            {/if}
          </div>
          <div class="text-right pt-2 border-t border-border mt-2">
            <span class="text-xs text-muted-foreground">Subtotal:</span>
            <span class="font-bold text-sm text-primary ml-1">
              Rp {((item.jumlah * item.harga_satuan) - (item.has_discount ? item.diskon_nominal : 0)).toLocaleString('id-ID')}
            </span>
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

    <button type="submit" disabled={isSubmitting} class="w-full py-3 bg-primary text-white font-bold rounded-xl shadow-lg hover:bg-primary/90 disabled:opacity-50">
      {isSubmitting ? 'Menyimpan...' : 'Simpan Data Pleno'}
    </button>
  </form>

  {#if showCamera}
    <div class="fixed inset-0 bg-black bg-opacity-80 z-50 flex flex-col justify-center items-center p-4">
      <div class="bg-card text-card-foreground rounded-xl p-4 w-full max-w-md shadow-2xl">
        <div class="flex justify-between items-center mb-4">
          <h3 class="font-bold text-lg text-foreground">Ambil Foto {cameraTarget === 'barang' ? 'Barang' : 'Nota'}</h3>
          <button type="button" on:click={closeCamera} class="text-red-500 font-bold hover:bg-red-50 px-3 py-1 rounded-lg">Tutup</button>
        </div>
        <div class="bg-black rounded-lg overflow-hidden aspect-[3/4] flex items-center justify-center mb-4 relative">
          <video bind:this={videoElement} autoplay playsinline class="w-full h-full object-cover"></video>
        </div>
        <button type="button" on:click={capturePhoto} class="w-full py-4 bg-primary text-white rounded-xl shadow-lg hover:bg-primary/90 flex justify-center items-center transition-transform active:scale-95">
          <span class="text-4xl">📸</span>
        </button>
      </div>
    </div>
  {/if}

  {#if cropModalOpen}
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/95 backdrop-blur-sm p-4" on:click={() => cropModalOpen = false}>
      <div class="relative w-full max-w-lg bg-card rounded-2xl shadow-2xl overflow-hidden flex flex-col h-[85vh] sm:h-[650px] border border-white/10" on:click={(e) => e.stopPropagation()}>
        <div class="p-4 border-b bg-muted/50 text-center font-bold">
          Potong Foto {cropTarget === 'barang' ? 'Barang' : 'Nota'}
        </div>
        
        <div class="flex-1 bg-black overflow-hidden relative flex items-center justify-center">
          {#if cropImageSrc}
            <img src={cropImageSrc} alt="Crop target" class="max-w-full max-h-full block object-contain" use:setupCropper />
          {/if}
        </div>

        <div class="p-4 border-t bg-muted/50 flex justify-end gap-3">
          <button type="button" class="px-4 py-2 border rounded-md hover:bg-muted font-medium transition-colors" on:click={() => { cropModalOpen = false; cropImageSrc = null; }}>Batal</button>
          <button type="button" class="px-6 py-2 bg-primary text-primary-foreground font-bold rounded-md hover:bg-primary/90 transition-colors" on:click={saveCrop}>
            Simpan Potongan
          </button>
        </div>
      </div>
    </div>
  {/if}

  {#if showSuccessPopup}
    <div class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-300" on:click={() => showSuccessPopup = false}>
      <div class="bg-white rounded-3xl shadow-2xl p-8 max-w-sm w-full text-center transform animate-in zoom-in-95 slide-in-from-bottom-4 duration-300" on:click={(e) => e.stopPropagation()}>
        <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-green-50 mb-6 border-[8px] border-green-100">
          <CheckCircle2 class="h-12 w-12 text-green-500" />
        </div>
        <h3 class="text-2xl font-extrabold text-gray-900 mb-2">Berhasil!</h3>
        <p class="text-gray-500 mb-8 font-medium">Data pleno berhasil disimpan dengan aman.</p>
        <button type="button" class="w-full py-3.5 px-4 bg-green-500 hover:bg-green-600 text-white text-lg font-bold rounded-2xl transition-all shadow-lg shadow-green-500/30 active:scale-95" on:click={() => showSuccessPopup = false}>
          Selesai
        </button>
      </div>
    </div>
  {/if}

  {#if showErrorPopup}
    <div class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-300" on:click={() => showErrorPopup = false}>
      <div class="bg-white rounded-3xl shadow-2xl p-8 max-w-sm w-full text-center transform animate-in zoom-in-95 slide-in-from-bottom-4 duration-300" on:click={(e) => e.stopPropagation()}>
        <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-red-50 mb-6 border-[8px] border-red-100">
          <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-red-500"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        </div>
        <h3 class="text-2xl font-extrabold text-gray-900 mb-2">Oops, Gagal!</h3>
        <p class="text-gray-500 mb-8 font-medium">{errorMessage}</p>
        <button type="button" class="w-full py-3.5 px-4 bg-red-500 hover:bg-red-600 text-white text-lg font-bold rounded-2xl transition-all shadow-lg shadow-red-500/30 active:scale-95" on:click={() => showErrorPopup = false}>
          Tutup
        </button>
      </div>
    </div>
  {/if}
</main>
