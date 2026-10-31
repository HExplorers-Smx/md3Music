import path from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { traditionalLocalePlugin } from './dev/i18n/traditionalLocalePlugin.mjs';
import { icuFoliaDataPlugin } from './dev/icuFolia/icuFoliaDataPlugin.mjs';
import { nebbiaStrokesPlugin } from './dev/nebbia/nebbiaStrokesPlugin.mjs';

const root = process.cwd();
export default defineConfig({
  root,
  base: './',
  publicDir: false,
  plugins: [traditionalLocalePlugin(), icuFoliaDataPlugin(), nebbiaStrokesPlugin(), react()],
  define: {
    __COMMIT_HASH__: JSON.stringify('md3music-visualizer'),
    __GIT_BRANCH__: JSON.stringify('md3music'),
    __BUILD_REPO__: JSON.stringify('chthollyphile/folia-major'),
    __BUILD_COMMIT__: JSON.stringify('8e8009f76bbb37c932ea275f848a0a2a65171fe9'),
    __BUILD_KIND__: JSON.stringify('web'),
    __BUILD_HOST__: JSON.stringify('android-embedded'),
    __APP_VERSION__: JSON.stringify('0.7'),
    __APP_VERSION_LABEL__: JSON.stringify('md3music-stage'),
    __APP_RELEASE_CHANNEL__: JSON.stringify('embedded'),
    __DOCKER_STACK_VERSION__: JSON.stringify(''),
  },
  resolve: {
    alias: { '@': path.resolve(root, 'src') },
  },
  build: {
    outDir: path.resolve(root, 'dist-md3music-stage'),
    emptyOutDir: true,
    cssCodeSplit: false,
    sourcemap: false,
    rollupOptions: {
      input: path.resolve(root, 'md3music-stage.html'),
      output: {
        entryFileNames: 'folia-stage.js',
        chunkFileNames: 'folia-stage-[name]-[hash].js',
        assetFileNames: 'folia-stage-[name][extname]',
      },
    },
  },
});
