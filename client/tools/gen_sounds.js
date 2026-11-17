// 程序合成麻将音效（16-bit PCM WAV，22050Hz 单声道）
// 生成：assets/sounds/{discard,peng,gang,hu,draw,win}.wav
const fs = require('fs');
const path = require('path');

const SR = 22050;
const outDir = path.join(
  'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/assets/sounds',
);
fs.mkdirSync(outDir, { recursive: true });

// 生成一段音频采样
function synth({ duration, gen }) {
  const n = Math.round(SR * duration);
  const samples = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const progress = i / n;
    samples[i] = gen(t, progress);
  }
  return samples;
}

// 简单低通平滑（去毛刺）
function smooth(samples, passes = 2) {
  for (let p = 0; p < passes; p++) {
    for (let i = 1; i < samples.length - 1; i++) {
      samples[i] = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4;
    }
  }
  return samples;
}

const sounds = {
  // 打牌：短促「嗒」
  discard: synth({
    duration: 0.06,
    gen: (t) => Math.sin(t * 2 * Math.PI * 900) * Math.exp(-t * 60) * 0.9,
  }),
  // 摸牌：更轻的「嗒」
  draw: synth({
    duration: 0.05,
    gen: (t) => Math.sin(t * 2 * Math.PI * 600) * Math.exp(-t * 80) * 0.5,
  }),
  // 碰：两声清脆
  peng: synth({
    duration: 0.16,
    gen: (t) =>
      (t < 0.07
        ? Math.sin(t * 2 * Math.PI * 880) * Math.exp(-t * 40)
        : Math.sin(t * 2 * Math.PI * 1100) * Math.exp(-(t - 0.07) * 40)) * 0.85,
  }),
  // 杠：低沉重击
  gang: synth({
    duration: 0.22,
    gen: (t, p) =>
      (Math.sin(t * 2 * Math.PI * 320) * 0.7 +
        Math.sin(t * 2 * Math.PI * 160) * 0.5) *
      Math.exp(-p * 6),
  }),
  // 胡：上行三连音
  hu: synth({
    duration: 0.5,
    gen: (t, p) => {
      const freq = p < 0.33 ? 523 : p < 0.66 ? 659 : 784;
      return Math.sin(t * 2 * Math.PI * freq) * Math.exp(-((p * 3) % 1) * 3) * 0.8;
    },
  }),
  // 流局：下行低落音
  liuju: synth({
    duration: 0.45,
    gen: (t, p) => Math.sin(t * 2 * Math.PI * (600 - p * 350)) * Math.exp(-p * 3) * 0.7,
  }),
    // 骰子：五连快点击
  dice: synth({
    duration: 0.5,
    gen: (t, p) => {
      const seg = (p * 5) % 1;
      return seg < 0.15
          ? Math.sin(t * 2 * Math.PI * 1400) * Math.exp(-seg * 30) * 0.6
          : 0;
    },
  }),
  // 上听：双音清脆提示
  ting: synth({
    duration: 0.25,
    gen: (t, p) =>
      (Math.sin(t * 2 * Math.PI * 880) + Math.sin(t * 2 * Math.PI * 1320) * 0.6) *
          Math.exp(-p * 4) *
          0.7,
  }),
    // 过自摸：轻柔下滑音
  pass: synth({
    duration: 0.2,
    gen: (t, p) => Math.sin(t * 2 * Math.PI * (700 - p * 300)) * Math.exp(-p * 5) * 0.6,
  }),
  // 查叫：低沉双音
  qiao: synth({
    duration: 0.3,
    gen: (t, p) =>
      (Math.sin(t * 2 * Math.PI * 500) + Math.sin(t * 2 * Math.PI * 750) * 0.5) *
          Math.exp(-p * 4) *
          0.7,
  }),
    // 大胡（封顶）：庆祝琶音
  win: synth({
    duration: 0.8,
    gen: (t, p) => {
      const notes = [523, 659, 784, 1047];
      const idx = Math.min(3, Math.floor(p * 4));
      const seg = (p * 4) % 1;
      return (
        Math.sin(t * 2 * Math.PI * notes[idx]) * Math.exp(-seg * 4) * 0.85 +
        (idx === 3 ? Math.sin(t * 2 * Math.PI * 1319) * Math.exp(-seg * 4) * 0.4 : 0)
      );
    },
  }),
};

for (const [name, samples] of Object.entries(sounds)) {
  smooth(samples, 2);
  // 转换 16-bit PCM
  const pcm = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    pcm.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(SR, 24);
  header.writeUInt32LE(SR * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  fs.writeFileSync(path.join(outDir, `${name}.wav`), Buffer.concat([header, pcm]));
  console.log(`${name}.wav  ${(pcm.length / 2 / SR).toFixed(2)}s`);
}
console.log('音效生成完成 →', outDir);
