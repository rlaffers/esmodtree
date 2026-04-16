import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import dts from 'vite-plugin-dts'

export default defineConfig({
  plugins: [dts({ tsconfigPath: './tsconfig.json' })],
  resolve: {
    alias: { '~': resolve(import.meta.dirname, 'src') },
  },
  build: {
    target: 'node22',
    outDir: 'dist',
    minify: false,
    lib: {
      entry: {
        index: resolve(import.meta.dirname, 'src/index.ts'),
        cli: resolve(import.meta.dirname, 'src/cli.ts'),
      },
      formats: ['es'],
    },
    rolldownOptions: {
      external: [/^[^.~\/]/, /^node:/],
      output: {
        banner: chunk => (chunk.name === 'cli' ? '#!/usr/bin/env node\n' : ''),
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
      },
    },
  },
})
