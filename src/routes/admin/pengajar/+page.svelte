<script lang="ts">
  import { onMount } from 'svelte';
  import ColumnFilter from '$lib/components/ColumnFilter.svelte';
  import Papa from 'papaparse';
  import { Search, RefreshCw, Users, FileDown, Settings, X, Settings2, Save } from 'lucide-svelte';
  import { Button } from '$lib/components/ui/button';
  import * as Table from '$lib/components/ui/table';

  // Constants
  const CLASSES = ['PENGAJAR PUTRA', 'PENGAJAR PUTRI'];

  const HEADERS = ['NAMA LENGKAP', 'ALAMAT', 'JABATAN', 'KELAS', 'BAGIAN', 'STATUS'];

  // State
  let studentsData = $state<any[]>([]);
  let isStudentsLoading = $state(false);
  let studentsError = $state('');
  let searchQuery = $state('');
  let columnFilters = $state<Record<string, string>>({});
  let sortColumn = $state('');
  let sortAsc = $state(true);
  let activeClass = $state(CLASSES[0]);
  let lastUpdated = $state<Date | null>(null);

  // Settings State
  let isSettingsOpen = $state(false);
  let isSavingSettings = $state(false);
  
  // App Config
  let appConfig = $state({
    baseUrl: 'https://docs.google.com/spreadsheets/d/e/2PACX-1vRJsVcfa7JzRWganlJ9kAhhcFXZdPs8e1nMhTzEWIPDP37lFUVtOQVT1mXMKhlEjONDN3eZ_d0ODzYM/pub',
    gids: { 
      'PENGAJAR PUTRA': '0',
      'PENGAJAR PUTRI': '735048396' 
    } as Record<string, string>
  });

  const filteredStudents = $derived(
    [...studentsData].filter(s => {
      // Hilangkan row kosong
      if (!s[HEADERS[0]]) return false;
      
      // Global search
      if (searchQuery) {
        const term = searchQuery.toLowerCase();
        const matchesGlobal = Object.values(s).some(val => String(val).toLowerCase().includes(term));
        if (!matchesGlobal) return false;
      }
      
      // Column filters
      for (const header of HEADERS) {
        if (columnFilters[header]) {
          const cellValue = String(s[header] || '').toLowerCase();
          const filterValue = columnFilters[header].toLowerCase();
          if (cellValue !== filterValue) return false;
        }
      }
      
      return true;
    }).sort((a, b) => {
      if (!sortColumn) return 0;
      const valA = String(a[sortColumn] || '').toLowerCase();
      const valB = String(b[sortColumn] || '').toLowerCase();
      if (valA < valB) return sortAsc ? -1 : 1;
      if (valA > valB) return sortAsc ? 1 : -1;
      return 0;
    })
  );

  
  const uniqueColumnValues = $derived(
    HEADERS.reduce((acc, header) => {
      acc[header] = [...new Set(studentsData.map(s => String(s[header] || '')).filter(Boolean))].sort();
      return acc;
    }, {} as Record<string, string[]>)
  );

  function toggleSort(header: string) {
    if (sortColumn === header) {
      sortAsc = !sortAsc;
    } else {
      sortColumn = header;
      sortAsc = true;
    }
  }

  onMount(() => {
    if (appConfig.baseUrl) {
      fetchStudentsForClass(activeClass);
    }
  });

  function selectClass(className: string) {
    activeClass = className;
    fetchStudentsForClass(className);
  }

  function saveSettings() {
    isSavingSettings = true;
    localStorage.setItem('hmqPengajarConfig', JSON.stringify(appConfig));
    setTimeout(() => {
      isSavingSettings = false;
      isSettingsOpen = false;
      fetchStudentsForClass(activeClass);
    }, 500);
  }

  async function fetchStudentsForClass(className: string) {
    if (!appConfig.baseUrl) {
      studentsError = 'URL Spreadsheet belum diatur. Silakan buka Pengaturan.';
      studentsData = [];
      return;
    }

    const gid = appConfig.gids[className];
    if (!gid) {
      studentsError = `GID untuk kelas ${className} belum diatur. Silakan masukkan GID di Pengaturan.`;
      studentsData = [];
      return;
    }

    isStudentsLoading = true;
    studentsError = '';
    studentsData = [];

    try {
      // Bersihkan parameter dari baseUrl jika user tidak sengaja mengcopynya
      let cleanBaseUrl = appConfig.baseUrl.split('?')[0]; 
      
      // Tambahkan output=csv, gid, dan parameter anti-cache
      const fetchUrl = `${cleanBaseUrl}?output=csv&single=true&gid=${gid}&t=${Date.now()}`;
      
      const response = await fetch(fetchUrl);
      if (!response.ok) throw new Error('Gagal memuat data. Pastikan link sudah di-Publish to Web sebagai CSV.');
      
      const csvText = await response.text();
      
      Papa.parse(csvText, {
        header: true,
        skipEmptyLines: true,
        complete: (results) => {
          studentsData = results.data as any[];
          isStudentsLoading = false;
          lastUpdated = new Date();
        },
        error: (err: any) => {
          studentsError = err.message;
          isStudentsLoading = false;
        }
      });
    } catch (err: any) {
      studentsError = err.message;
      isStudentsLoading = false;
    }
  }

  function exportCsv() {
    if (studentsData.length === 0) return;
    const csv = Papa.unparse(studentsData);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `Data_Pengajar_${activeClass.replace(/\s+/g, '_')}_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }
</script>

<div class="p-6 w-full max-w-[1600px] mx-auto space-y-6 flex flex-col h-full relative">
  <!-- Header -->
  <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 shrink-0">
    <div>
      <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-primary to-blue-600 flex items-center gap-3 pb-1">
        <Users class="w-8 h-8 text-primary" />
        Daftar Pengajar Madrasah
      </h1>
      <p class="text-muted-foreground flex items-center gap-2 mt-1">
        {#if appConfig.baseUrl}
          <span class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
          Sistem Tersinkronisasi
        {:else}
          <span class="w-2 h-2 rounded-full bg-red-500"></span>
          Menunggu Sinkronisasi
        {/if}
        
        {#if lastUpdated}
          <span class="text-xs text-gray-400 border-l border-gray-300 pl-2 ml-1">
            Update terakhir: {lastUpdated.toLocaleTimeString('id-ID')}
          </span>
        {/if}
      </p>
    </div>
    
    <div class="flex items-center gap-3">
      <Button variant="outline" onclick={() => isSettingsOpen = true} class="rounded-xl border-primary/20 text-primary hover:bg-primary/5">
        <Settings class="w-4 h-4 mr-2" />
        Pengaturan GID
      </Button>
      <Button variant="outline" onclick={() => fetchStudentsForClass(activeClass)} class="rounded-xl" disabled={isStudentsLoading || !appConfig.baseUrl}>
        <RefreshCw class="w-4 h-4 mr-2 {isStudentsLoading ? 'animate-spin' : ''}" />
        Refresh
      </Button>
      <Button class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white" onclick={exportCsv} disabled={studentsData.length === 0}>
        <FileDown class="w-4 h-4 mr-2" />
        Export CSV
      </Button>
    </div>
  </div>

  <div class="flex h-[calc(100vh-140px)]">
    <!-- MAIN CONTENT -->
    <div class="flex-1 bg-white border border-gray-200 rounded-2xl shadow-sm flex flex-col overflow-hidden min-w-0">
      
      <!-- Toolbox / Pencarian -->
      <div class="p-4 border-b flex flex-col lg:flex-row justify-between items-center gap-4 bg-gray-50/30">
        <div class="flex flex-wrap items-center gap-3 w-full lg:w-auto">
          <div class="relative">
            <select 
              bind:value={activeClass} 
              onchange={(e) => selectClass(e.currentTarget.value)}
              class="appearance-none pl-11 pr-10 py-2.5 bg-gradient-to-b from-white to-gray-50 border border-gray-300 rounded-xl text-sm font-bold text-gray-800 focus:ring-4 focus:ring-primary/20 outline-none shadow-md cursor-pointer hover:border-primary/50 transition-all hover:shadow-lg"
            >
              {#each CLASSES as className}
                <option value={className}>{className} {!appConfig.gids[className] ? '(⚠️ Belum Diatur)' : ''}</option>
              {/each}
            </select>
            <Settings2 class="absolute left-3.5 top-3 h-4 w-4 text-primary" />
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="absolute right-3.5 top-3 text-primary pointer-events-none"><path d="m6 9 6 6 6-6"/></svg>
          </div>
          <div class="text-sm font-medium text-gray-500 bg-white px-3 py-1.5 rounded-lg border shadow-sm">
            Total: <span class="text-primary font-bold">{filteredStudents.length}</span> Pengajar
          </div>
        </div>

        <div class="relative w-full sm:w-80">
          <Search class="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <input 
            type="text" 
            bind:value={searchQuery}
            placeholder="Cari nama, jabatan, alamat..." 
            class="pl-9 w-full p-2 bg-white border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary/30 outline-none transition-all shadow-sm"
          />
        </div>
      </div>

      <!-- Tabel -->
      <div class="flex-1 overflow-auto custom-scrollbar relative">
        {#if isStudentsLoading}
          <div class="absolute inset-0 z-10 bg-white/80 backdrop-blur-sm flex flex-col items-center justify-center text-primary gap-4">
            <RefreshCw class="w-10 h-10 animate-spin" />
            <p class="font-medium animate-pulse">Memuat data {activeClass}...</p>
          </div>
        {/if}

        {#if studentsError}
          <div class="absolute inset-0 z-10 flex flex-col items-center justify-center p-8 text-center bg-gray-50">
            <div class="w-16 h-16 bg-red-100 text-red-600 rounded-full flex items-center justify-center mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Oops, Gagal Memuat Data!</h3>
            <p class="text-gray-600 max-w-md">{studentsError}</p>
            <Button class="mt-6 rounded-xl" onclick={() => isSettingsOpen = true}>Buka Pengaturan</Button>
          </div>
        {:else if !isStudentsLoading && filteredStudents.length === 0}
           <div class="absolute inset-0 flex flex-col items-center justify-center text-gray-500">
             <p>Tidak ada data ditemukan di kelas ini.</p>
           </div>
        {/if}

        <table class="w-full text-sm text-left">
          <thead class="text-xs text-gray-600 uppercase bg-gray-100/80 sticky top-0 z-10 shadow-sm backdrop-blur-md">
            <tr>
              <th class="px-4 py-4 w-12 text-center font-bold border-r border-gray-200">No</th>
              {#each HEADERS as header}
                <th 
                  class="px-4 py-3 font-bold whitespace-nowrap border-r border-gray-200 text-center cursor-pointer hover:bg-gray-200 transition-colors"
                  onclick={() => toggleSort(header)}
                  title="Klik untuk mengurutkan (Sort)"
                >
                  <div class="flex items-center justify-center gap-1">
                    {header}
                    {#if sortColumn === header}
                      <span class="text-primary text-[10px]">{sortAsc ? '▲' : '▼'}</span>
                    {/if}
                  </div>
                </th>
              {/each}
            </tr>
            <!-- Row for Column Filters -->
            <tr class="bg-gray-50/90 border-b border-gray-200">
              <td class="border-r border-gray-200"></td>
              {#each HEADERS as header}
                <td class="px-2 py-1.5 border-r border-gray-200">
                  <ColumnFilter 
                    options={uniqueColumnValues[header] || []} 
                    bind:value={columnFilters[header]} 
                    placeholder="Semua" 
                  />
                </td>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each filteredStudents as student, i}
              <tr class="border-b border-gray-100 hover:bg-primary/5 transition-colors {i % 2 === 0 ? 'bg-white' : 'bg-gray-50/30'} group">
                <td class="px-4 py-3 text-center text-gray-400 font-medium border-r border-gray-100">{i + 1}</td>
                {#each HEADERS as header}
                  <td class="px-4 py-3 font-medium text-gray-700 whitespace-nowrap border-r border-gray-100 {header.includes('NAMA') || header === 'ALAMAT' ? 'text-left' : 'text-center'}">
                    {#if header === 'JABATAN' && student[header]}
                       <span class="px-2.5 py-1 bg-blue-100 text-blue-800 rounded-full text-[11px] font-bold tracking-wide">
                         {student[header]}
                       </span>
                    {:else if header === 'STATUS' && student[header]}
                       <span class="px-2.5 py-1 rounded-full text-[11px] font-bold tracking-wide {student[header].toUpperCase().includes('BARU') ? 'bg-emerald-100 text-emerald-800' : 'bg-gray-200 text-gray-700'}">
                         {student[header]}
                       </span>
                    {:else}
                       {student[header] || '-'}
                    {/if}
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- SLIDING SIDE PANEL PENGATURAN -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  {#if isSettingsOpen}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[100] flex justify-end transition-opacity duration-300" onclick={() => isSettingsOpen = false}>
      <div 
        class="w-full max-w-md bg-white h-full shadow-2xl flex flex-col transform transition-transform duration-300 animate-in slide-in-from-right"
        onclick={(e) => e.stopPropagation()}
      >
        <div class="p-6 border-b bg-gray-50 flex justify-between items-center">
          <div>
            <h2 class="text-xl font-bold flex items-center gap-2">
              <Settings class="w-5 h-5 text-primary" /> Pengaturan GID
            </h2>
            <p class="text-xs text-muted-foreground mt-1">Sambungkan Spreadsheet dengan Halaman Ini</p>
          </div>
          <button class="p-2 hover:bg-gray-200 rounded-full transition-colors" onclick={() => isSettingsOpen = false}>
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
          <!-- Panduan -->
          <div class="bg-blue-50 text-blue-900 p-4 rounded-xl text-sm leading-relaxed border border-blue-100">
            <b>1.</b> Buka Google Sheet Abang, klik <b>File > Share > Publish to web</b>.<br>
            <b>2.</b> Pilih "Entire Document" & "CSV", lalu copy linknya kesini.<br>
            <b>3.</b> Untuk GID, lihat angka di ujung link browser saat Abang membuka tab kelas tersebut (contoh: <code>...#gid=787389808</code>, maka GID nya <code>787389808</code>).
          </div>

          <!-- Base URL Input -->
          <div>
            <label class="block text-sm font-bold text-gray-700 mb-2">1. Link "Publish to Web" (CSV) Utama</label>
            <textarea 
              bind:value={appConfig.baseUrl} 
              rows="3"
              placeholder="https://docs.google.com/spreadsheets/d/e/2PACX-.../pub" 
              class="w-full p-3 bg-gray-50 border border-gray-300 rounded-xl text-xs focus:ring-2 focus:ring-primary/50 outline-none"
            ></textarea>
          </div>

          <!-- GID Inputs -->
          <div>
            <label class="block text-sm font-bold text-gray-700 mb-3">2. Masukkan Kode GID Tiap Kelas</label>
            <div class="space-y-3">
              {#each CLASSES as className}
                <div class="flex items-center gap-3">
                  <div class="w-1/2 text-xs font-semibold text-gray-600 bg-gray-100 p-2.5 rounded-lg border">{className}</div>
                  <input 
                    type="text" 
                    bind:value={appConfig.gids[className]} 
                    placeholder="Contoh: 787389808"
                    class="w-1/2 p-2 bg-white border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary/50 outline-none"
                  />
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t bg-gray-50 flex gap-3">
          <Button variant="outline" class="flex-1 rounded-xl" onclick={() => isSettingsOpen = false}>Batal</Button>
          <Button class="flex-1 rounded-xl bg-primary hover:bg-primary/90 text-white" onclick={saveSettings} disabled={isSavingSettings}>
            {#if isSavingSettings}
              <RefreshCw class="w-4 h-4 mr-2 animate-spin" /> Menyimpan...
            {:else}
              <Save class="w-4 h-4 mr-2" /> Simpan & Muat Ulang
            {/if}
          </Button>
        </div>
      </div>
    </div>
  {/if}
</div>
