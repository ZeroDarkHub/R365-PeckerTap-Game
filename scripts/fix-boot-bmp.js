#!/usr/bin/env node
const fs = require('fs');

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error('usage: fix-boot-bmp.js input.bmp output.bmp');
  process.exit(2);
}
const bmp = fs.readFileSync(input);
if (bmp.toString('ascii', 0, 2) !== 'BM') throw new Error('not a BMP');
const pixelOffset = bmp.readUInt32LE(10);
const width = bmp.readInt32LE(18);
const signedHeight = bmp.readInt32LE(22);
const bits = bmp.readUInt16LE(28);
if (width !== 640 || Math.abs(signedHeight) !== 480 || bits !== 24) {
  throw new Error(`expected 640x480 24-bit BMP, got ${width}x${signedHeight} ${bits}-bit`);
}
if (signedHeight > 0) {
  fs.copyFileSync(input, output);
  process.exit(0);
}
const height = -signedHeight;
const stride = Math.ceil((width * 3) / 4) * 4;
const out = Buffer.from(bmp);
out.writeInt32LE(height, 22);
for (let y = 0; y < height; y++) {
  const src = pixelOffset + y * stride;
  const dst = pixelOffset + (height - 1 - y) * stride;
  bmp.copy(out, dst, src, src + stride);
}
fs.writeFileSync(output, out);
