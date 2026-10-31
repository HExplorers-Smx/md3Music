import React, { useEffect, useMemo, useState } from 'react';
import { Buffer } from 'buffer';
import { createRoot } from 'react-dom/client';
import { motionValue } from 'framer-motion';
import type { AudioBands, Line, Theme, VisualizerMode } from '../types';
import VisualizerRenderer from '../components/visualizer/VisualizerRenderer';
import '../index.css';
import '../i18n/config';

(globalThis as typeof globalThis & { Buffer: typeof Buffer }).Buffer = Buffer;

type SceneMessage = {
  type: 'scene';
  mode: string;
  lines: Line[];
  palette: Partial<Theme>;
  songTitle?: string;
  songArtist?: string;
  songAlbum?: string;
  coverUrl?: string;
};
type ClockMessage = { type: 'clock'; positionMs: number; playing: boolean };
type AudioMessage = { type: 'audio'; bands: number[] };
type StageMessage = SceneMessage | ClockMessage | AudioMessage;
type StageChannel = { postMessage: (message: string) => void };

declare global {
  interface Window {
    MD3StageChannel?: StageChannel;
    md3StageReceive?: (raw: string) => void;
  }
}

const STAGES = new Set([
  'classic', 'cadenza', 'cappella', 'claddagh', 'diorama',
  'nebbia', 'fume', 'hanabi', 'lumiere', 'machi', 'monet',
  'partita', 'pendolo', 'sonnet', 'still', 'tempera', 'tilt',
]);

const defaultTheme: Theme = {
  name: 'Local player',
  backgroundColor: '#141216',
  primaryColor: '#f5f0f8',
  accentColor: '#d6bbf2',
  secondaryColor: '#9c86b6',
  fontStyle: 'sans',
  animationIntensity: 'normal',
};

function notify(type: string, additional: Record<string, unknown> = {}) {
  window.MD3StageChannel?.postMessage(JSON.stringify({ type, ...additional }));
}

function Host() {
  const [mode, setMode] = useState<VisualizerMode>('classic');
  const [lines, setLines] = useState<Line[]>([]);
  const [theme, setTheme] = useState<Theme>(defaultTheme);
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(true);
  const [metadata, setMetadata] = useState({
    title: '', artist: '', album: '', cover: '' });
  const clock = useMemo(() => motionValue(0), []);
  const power = useMemo(() => motionValue(0), []);
  const bands = useMemo<AudioBands>(() => ({
    bass: motionValue(0),
    lowMid: motionValue(0),
    mid: motionValue(0),
    vocal: motionValue(0),
    treble: motionValue(0),
  }), []);
  const linesRef = React.useRef<Line[]>([]);
  const indexRef = React.useRef(0);
  const authority = React.useRef({ seconds: 0, at: 0, playing: false });

  useEffect(() => {
    window.md3StageReceive = (raw) => {
      let msg: StageMessage;
      try { msg = JSON.parse(raw) as StageMessage; }
      catch { return; }
      if (msg.type === 'scene') {
        const nextMode = STAGES.has(msg.mode) ? msg.mode : 'classic';
        const updated = msg.lines.map((line) => ({
          ...line,
          fullText: line.fullText ?? '',
          words: Array.isArray(line.words) ? line.words : [],
        }));
        linesRef.current = updated;
        indexRef.current = 0;
        setLines(updated);
        setIndex(0);
        setMode(nextMode as VisualizerMode);
        setTheme({ ...defaultTheme, ...msg.palette });
        setMetadata({
          title: msg.songTitle ?? '',
          artist: msg.songArtist ?? '',
          album: msg.songAlbum ?? '',
          cover: msg.coverUrl ?? '',
        });
      }
      if (msg.type === 'clock') {
        const pos = Number.isFinite(msg.positionMs)
          ? Math.max(0, msg.positionMs / 1000) : 0;
        const sampledAt = performance.now();
        authority.current = { seconds: pos, at: sampledAt,
          playing: msg.playing };
        clock.set(pos);
        setPaused(!msg.playing);
        const source = linesRef.current;
        if (source.length) {
          let lo = 0, hi = source.length;
          while (lo < hi) {
            const mid = (lo + hi) >>> 1;
            if (source[mid].startTime <= pos) lo = mid + 1;
            else hi = mid;
          }
          const active = Math.max(0, lo - 1);
          if (active !== indexRef.current) {
            indexRef.current = active;
            setIndex(active);
          }
        }
      }
      if (msg.type === 'audio' && Array.isArray(msg.bands)) {
        const values = msg.bands.map(v => Number.isFinite(v)
          ? Math.max(0, Math.min(1, v)) : 0);
        bands.bass.set(values[0] ?? 0);
        bands.lowMid.set(values[1] ?? 0);
        bands.mid.set(values[2] ?? 0);
        bands.vocal.set(values[3] ?? 0);
        bands.treble.set(values[4] ?? 0);
        power.set(values.reduce((a, b) => a + b, 0) / Math.max(1, values.length));
      }
    };
    notify('ready');
    let frame = 0;
    const draw = (now: number) => {
      const state = authority.current;
      if (state.playing) {
        clock.set(state.seconds + Math.max(0, now - state.at) / 1000);
      }
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(frame);
      delete window.md3StageReceive;
    };
  }, [clock, power, bands]);

  return (
    <VisualizerRenderer
      mode={mode}
      lines={lines}
      currentLineIndex={index}
      currentTime={clock}
      audioPower={power}
      audioBands={bands}
      paused={paused}
      songTitle={metadata.title}
      songArtist={metadata.artist}
      songAlbum={metadata.album}
      coverUrl={metadata.cover || null}
      theme={theme}
      subtitleTheme={theme}
      showText
      showHarmonySubtitle={false}
      isPlayerChromeHidden
      background={{ mode: 'common' }}
      animateStyleSwitch
      onLyricLineSeek={(seconds: number) => {
        if (Number.isFinite(seconds) && seconds >= 0) {
          notify('seek', { positionMs: Math.round(seconds * 1000) });
        }
      }}
    />
  );
}

window.addEventListener('error', e => {
  notify('error', { message: String(e.message).slice(0, 200) });
});

const mount = document.getElementById('root');
if (!mount) throw new Error('No stage mount element');
createRoot(mount).render(<Host />);
