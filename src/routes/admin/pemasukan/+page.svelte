<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { Button } from '$lib/components/ui/button';
  import { Plus, Trash2, ArrowLeft, RefreshCw, Camera, ImageIcon, Image } from 'lucide-svelte';
  import Cropper from 'cropperjs';
  import 'cropperjs/dist/cropper.css';

  let pemasukanList: any[] = $state([]);
  let loading = $state(true);

  // Opsi Dropdown Tanggal
  const hariList = Array.from({length: 31}, (_, i) => (i + 1).toString());
  const bulanList = [
    { value: '1', label: 'Januari' }, { value: '2', label: 'Februari' }, { value: '3', label: 'Maret' },
    { value: '4', label: 'April' }, { value: '5', label: 'Mei' }, { value: '6', label: 'Juni' },
    { value: '7', label: 'Juli' }, { value: '8', label: 'Agustus' }, { value: '9', label: 'September' },
    { value: '10', label: 'Oktober' }, { value: '11', label: 'November' }, { value: '12', label: 'Desember' }
  ];
  const tahunList = Array.from({length: 5}, (_, i) => (new Date().getFullYear() - 2 + i).toString());

  // Form State Tanggal
  let inputHari = $state(new Date().getDate().toString());
  let inputBulan = $state((new Date().getMonth() + 1).toString());
  let inputTahun = $state(new Date().getFullYear().toString());
  let tanggalPemasukan = $derived(`${inputTahun}-${inputBulan.padStart(2, '0')}-${inputHari.padStart(2, '0')}`);

  // Modal State
  let showModal = $state(false);
  let isSubmitting = $state(false);
  let inputForm = $state({
    no_kode: '',
    no_bukti: '',
    uraian: '',
    nominal: '' as string | number
  });

  // State File & Camera
  let fileFotoBukti: File | null = $state(null);
  let showCamera = $state(false);
  let videoElement: HTMLVideoElement | undefined = $state();
  let stream: MediaStream | null = $state(null);

  // Cropper State
  let cropModalOpen = $state(false);
  let cropImageSrc = $state<string | null>(null);
  let cropperInstance: Cropper | null = null;

  function setHariIni() {
    const now = new Date();
    inputHari = now.getDate().toString();
    inputBulan = (now.getMonth() + 1).toString();
    inputTahun = now.getFullYear().toString();
  }

  onMount(() => {
    fetchData();
  });

  async function fetchData() {
    loading = true;
    const { data, error } = await supabase
      .from('pemasukan')
      .select('*')
      .order('tanggal', { ascending: false });
    
    if (error) {
      console.warn("Tabel pemasukan belum dibuat atau error: ", error.message);
    } else {
      pemasukanList = data || [];
    }
    loading = false;
  }

  // --- CAMERA & UPLOAD LOGIC ---
  async function startCamera() {
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

  function handleFileSelect(e: Event) {
    const input = e.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      cropImageSrc = ev.target?.result as string;
      cropModalOpen = true;
      input.value = '';
    };
    reader.readAsDataURL(file);
  }

  function setupCropper(node: HTMLImageElement) {
    cropperInstance = new Cropper(node, {
      aspectRatio: NaN, // bebas
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
    if (!cropperInstance) return;
    
    cropperInstance.getCroppedCanvas({
      width: 800,
      height: 800,
      fillColor: '#fff',
    }).toBlob((blob: Blob | null) => {
      if (!blob) return;
      
      const file = new File([blob], `bukti_${Date.now()}.png`, { type: 'image/png' });
      fileFotoBukti = file;
      
      cropModalOpen = false;
      cropImageSrc = null;
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
  // --- END CAMERA & UPLOAD LOGIC ---

  async function simpanData() {
    const nominalNumber = Number(inputForm.nominal.toString().replace(/\./g, ''));
    if (!tanggalPemasukan || !inputForm.uraian || nominalNumber <= 0) {
      alert('Harap lengkapi tanggal, uraian, dan pastikan nominal lebih dari 0.');
      return;
    }

    isSubmitting = true;
    try {
      let fotoBuktiUrl = null;
      if (fileFotoBukti) {
        fotoBuktiUrl = await uploadFile(fileFotoBukti, 'pemasukan');
      }

      const { error } = await supabase.from('pemasukan').insert([{
        tanggal: tanggalPemasukan,
        no_kode: inputForm.no_kode || null,
        no_bukti: inputForm.no_bukti || null,
        uraian: inputForm.uraian,
        nominal: nominalNumber,
        foto_bukti_url: fotoBuktiUrl
      }]);

      if (error) throw error;

      showModal = false;
      inputForm = { no_kode: '', no_bukti: '', uraian: '', nominal: '' };
      fileFotoBukti = null;
      setHariIni();
      await fetchData();
    } catch (err: any) {
      alert('Gagal menyimpan pemasukan: ' + err.message);
    } finally {
      isSubmitting = false;
    }
  }

  async function hapusData(id: string) {
    if (!confirm('Yakin ingin menghapus data pemasukan ini?')) return;
    loading = true;
    const { error } = await supabase.from('pemasukan').delete().eq('id', id);
    if (error) alert('Gagal menghapus: ' + error.message);
    await fetchData();
  }

  function handleNominalInput(event: Event) {
    const input = event.target as HTMLInputElement;
    let val = input.value.replace(/\D/g, '');
    if (val) {
      inputForm.nominal = new Intl.NumberFormat('id-ID').format(Number(val));
    } else {
      inputForm.nominal = '';
    }
  }

  function formatRupiah(val: number) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(val);
  }
</script>

<div class="p-4 sm:p-8 w-full max-w-7xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
    <div>
      <div class="flex items-center gap-3 mb-2">
        <a href="/admin" class="p-2 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors text-gray-600">
          <ArrowLeft class="w-5 h-5" />
        </a>
        <h1 class="text-3xl font-bold tracking-tight text-emerald-700">Daftar Pemasukan</h1>
      </div>
      <p class="text-gray-500 pl-14">Kelola semua dana yang masuk (Debet).</p>
    </div>
    
    <div class="flex flex-wrap gap-3 w-full sm:w-auto mt-4 sm:mt-0">
      <Button onclick={() => showModal = true} class="bg-emerald-600 hover:bg-emerald-700 text-white shadow-md flex items-center gap-2">
        <Plus class="w-4 h-4" /> Tambah Pemasukan
      </Button>
    </div>
  </div>

  <!-- Table -->
  <div class="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm relative">
    {#if loading}
      <div class="absolute inset-0 z-10 bg-white/80 backdrop-blur-sm flex flex-col items-center justify-center text-primary gap-4">
        <RefreshCw class="w-10 h-10 animate-spin text-emerald-600" />
        <p class="font-medium text-emerald-700 animate-pulse">Memuat data pemasukan...</p>
      </div>
    {/if}

    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        <thead class="text-xs text-gray-600 uppercase bg-gray-100/80 sticky top-0 z-10 shadow-sm backdrop-blur-md">
          <tr>
            <th class="px-4 py-4 w-12 text-center font-bold border-r border-gray-200">No</th>
            <th class="px-4 py-4 font-bold border-r border-gray-200">Tanggal</th>
            <th class="px-4 py-4 font-bold border-r border-gray-200">No. Kode</th>
            <th class="px-4 py-4 font-bold border-r border-gray-200">No. Bukti</th>
            <th class="px-4 py-4 font-bold border-r border-gray-200 w-1/3">Uraian / Keterangan</th>
            <th class="px-4 py-4 font-bold border-r border-gray-200 text-right">Nominal</th>
            <th class="px-4 py-4 font-bold text-center">Aksi</th>
          </tr>
        </thead>
        <tbody>
          {#if !loading && pemasukanList.length === 0}
            <tr>
              <td colspan="7" class="text-center py-12 text-gray-500 italic">
                Belum ada data pemasukan. Silakan klik tombol "Tambah Pemasukan" di atas.
              </td>
            </tr>
          {:else}
            {#each pemasukanList as p, i}
              <tr class="border-b hover:bg-emerald-50/30 transition-colors group">
                <td class="px-4 py-3 text-center border-r border-gray-200 text-gray-500">{i + 1}</td>
                <td class="px-4 py-3 border-r border-gray-200 font-medium text-gray-900">{new Date(p.tanggal).toLocaleDateString('id-ID', {day: 'numeric', month: 'long', year: 'numeric'})}</td>
                <td class="px-4 py-3 border-r border-gray-200 text-gray-600">{p.no_kode || '-'}</td>
                <td class="px-4 py-3 border-r border-gray-200 text-gray-600">
                  <div class="flex flex-col gap-1">
                    <span>{p.no_bukti || '-'}</span>
                    {#if p.foto_bukti_url}
                      <a href={p.foto_bukti_url} target="_blank" class="text-xs text-blue-500 hover:underline flex items-center gap-1">
                        <Image class="w-3 h-3"/> Lihat Foto
                      </a>
                    {/if}
                  </div>
                </td>
                <td class="px-4 py-3 border-r border-gray-200 text-gray-700">{p.uraian}</td>
                <td class="px-4 py-3 border-r border-gray-200 text-right font-bold text-emerald-600">{formatRupiah(p.nominal)}</td>
                <td class="px-4 py-3 text-center">
                  <button type="button" onclick={() => hapusData(p.id)} class="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors inline-flex" title="Hapus Pemasukan">
                    <Trash2 class="w-4 h-4" />
                  </button>
                </td>
              </tr>
            {/each}
          {/if}
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Modal Form -->
{#if showModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4" onclick={() => showModal = false}>
    <div class="relative max-w-lg w-full bg-white rounded-2xl shadow-2xl overflow-hidden flex flex-col" onclick={(e) => e.stopPropagation()}>
      <div class="p-5 border-b bg-gray-50 flex justify-between items-center">
        <h3 class="font-bold text-lg text-emerald-700 flex items-center gap-2"><Plus class="w-5 h-5"/> Tambah Pemasukan Baru</h3>
      </div>
      <div class="p-5 space-y-4 max-h-[70vh] overflow-y-auto custom-scrollbar">
        <div>
          <label class="block text-sm font-semibold mb-1">Tanggal Pemasukan</label>
          <div class="grid grid-cols-[1fr_2fr_1fr_auto] gap-2">
            <div class="relative">
              <select bind:value={inputHari} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold outline-none focus:border-emerald-500 appearance-none bg-white">
                {#each hariList as h}
                  <option value={h}>{h}</option>
                {/each}
              </select>
            </div>
            <div class="relative">
              <select bind:value={inputBulan} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold outline-none focus:border-emerald-500 appearance-none bg-white">
                {#each bulanList as b}
                  <option value={b.value}>{b.label}</option>
                {/each}
              </select>
            </div>
            <div class="relative">
              <select bind:value={inputTahun} class="w-full p-2.5 border-2 rounded-xl text-sm font-bold outline-none focus:border-emerald-500 appearance-none bg-white">
                {#each tahunList as t}
                  <option value={t}>{t}</option>
                {/each}
              </select>
            </div>
            <button type="button" onclick={setHariIni} class="px-4 py-2 bg-emerald-50 text-emerald-700 rounded-xl text-sm font-bold hover:bg-emerald-100 transition-colors whitespace-nowrap">Hari Ini</button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold mb-1">No. Kode (Opsional)</label>
            <input type="text" bind:value={inputForm.no_kode} placeholder="Contoh: ULA-001" class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-emerald-500" />
          </div>
          <div>
            <label class="block text-sm font-semibold mb-1">No. Bukti (Opsional)</label>
            <input type="text" bind:value={inputForm.no_bukti} placeholder="Kosongkan jika tidak ada" class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-emerald-500" />
          </div>
        </div>
        <div>
          <label class="block text-sm font-semibold mb-1">Uraian / Keterangan</label>
          <textarea bind:value={inputForm.uraian} placeholder="Contoh: Dana Bos Tahap III" rows="2" class="w-full p-2.5 border-2 rounded-xl text-sm outline-none focus:border-emerald-500"></textarea>
        </div>
        <div>
          <label class="block text-sm font-semibold mb-1">Nominal (Rp)</label>
          <div class="relative">
            <span class="absolute left-3 top-2.5 font-bold text-gray-500">Rp</span>
            <input type="text" value={inputForm.nominal} oninput={handleNominalInput} placeholder="0" class="w-full pl-10 p-2.5 border-2 rounded-xl text-lg font-bold text-emerald-600 outline-none focus:border-emerald-500" />
          </div>
        </div>

        <hr class="my-2" />

        <!-- Upload Foto Bukti -->
        <div>
          <label class="block text-sm font-semibold mb-1">Foto Bukti (Opsional)</label>
          <div class="flex gap-2">
            <label class="flex-1 cursor-pointer bg-white border-2 border-dashed border-gray-300 p-2 rounded-xl text-sm text-center font-medium hover:bg-emerald-50 hover:border-emerald-400 text-gray-500 flex items-center justify-center transition-colors">
              <input type="file" accept="image/*" onchange={handleFileSelect} class="hidden" />
              <ImageIcon class="w-4 h-4 mr-2"/> Pilih File Gambar
            </label>
            <button type="button" onclick={startCamera} class="p-2 bg-emerald-100 text-emerald-700 rounded-xl font-semibold hover:bg-emerald-200 flex items-center justify-center aspect-square transition-colors" title="Kamera">
              <Camera class="w-5 h-5" />
            </button>
          </div>
          {#if fileFotoBukti}
            <div class="mt-2 p-2 bg-emerald-50 border border-emerald-200 rounded-lg flex justify-between items-center">
              <span class="text-xs text-emerald-700 font-medium truncate">Terpilih: {fileFotoBukti.name}</span>
              <button type="button" onclick={() => fileFotoBukti = null} class="text-red-500 hover:bg-red-50 p-1 rounded">
                <Trash2 class="w-3 h-3" />
              </button>
            </div>
          {/if}
        </div>

      </div>
      <div class="p-4 border-t flex justify-end gap-3 bg-gray-50">
        <Button variant="outline" onclick={() => showModal = false}>Batal</Button>
        <Button onclick={simpanData} disabled={isSubmitting} class="bg-emerald-600 hover:bg-emerald-700 text-white font-bold">
          {isSubmitting ? 'Menyimpan...' : 'Simpan Pemasukan'}
        </Button>
      </div>
    </div>
  </div>
{/if}

<!-- Camera View -->
{#if showCamera}
  <div class="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center">
    <!-- svelte-ignore a11y_media_has_caption -->
    <video bind:this={videoElement} autoplay playsinline class="max-h-[80vh] w-auto object-contain"></video>
    <div class="absolute bottom-8 flex gap-6">
      <button onclick={closeCamera} class="px-6 py-3 bg-white/20 text-white rounded-full font-bold backdrop-blur-md">Batal</button>
      <button onclick={capturePhoto} class="w-16 h-16 bg-white rounded-full border-4 border-gray-300 shadow-lg"></button>
    </div>
  </div>
{/if}

<!-- Crop Modal -->
{#if cropModalOpen && cropImageSrc}
  <div class="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center p-4">
    <div class="w-full max-w-2xl bg-white rounded-xl overflow-hidden flex flex-col h-[80vh]">
      <div class="p-4 border-b flex justify-between items-center bg-gray-50">
        <h3 class="font-bold">Sesuaikan Foto</h3>
        <button onclick={() => { cropModalOpen = false; cropImageSrc = null; }} class="text-gray-500 hover:text-black font-bold">Tutup</button>
      </div>
      <div class="flex-1 bg-black overflow-hidden">
        <img src={cropImageSrc} use:setupCropper alt="Crop Source" class="max-w-full h-auto block" />
      </div>
      <div class="p-4 border-t bg-gray-50 flex justify-end">
        <Button onclick={saveCrop} class="bg-emerald-600 hover:bg-emerald-700 text-white w-full sm:w-auto">
          Potong & Simpan
        </Button>
      </div>
    </div>
  </div>
{/if}
