<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { Input } from '$lib/components/ui/input';
  import { Button } from '$lib/components/ui/button';
  import * as Card from '$lib/components/ui/card';
  import { goto } from '$app/navigation';

  let email = $state('');
  let password = $state('');
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

<div class="flex items-center justify-center min-h-screen bg-muted p-4">
  <Card.Root class="w-full max-w-md">
    <Card.Header>
      <Card.Title>Admin Login</Card.Title>
      <Card.Description>Masuk untuk mengelola data Pleno</Card.Description>
    </Card.Header>
    <Card.Content>
      <form onsubmit={(e) => { e.preventDefault(); handleLogin(); }} class="space-y-4">
        <div class="space-y-2">
          <label for="email" class="text-sm font-medium">Email</label>
          <Input id="email" type="email" bind:value={email} required placeholder="admin@example.com" />
        </div>
        <div class="space-y-2">
          <label for="password" class="text-sm font-medium">Password</label>
          <Input id="password" type="password" bind:value={password} required />
        </div>
        {#if errorMsg}
          <p class="text-sm text-red-500 font-medium">{errorMsg}</p>
        {/if}
        <Button type="submit" class="w-full" disabled={loading}>
          {loading ? 'Masuk...' : 'Login'}
        </Button>
      </form>
    </Card.Content>
  </Card.Root>
</div>
