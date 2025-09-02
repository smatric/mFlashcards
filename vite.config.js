import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  plugins: [svelte()],
  define: {
    global: 'globalThis',
  },
  base: '/',
  server: {
    host: true,
    port: 3000,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
})