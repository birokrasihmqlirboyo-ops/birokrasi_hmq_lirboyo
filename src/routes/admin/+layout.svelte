<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';
  import { LayoutDashboard, BookText, Users, GraduationCap, LogOut, Menu } from 'lucide-svelte';

  let isLoggingOut = $state(false);
  let isMobileMenuOpen = $state(false);
  
  // PWA Install State
  let deferredPrompt = $state<any>(null);
  let showInstallPrompt = $state(false);

  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      goto('/login');
    }

    // PWA Install Prompt Logic
    const checkAndShowPrompt = (e: any) => {
      deferredPrompt = e;
      const lastDismissed = localStorage.getItem('installPromptDismissedAt');
      if (lastDismissed) {
        const timeSinceDismissed = Date.now() - parseInt(lastDismissed, 10);
        if (timeSinceDismissed < 10 * 60 * 1000) {
          return; // Skip showing if within 10 minutes
        }
      }
      setTimeout(() => { showInstallPrompt = true; }, 2000);
    };

    if (window.deferredPWAInstallPrompt) {
      checkAndShowPrompt(window.deferredPWAInstallPrompt);
    }
    
    window.addEventListener('pwa-prompt-ready', () => {
      if (window.deferredPWAInstallPrompt) {
        checkAndShowPrompt(window.deferredPWAInstallPrompt);
      }
    });
  });

  async function handleLogout() {
    isLoggingOut = true;
    await supabase.auth.signOut();
    goto('/login');
  }

  async function handleInstallApp() {
    if (deferredPrompt) {
      showInstallPrompt = false;
      deferredPrompt.prompt(); // Memanggil popup bawaan Google (Wajib dari aturan browser)
      const { outcome } = await deferredPrompt.userChoice;
      if (outcome !== 'accepted') {
        localStorage.setItem('installPromptDismissedAt', Date.now().toString());
      }
      deferredPrompt = null;
      window.deferredPWAInstallPrompt = null;
    }
  }

  function handleDismissInstall() {
    showInstallPrompt = false;
    localStorage.setItem('installPromptDismissedAt', Date.now().toString());
  }
</script>

<!-- PWA Install Modal -->
{#if showInstallPrompt}
  <div class="fixed inset-0 bg-black/60 z-[100] flex items-center justify-center p-4 backdrop-blur-sm transition-all duration-300">
    <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-sm text-center">
      <div class="w-16 h-16 bg-blue-50/50 rounded-2xl flex items-center justify-center mx-auto mb-4 border border-blue-100">
        <img src="/logo_hmq.png" alt="Logo" class="w-10 h-10 object-contain" />
      </div>
      <h2 class="text-xl font-bold text-gray-900 mb-2">Instal Aplikasi HMQ?</h2>
      <p class="text-sm text-gray-500 mb-6">Apakah ingin di instal di HP biar gampang diakses dan nggak usah repot buka browser terus?</p>
      
      <div class="space-y-3">
        <button class="w-full bg-primary hover:bg-primary/90 text-white font-medium py-3 rounded-xl transition-colors shadow-sm" onclick={handleInstallApp}>
          Ya, Instal Sekarang
        </button>
        <button class="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-3 rounded-xl transition-colors" onclick={handleDismissInstall}>
          Nanti Saja
        </button>
      </div>
    </div>
  </div>
{/if}

<div class="flex h-screen bg-[#f8fafc] overflow-hidden">
  <!-- Mobile Sidebar Overlay -->
  {#if isMobileMenuOpen}
    <div class="fixed inset-0 bg-black/50 z-40 md:hidden" onclick={() => isMobileMenuOpen = false}></div>
  {/if}

  <!-- Sidebar -->
  <aside class="w-72 bg-white border-r border-gray-200 flex flex-col h-full shrink-0 shadow-sm z-50 fixed md:relative transition-transform duration-300 {isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}">
    <div class="p-6 border-b border-gray-100 flex items-center justify-between gap-4">
      <div class="flex items-center gap-4">
        <img src="/logo_hmq.png" alt="Logo" class="w-10 h-10 object-contain" />
        <div>
          <h1 class="font-bold text-lg leading-tight text-foreground">BIROKRASI HMQ</h1>
          <p class="text-xs text-muted-foreground">Admin Portal</p>
        </div>
      </div>
      <button class="md:hidden p-2 text-gray-500 hover:bg-gray-100 rounded-lg" onclick={() => isMobileMenuOpen = false}>
        <Menu class="w-5 h-5" />
      </button>
    </div>

    <nav class="flex-1 overflow-y-auto p-4 space-y-1.5 custom-scrollbar">
      <a href="/admin" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname === '/admin' ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <LayoutDashboard class="w-5 h-5" />
        Dashboard & Rekapan
      </a>
      <a href="/admin/bku" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname.startsWith('/admin/bku') ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <BookText class="w-5 h-5" />
        Buku Kas Umum (BKU)
      </a>
      <a href="/admin/bpp" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname.startsWith('/admin/bpp') ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <BookText class="w-5 h-5" />
        Buku Pembantu Pajak (BPP)
      </a>
      <a href="/admin/pemasukan" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname.startsWith('/admin/pemasukan') ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
        Pemasukan (Dana Masuk)
      </a>
      <a href="/admin/pengajar" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname.startsWith('/admin/pengajar') ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <Users class="w-5 h-5" />
        Daftar Pengajar
      </a>
      <a href="/admin/siswi" onclick={() => isMobileMenuOpen = false} class="flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium { $page.url.pathname.startsWith('/admin/siswi') ? 'bg-primary/10 text-primary' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900' }">
        <GraduationCap class="w-5 h-5" />
        Daftar Siswi
      </a>
    </nav>

    <div class="p-4 border-t border-gray-100">
      <button type="button" class="flex items-center gap-3 px-4 py-3 w-full rounded-xl transition-all font-medium text-red-600 hover:bg-red-50" onclick={handleLogout} disabled={isLoggingOut}>
        <LogOut class="w-5 h-5" />
        {isLoggingOut ? 'Keluar...' : 'Logout'}
      </button>
    </div>
  </aside>

  <!-- Main Content -->
  <main class="flex-1 h-full overflow-y-auto relative w-full">
    <!-- Mobile Header -->
    <div class="md:hidden bg-white border-b border-gray-200 p-4 sticky top-0 z-30 flex items-center gap-4 shadow-sm">
      <button class="p-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200" onclick={() => isMobileMenuOpen = true}>
        <Menu class="w-5 h-5" />
      </button>
      <h1 class="font-bold text-gray-800">BIROKRASI HMQ</h1>
    </div>
    
    <slot />
  </main>
</div>
