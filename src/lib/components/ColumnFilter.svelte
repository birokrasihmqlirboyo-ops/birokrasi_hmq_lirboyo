<script lang="ts">
  import { Search, ChevronDown, Check } from 'lucide-svelte';

  let { 
    options = [], 
    value = $bindable(), 
    placeholder = 'Semua' 
  } = $props<{
    options?: string[];
    value?: string;
    placeholder?: string;
  }>();

  let isOpen = $state(false);
  let searchQuery = $state('');
  let containerRef: HTMLDivElement | undefined = $state();
  let inputRef: HTMLInputElement | undefined = $state();

  const filteredOptions = $derived(options.filter((opt: string) => 
    opt.toLowerCase().includes(searchQuery.toLowerCase())
  ));

  function toggleOpen() {
    isOpen = !isOpen;
    if (isOpen) {
      searchQuery = '';
      setTimeout(() => {
        if (inputRef) inputRef.focus();
      }, 50);
    }
  }

  function selectOption(opt: string) {
    value = opt;
    isOpen = false;
  }

  // Handle click outside to close
  function handleClickOutside(event: MouseEvent) {
    if (isOpen && containerRef && !containerRef.contains(event.target as Node)) {
      isOpen = false;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<div class="relative" bind:this={containerRef}>
  <!-- Trigger Button -->
  <button 
    type="button" 
    class="w-full flex items-center justify-between p-1.5 text-[11px] border border-gray-300 rounded font-normal normal-case bg-white cursor-pointer hover:border-primary/50 transition-colors focus:ring-2 focus:ring-primary/20 outline-none"
    on:click|stopPropagation={toggleOpen}
  >
    <span class="truncate max-w-[120px] text-gray-700 font-medium">
      {value || placeholder}
    </span>
    <ChevronDown class="w-3 h-3 text-gray-400 shrink-0 ml-1 {isOpen ? 'rotate-180 text-primary' : ''} transition-transform" />
  </button>

  <!-- Popover Dropdown -->
  {#if isOpen}
    <div class="absolute left-0 top-full mt-1 w-48 bg-white border border-gray-200 rounded-xl shadow-xl z-50 overflow-hidden transform origin-top animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Search Input inside Dropdown -->
      <div class="p-2 border-b bg-gray-50/50">
        <div class="relative">
          <Search class="absolute left-2 top-2 h-3 w-3 text-muted-foreground" />
          <input 
            bind:this={inputRef}
            type="text" 
            bind:value={searchQuery}
            placeholder="Cari..." 
            class="w-full pl-7 pr-2 py-1.5 text-[11px] bg-white border border-gray-300 rounded-md focus:ring-1 focus:ring-primary outline-none"
            on:click|stopPropagation
          />
        </div>
      </div>

      <!-- Scrollable List -->
      <div class="max-h-48 overflow-y-auto custom-scrollbar p-1">
        <!-- Option: Semua -->
        <button 
          type="button"
          class="w-full flex items-center justify-between px-3 py-1.5 text-left text-[11px] rounded-md hover:bg-primary/10 hover:text-primary transition-colors {!value ? 'bg-primary/5 text-primary font-bold' : 'text-gray-700'}"
          on:click|stopPropagation={() => selectOption('')}
        >
          Semua
          {#if !value}
            <Check class="w-3 h-3" />
          {/if}
        </button>

        <!-- Dynamic Options -->
        {#if filteredOptions.length === 0}
          <div class="px-3 py-2 text-center text-[10px] text-gray-500 italic">
            Tidak ada yang cocok.
          </div>
        {:else}
          {#each filteredOptions as opt}
            <button 
              type="button"
              class="w-full flex items-center justify-between px-3 py-1.5 text-left text-[11px] rounded-md hover:bg-primary/10 hover:text-primary transition-colors {value === opt ? 'bg-primary/5 text-primary font-bold' : 'text-gray-700'}"
              on:click|stopPropagation={() => selectOption(opt)}
            >
              <span class="truncate">{opt}</span>
              {#if value === opt}
                <Check class="w-3 h-3 shrink-0" />
              {/if}
            </button>
          {/each}
        {/if}
      </div>
    </div>
  {/if}
</div>
