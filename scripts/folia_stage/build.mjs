#!/usr/bin/env node
// Offline visualizer asset builder. Does not run GitHub Actions or modify the
// playback engine. Requires Node 24+ and an Internet connection for npm ci.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const project = path.resolve(__dirname, '../..');
const ref = '8e8009f76bbb37c932ea275f848a0a2a65171fe9';
const output = path.join(project, 'assets/web');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'md3music-lyrics-'));
let source = process.env.FOLIA_SOURCE_DIR
  ? path.resolve(process.env.FOLIA_SOURCE_DIR)
  : path.join(temp, 'folia-major');

function run(command, args, cwd = project) {
  const result = spawnSync(command, args,
    { cwd, stdio: 'inherit', shell: false });
  if (result.error || result.status !== 0) {
    throw new Error(command + ' failed with code ' + result.status);
  }
}

try {
  if (Number(process.versions.node.split('.')[0]) < 24) {
    throw new Error('The upstream project requires Node.js 24 or newer.');
  }
  if (!process.env.FOLIA_SOURCE_DIR) {
    run('git', ['init', source]);
    run('git', ['remote', 'add', 'origin',
      'https://github.com/chthollyphile/folia-major.git'], source);
    run('git', ['fetch', '--depth', '1', 'origin', ref], source);
    run('git', ['checkout', '--detach', 'FETCH_HEAD'], source);
  }
  if (!fs.existsSync(path.join(source, 'src/types.ts'))) {
    throw new Error('Folia source directory is missing src/types.ts');
  }
  const bridgeDir = path.join(source, 'src/md3music_bridge');
  fs.mkdirSync(bridgeDir, { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'entry.tsx'),
    path.join(bridgeDir, 'entry.tsx'));
  fs.copyFileSync(path.join(__dirname, 'index.html'),
    path.join(source, 'md3music-stage.html'));
  fs.copyFileSync(path.join(__dirname, 'vite.config.ts'),
    path.join(source, 'md3music-stage.vite.config.ts'));

  run('npm', ['ci', '--no-audit', '--no-fund'], source);
  run(process.execPath, [
    path.join(source, 'node_modules/vite/bin/vite.js'),
    'build', '--config', 'md3music-stage.vite.config.ts',
  ], source);

  const dist = path.join(source, 'dist-md3music-stage');
  const html = path.join(dist, 'md3music-stage.html');
  const js = path.join(dist, 'folia-stage.js');
  if (!fs.existsSync(html) || !fs.existsSync(js)) {
    throw new Error('No original-engine JS/HTML outputs. Do not enable the stage.');
  }

  // Make the manifest unavailable while assets are being updated.
  fs.writeFileSync(path.join(output, 'folia_stage_ready.json'),
    JSON.stringify({ available: false }, null, 2) + '\n');
  const outputFiles = [];
  // Flat assets are served by the loopback HTTP origin in the Android app.
  for (const d of fs.readdirSync(dist, { withFileTypes: true })) {
    if (!d.isFile()) {
      throw new Error('Unexpected nested Vite output: ' + d.name);
    }
    const targetName = d.name === 'md3music-stage.html'
      ? 'folia_stage.html' : d.name;
    fs.copyFileSync(path.join(dist, d.name), path.join(output, targetName));
    outputFiles.push(targetName);
  }
  fs.copyFileSync(path.join(source, 'LICENSE'),
    path.join(output, 'folia_stage_LICENSE.txt'));
  outputFiles.push('folia_stage_LICENSE.txt');
  const ready = {
    available: true,
    source: 'chthollyphile/folia-major',
    pinnedRevision: ref,
    entry: 'assets/web/folia_stage.html',
    files: outputFiles,
  };
  // Write the readiness flag last: a failed build cannot activate the viewer.
  fs.writeFileSync(path.join(output, 'folia_stage_ready.json'),
    JSON.stringify(ready, null, 2) + '\n');
  console.log('Original lyric engine staged at assets/web/ with ' +
    outputFiles.length + ' allowlisted assets.');
  console.log('Commit generated assets only after Android visual verification.');
} finally {
  if (!process.env.FOLIA_SOURCE_DIR) {
    fs.rmSync(temp, { recursive: true, force: true });
  }
}
