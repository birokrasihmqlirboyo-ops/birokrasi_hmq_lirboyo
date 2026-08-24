<script lang="ts">
  import { onMount } from 'svelte';
  import '../app.css';

  let { children } = $props();

  // PWA Install State
  let deferredPrompt = $state<any>(null);
  let showInstallPrompt = $state(false);

  onMount(() => {
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

  async function handleInstallApp() {
    if (deferredPrompt) {
      showInstallPrompt = false;
      deferredPrompt.prompt();
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

{@render children()}
