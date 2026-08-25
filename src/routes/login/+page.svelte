<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { Input } from '$lib/components/ui/input';
  import { Button } from '$lib/components/ui/button';
  import { goto } from '$app/navigation';
  import { Landmark, Lock, Mail, ArrowRight, Loader2, Eye, EyeOff } from 'lucide-svelte';
  import { fade, fly } from 'svelte/transition';

  let email = $state('');
  let password = $state('');
  let showPassword = $state(false);
  let errorMsg = $state('');
  let loading = $state(false);

  async function handleLogin() {
    loading = true;
    errorMsg = '';
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      errorMsg = error.message;
      loading = false;
    } else {
      goto('/admin');
    }
  }
</script>

<div class="min-h-screen relative flex items-center justify-center overflow-hidden bg-emerald-50/50 selection:bg-emerald-200">
  <!-- Background Decorations -->
  <div class="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none">
    <div class="absolute -top-[20%] -left-[10%] w-[60%] h-[60%] rounded-full bg-emerald-200/40 blur-[100px] animate-pulse" style="animation-duration: 8s;"></div>
    <div class="absolute top-[50%] -right-[10%] w-[50%] h-[60%] rounded-full bg-emerald-300/30 blur-[120px] animate-pulse" style="animation-duration: 12s; animation-delay: 2s;"></div>
  </div>

  <div class="relative z-10 w-full max-w-[420px] p-6" in:fly={{ y: 30, duration: 800, delay: 100 }}>
    <div class="bg-white/70 backdrop-blur-2xl p-8 sm:p-10 rounded-[2rem] shadow-[0_8px_40px_rgb(0,0,0,0.04)] border border-white">
      
      <div class="flex flex-col items-center mb-10 text-center">
        <div class="w-24 h-24 rounded-2xl flex items-center justify-center shadow-lg shadow-emerald-500/20 mb-5 bg-white transform transition-transform hover:scale-105 hover:rotate-3 duration-300 overflow-hidden border border-gray-100 p-2">
          <img src="/logo_hmq.png" alt="Logo HMQ" class="w-full h-full object-contain" />
        </div>
        <h1 class="text-3xl font-extrabold tracking-tight text-gray-900 mb-2">Birokrasi HMQ</h1>
        <p class="text-gray-500 text-sm font-medium">Selamat datang! Silakan masuk ke panel admin.</p>
      </div>

      <form onsubmit={(e) => { e.preventDefault(); handleLogin(); }} class="space-y-5">
        <div class="space-y-2">
          <label for="email" class="text-[11px] font-bold text-gray-600 uppercase tracking-wider ml-1">Alamat Email</label>
          <div class="relative group">
            <Mail class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-emerald-500 transition-colors" />
            <Input id="email" type="email" bind:value={email} required placeholder="admin@hmqlirboyo.com" class="pl-12 py-6 bg-white/60 border-gray-200 focus:bg-white transition-colors rounded-xl text-base shadow-sm hover:border-gray-300 focus:border-emerald-500 focus:ring-emerald-500/20" />
          </div>
        </div>
        
        <div class="space-y-2">
          <label for="password" class="text-[11px] font-bold text-gray-600 uppercase tracking-wider ml-1">Kata Sandi</label>
          <div class="relative group">
            <Lock class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-emerald-500 transition-colors" />
            <Input id="password" type={showPassword ? "text" : "password"} bind:value={password} required placeholder="••••••••" class="pl-12 pr-12 py-6 bg-white/60 border-gray-200 focus:bg-white transition-colors rounded-xl text-base shadow-sm hover:border-gray-300 focus:border-emerald-500 focus:ring-emerald-500/20 {showPassword ? '' : 'font-mono tracking-widest'}" />
            <button type="button" class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-emerald-600 focus:outline-none transition-colors" onclick={() => showPassword = !showPassword} tabindex="-1">
              {#if showPassword}
                <EyeOff class="w-5 h-5" />
              {:else}
                <Eye class="w-5 h-5" />
              {/if}
            </button>
          </div>
        </div>

        {#if errorMsg}
          <div class="p-3 bg-red-50 border border-red-100 rounded-xl flex items-center gap-3 text-red-600 text-sm font-medium" in:fade>
            <div class="p-1 bg-red-100 rounded-lg shrink-0">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" /></svg>
            </div>
            <p>{errorMsg}</p>
          </div>
        {/if}

        <Button type="submit" class="w-full mt-2 py-6 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-700 hover:to-emerald-800 text-white shadow-lg shadow-emerald-600/25 transition-all font-bold text-base group relative overflow-hidden" disabled={loading}>
          <!-- Shine effect -->
          <div class="absolute inset-0 -translate-x-full group-hover:animate-[shimmer_1.5s_infinite] bg-gradient-to-r from-transparent via-white/20 to-transparent"></div>
          
          {#if loading}
            <Loader2 class="w-5 h-5 animate-spin mr-2" /> Memproses...
          {:else}
            Masuk ke Dashboard
            <ArrowRight class="w-5 h-5 ml-2 group-hover:translate-x-1.5 transition-transform duration-300" />
          {/if}
        </Button>
      </form>

      <div class="mt-8 pt-6 border-t border-gray-100 text-center">
        <p class="text-[11px] text-gray-400 font-semibold tracking-wide uppercase">&copy; {new Date().getFullYear()} Birokrasi HMQ Lirboyo</p>
      </div>
    </div>
  </div>
</div>

<style>
  /* Hide the native eye icon in Edge/Windows */
  :global(input[type="password"]::-ms-reveal),
  :global(input[type="password"]::-ms-clear) {
    display: none;
  }

  @keyframes shimmer {
    100% {
      transform: translateX(100%);
    }
  }
</style>
