// COMPOSED RENDERS, not Roblox Studio captures.
import { writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const data = JSON.parse(readFileSync(join(root, 'src/shared/GameData.json'), 'utf8'));
const rarityMap = new Map(data.rarities.map((rarity) => [rarity.name, rarity]));
const brainrotMap = new Map(data.brainrots.map((brainrot) => [brainrot.id, brainrot]));
const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
const mix = (a, b, amount) => a.map((value, index) => Math.round(value + (b[index] - value) * amount));
const rgb = (values) => [Math.round(values[0] * 255), Math.round(values[1] * 255), Math.round(values[2] * 255)];
const shade = (values, amount) => values.map((value) => clamp(Math.round(value * 255 * amount), 0, 255));
const alpha = (values, opacity) => [...values, opacity];

class Canvas {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.pixels = Buffer.alloc(width * height * 3);
  }

  blend(x, y, color, opacity = 1) {
    x = Math.floor(x);
    y = Math.floor(y);
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    const offset = (y * this.width + x) * 3;
    if (opacity >= 1) {
      this.pixels[offset] = color[0];
      this.pixels[offset + 1] = color[1];
      this.pixels[offset + 2] = color[2];
      return;
    }
    for (let channel = 0; channel < 3; channel += 1) {
      this.pixels[offset + channel] = Math.round(this.pixels[offset + channel] * (1 - opacity) + color[channel] * opacity);
    }
  }

  fillRect(x, y, width, height, color, opacity = 1) {
    const left = Math.floor(x);
    const top = Math.floor(y);
    const right = Math.ceil(x + width);
    const bottom = Math.ceil(y + height);
    for (let py = top; py < bottom; py += 1) {
      for (let px = left; px < right; px += 1) this.blend(px, py, color, opacity);
    }
  }

  gradientRect(x, y, width, height, topColor, bottomColor, opacity = 1) {
    for (let py = Math.floor(y); py < Math.ceil(y + height); py += 1) {
      const amount = clamp((py - y) / Math.max(1, height), 0, 1);
      this.fillRect(x, py, width, 1, mix(topColor, bottomColor, amount), opacity);
    }
  }

  polygon(points, color, opacity = 1) {
    const minimumY = Math.floor(Math.min(...points.map((point) => point[1])));
    const maximumY = Math.ceil(Math.max(...points.map((point) => point[1])));
    for (let y = minimumY; y <= maximumY; y += 1) {
      const intersections = [];
      for (let index = 0; index < points.length; index += 1) {
        const current = points[index];
        const next = points[(index + 1) % points.length];
        if ((current[1] <= y && next[1] > y) || (next[1] <= y && current[1] > y)) {
          intersections.push(current[0] + ((y - current[1]) * (next[0] - current[0])) / (next[1] - current[1]));
        }
      }
      intersections.sort((a, b) => a - b);
      for (let index = 0; index + 1 < intersections.length; index += 2) {
        this.fillRect(Math.ceil(intersections[index]), y, Math.floor(intersections[index + 1]) - Math.ceil(intersections[index]) + 1, 1, color, opacity);
      }
    }
  }

  ellipse(x, y, radiusX, radiusY, color, opacity = 1) {
    for (let py = Math.floor(y - radiusY); py <= Math.ceil(y + radiusY); py += 1) {
      for (let px = Math.floor(x - radiusX); px <= Math.ceil(x + radiusX); px += 1) {
        const dx = (px - x) / radiusX;
        const dy = (py - y) / radiusY;
        if (dx * dx + dy * dy <= 1) this.blend(px, py, color, opacity);
      }
    }
  }

  line(x1, y1, x2, y2, color, opacity = 1) {
    x1 = Math.floor(x1);
    y1 = Math.floor(y1);
    x2 = Math.floor(x2);
    y2 = Math.floor(y2);
    const dx = Math.abs(x2 - x1);
    const dy = -Math.abs(y2 - y1);
    const sx = x1 < x2 ? 1 : -1;
    const sy = y1 < y2 ? 1 : -1;
    let error = dx + dy;
    while (true) {
      this.blend(x1, y1, color, opacity);
      if (x1 === x2 && y1 === y2) break;
      const twice = 2 * error;
      if (twice >= dy) { error += dy; x1 += sx; }
      if (twice <= dx) { error += dx; y1 += sy; }
    }
  }

  roundedRect(x, y, width, height, radius, color, opacity = 1) {
    radius = Math.min(radius, width / 2, height / 2);
    this.fillRect(x + radius, y, width - radius * 2, height, color, opacity);
    this.fillRect(x, y + radius, radius, height - radius * 2, color, opacity);
    this.fillRect(x + width - radius, y + radius, radius, height - radius * 2, color, opacity);
    this.ellipse(x + radius, y + radius, radius, radius, color, opacity);
    this.ellipse(x + width - radius, y + radius, radius, radius, color, opacity);
    this.ellipse(x + radius, y + height - radius, radius, radius, color, opacity);
    this.ellipse(x + width - radius, y + height - radius, radius, radius, color, opacity);
  }

  textWidth(value, size) {
    const scale = Math.max(1, Math.round(size / 7));
    return Math.max(0, String(value).length * 6 * scale - scale);
  }

  text(value, x, y, size, color, align = 'left', opacity = 1) {
    const text = String(value).toUpperCase();
    const scale = Math.max(1, Math.round(size / 7));
    const width = this.textWidth(text, size);
    let cursor = align === 'center' ? x - width / 2 : align === 'right' ? x - width : x;
    for (const character of text) {
      const glyph = FONT[character] ?? FONT['?'];
      for (let row = 0; row < 7; row += 1) {
        for (let column = 0; column < 5; column += 1) {
          if (glyph[row] & (1 << (4 - column))) this.fillRect(cursor + column * scale, y + row * scale, scale, scale, color, opacity);
        }
      }
      cursor += 6 * scale;
    }
    return y + 7 * scale;
  }

  outlineText(value, x, y, size, color, align = 'left', opacity = 1) {
    const offsets = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]];
    for (const [dx, dy] of offsets) this.text(value, x + dx, y + dy, size, color, align, opacity * 0.7);
    this.text(value, x, y, size, color, align, opacity);
  }

  textWrap(value, x, y, width, size, color, lineHeight = size * 1.5, align = 'left') {
    const words = String(value).toUpperCase().split(/\s+/);
    let line = '';
    let cursorY = y;
    for (const word of words) {
      const candidate = line ? `${line} ${word}` : word;
      if (line && this.textWidth(candidate, size) > width) {
        this.text(line, x, cursorY, size, color, align);
        cursorY += lineHeight;
        line = word;
      } else {
        line = candidate;
      }
    }
    if (line) {
      this.text(line, x, cursorY, size, color, align);
      cursorY += lineHeight;
    }
    return cursorY;
  }
}

const FONT = {
  A: [14, 17, 17, 31, 17, 17, 17], B: [30, 17, 17, 30, 17, 17, 30], C: [14, 17, 16, 16, 16, 17, 14],
  D: [30, 17, 17, 17, 17, 17, 30], E: [31, 16, 16, 30, 16, 16, 31], F: [31, 16, 16, 30, 16, 16, 16],
  G: [14, 17, 16, 23, 17, 17, 15], H: [17, 17, 17, 31, 17, 17, 17], I: [14, 4, 4, 4, 4, 4, 14],
  J: [7, 2, 2, 2, 2, 18, 12], K: [17, 18, 20, 24, 20, 18, 17], L: [16, 16, 16, 16, 16, 16, 31],
  M: [17, 27, 21, 21, 17, 17, 17], N: [17, 25, 21, 19, 17, 17, 17], O: [14, 17, 17, 17, 17, 17, 14],
  P: [30, 17, 17, 30, 16, 16, 16], Q: [14, 17, 17, 17, 21, 18, 13], R: [30, 17, 17, 30, 20, 18, 17],
  S: [15, 16, 16, 14, 1, 1, 30], T: [31, 4, 4, 4, 4, 4, 4], U: [17, 17, 17, 17, 17, 17, 14],
  V: [17, 17, 17, 17, 17, 10, 4], W: [17, 17, 17, 21, 21, 27, 17], X: [17, 17, 10, 4, 10, 17, 17],
  Y: [17, 17, 10, 4, 4, 4, 4], Z: [31, 1, 2, 4, 8, 16, 31],
  0: [14, 17, 19, 21, 25, 17, 14], 1: [4, 12, 4, 4, 4, 4, 14], 2: [14, 17, 1, 2, 4, 8, 31],
  3: [30, 1, 1, 14, 1, 1, 30], 4: [2, 6, 10, 18, 31, 2, 2], 5: [31, 16, 16, 30, 1, 1, 30],
  6: [14, 16, 16, 30, 17, 17, 14], 7: [31, 1, 2, 4, 8, 8, 8], 8: [14, 17, 17, 14, 17, 17, 14],
  9: [14, 17, 17, 15, 1, 1, 14], '.': [0, 0, 0, 0, 0, 6, 6], ':': [0, 6, 6, 0, 6, 6, 0],
  '$': [4, 15, 20, 14, 5, 30, 4], '/': [1, 2, 2, 4, 8, 8, 16], '+': [0, 4, 4, 31, 4, 4, 0],
  '-': [0, 0, 0, 31, 0, 0, 0], '%': [25, 25, 2, 4, 8, 19, 19], '!': [4, 4, 4, 4, 4, 0, 4],
  '?': [14, 17, 1, 2, 4, 0, 4], '(': [2, 4, 8, 8, 8, 4, 2], ')': [8, 4, 2, 2, 2, 4, 8],
  ',': [0, 0, 0, 0, 6, 6, 12], "'": [4, 4, 8, 0, 0, 0, 0], '>': [8, 4, 2, 1, 2, 4, 8], ' ': [0, 0, 0, 0, 0, 0, 0]
};

const crcTable = Array.from({ length: 256 }, (_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit += 1) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, body) {
  const name = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(body.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, body])));
  return Buffer.concat([length, name, body, checksum]);
}

function encodePng(canvas) {
  const stride = canvas.width * 3;
  const raw = Buffer.alloc((stride + 1) * canvas.height);
  for (let y = 0; y < canvas.height; y += 1) {
    const row = y * (stride + 1);
    raw[row] = 0;
    canvas.pixels.copy(raw, row + 1, y * stride, (y + 1) * stride);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(canvas.width, 0);
  header.writeUInt32BE(canvas.height, 4);
  header[8] = 8;
  header[9] = 2;
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', header),
    pngChunk('IDAT', deflateSync(raw, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0))
  ]);
}

function panel(canvas, x, y, width, height, fill = [25, 29, 56], border = [90, 104, 158], radius = 18, shadow = true) {
  if (shadow) canvas.roundedRect(x + 5, y + 8, width, height, radius, [6, 8, 20], 0.28);
  canvas.roundedRect(x, y, width, height, radius, fill, 0.96);
  canvas.roundedRect(x + 2, y + 2, width - 4, height - 4, Math.max(1, radius - 2), border, 0.48);
}

function hudButton(canvas, x, y, width, label, accent) {
  canvas.roundedRect(x + 2, y + 4, width, 44, 12, [5, 7, 18], 0.35);
  canvas.roundedRect(x, y, width, 44, 12, mix(accent, [24, 27, 52], 0.72));
  canvas.roundedRect(x, y, width, 4, 2, accent);
  canvas.text(label, x + width / 2, y + 14, 14, [239, 243, 255], 'center');
}

function statCard(canvas, x, y, width, label, value, accent, icon) {
  panel(canvas, x, y, width, 62, [26, 30, 59], mix(accent, [66, 72, 110], 0.7), 14, false);
  canvas.ellipse(x + 27, y + 31, 17, 17, accent);
  canvas.text(icon, x + 27, y + 23, 12, [18, 20, 35], 'center');
  canvas.text(label, x + 50, y + 11, 9, [166, 176, 213]);
  canvas.text(value, x + 50, y + 31, 15, [250, 252, 255]);
}

function drawHud(canvas, stats) {
  canvas.gradientRect(0, 0, 1280, 112, [17, 22, 48], [38, 29, 72]);
  canvas.fillRect(0, 108, 1280, 4, [255, 205, 65]);
  canvas.fillRect(0, 108, 640, 4, [62, 214, 255]);
  canvas.roundedRect(22, 19, 188, 73, 18, [55, 42, 112]);
  canvas.roundedRect(29, 26, 174, 59, 14, [83, 58, 151]);
  canvas.text('BRAINROT', 118, 37, 19, [255, 240, 126], 'center');
  canvas.text('BASE WARS', 118, 61, 15, [255, 255, 255], 'center');
  statCard(canvas, 220, 16, 168, 'CASH', stats.cash, [255, 204, 55], '$');
  statCard(canvas, 398, 16, 168, 'INCOME', stats.income, [70, 219, 173], '+');
  statCard(canvas, 576, 16, 168, 'REBIRTHS', stats.rebirth, [225, 102, 255], 'R');
  hudButton(canvas, 758, 21, 88, 'LOCK', [86, 132, 255]);
  hudButton(canvas, 856, 21, 96, 'SHOP', [255, 160, 53]);
  hudButton(canvas, 962, 21, 142, 'COLLECTION', [203, 87, 255]);
  hudButton(canvas, 1114, 21, 142, 'REBIRTH', [49, 211, 165]);
  canvas.roundedRect(354, 121, 572, 47, 14, [78, 35, 96], 0.95);
  canvas.roundedRect(361, 127, 558, 35, 11, [119, 55, 119], 0.94);
  canvas.polygon([[376, 144], [389, 132], [402, 144], [389, 157]], [255, 218, 74]);
  canvas.text('!', 389, 136, 12, [79, 41, 93], 'center');
  canvas.text('GOLDEN HOUR EVENT', 416, 135, 14, [255, 245, 189]);
  canvas.text('2X CASH  02:14', 900, 136, 11, [255, 226, 116], 'right');
}

function composedBadge(canvas) {
  canvas.roundedRect(1084, 690, 180, 20, 8, [9, 12, 27], 0.72);
  canvas.text('COMPOSED ILLUSTRATION', 1174, 695, 7, [199, 207, 230], 'center', 0.85);
}

const project = (x, y, z) => [640 + x * 3.55, 404 + z * 1.55 - y * 9];

function drawBrainrot(canvas, brainrot, x, groundY, scale = 13, mutation = 'None') {
  const color = mutation === 'None' ? rgb(brainrot.color) : rgb(data.mutations.find((item) => item.name === mutation).color);
  const width = brainrot.size[0] * scale;
  const totalHeight = brainrot.size[1] * scale;
  const headSize = width * 0.78;
  const bodyHeight = totalHeight * 0.48;
  const topY = groundY - totalHeight;
  canvas.ellipse(x, groundY + 3, width * 0.65, width * 0.18, [23, 39, 45], 0.3);
  if (mutation !== 'None') {
    canvas.ellipse(x, groundY - totalHeight * 0.52, width * 0.85, totalHeight * 0.62, color, 0.14);
    canvas.ellipse(x, groundY - totalHeight * 0.52, width * 0.66, totalHeight * 0.48, [255, 255, 255], 0.08);
  }
  canvas.roundedRect(x - width * 0.38, groundY - width * 0.31, width * 0.28, width * 0.31, 2, shade(color, 0.78));
  canvas.roundedRect(x + width * 0.1, groundY - width * 0.31, width * 0.28, width * 0.31, 2, shade(color, 0.78));
  canvas.roundedRect(x - width * 0.72, groundY - bodyHeight * 0.82, width * 0.3, bodyHeight * 0.75, 2, shade(color, 0.86));
  canvas.roundedRect(x + width * 0.42, groundY - bodyHeight * 0.82, width * 0.3, bodyHeight * 0.75, 2, shade(color, 0.86));
  canvas.roundedRect(x - width / 2, groundY - bodyHeight, width, bodyHeight, 3, color);
  canvas.fillRect(x - width / 2, groundY - bodyHeight, Math.max(2, width * 0.12), bodyHeight, [255, 255, 255], 0.13);
  canvas.roundedRect(x - headSize / 2, topY, headSize, headSize, 3, mix(color, [255, 255, 255], 0.08));
  const eyeY = topY + headSize * 0.32;
  const eyeWidth = Math.max(2, width * 0.12);
  canvas.fillRect(x - width * 0.23, eyeY, eyeWidth, eyeWidth * 1.15, [17, 18, 29]);
  canvas.fillRect(x + width * 0.09, eyeY, eyeWidth, eyeWidth * 1.15, [17, 18, 29]);
  canvas.fillRect(x - width * 0.2, eyeY + 1, Math.max(1, eyeWidth * 0.28), eyeWidth * 0.3, [255, 255, 255]);
  canvas.fillRect(x + width * 0.12, eyeY + 1, Math.max(1, eyeWidth * 0.28), eyeWidth * 0.3, [255, 255, 255]);
  canvas.fillRect(x - width * 0.14, topY + headSize * 0.68, width * 0.28, Math.max(2, headSize * 0.08), [67, 28, 39]);
  if (mutation !== 'None') {
    canvas.text('*', x + width * 0.47, topY - 7, 10, [255, 239, 119], 'center');
    canvas.text('*', x - width * 0.52, topY + 8, 8, [117, 238, 255], 'center');
  }
}

function drawTree(canvas, prop) {
  const [x, groundY] = project(prop.position[0], 0, prop.position[2]);
  canvas.roundedRect(x - 7, groundY - 48, 14, 48, 3, [118, 77, 44]);
  canvas.ellipse(x, groundY - 66, 32, 29, rgb(prop.color));
  canvas.ellipse(x - 13, groundY - 48, 25, 23, mix(rgb(prop.color), [255, 255, 255], 0.06));
  canvas.ellipse(x + 12, groundY - 48, 24, 22, shade(rgb(prop.color), 0.86));
  canvas.ellipse(x, groundY - 85, 20, 18, [55, 181, 83]);
}

function drawBase(canvas, base, label, isPlayer) {
  const [centerX, centerZ] = base.center;
  const [width, , depth] = base.size;
  const halfWidth = width / 2;
  const halfDepth = depth / 2;
  const top = base.color.map((value) => Math.round(value * 255));
  const front = shade(top, 0.65);
  const side = shade(top, 0.78);
  const a = project(centerX - halfWidth, 4, centerZ - halfDepth);
  const b = project(centerX + halfWidth, 4, centerZ - halfDepth);
  const c = project(centerX + halfWidth, 4, centerZ + halfDepth);
  const d = project(centerX - halfWidth, 4, centerZ + halfDepth);
  const ab = project(centerX - halfWidth, 0, centerZ - halfDepth);
  const bb = project(centerX + halfWidth, 0, centerZ - halfDepth);
  const cb = project(centerX + halfWidth, 0, centerZ + halfDepth);
  const db = project(centerX - halfWidth, 0, centerZ + halfDepth);
  canvas.polygon([a, b, c, d], top);
  canvas.polygon([d, c, cb, db], front);
  canvas.polygon([b, c, cb, bb], side);
  canvas.line(a[0], a[1], d[0], d[1], mix(top, [255, 255, 255], 0.5), 0.75);
  for (const sideSign of [-1, 1]) {
    const railX = centerX + sideSign * halfWidth;
    const start = project(railX, 5, centerZ - halfDepth);
    const end = project(railX, 5, centerZ + halfDepth);
    canvas.line(start[0], start[1], end[0], end[1], [255, 213, 48], 0.95);
  }
  const signZ = centerZ + (isPlayer ? halfDepth : -halfDepth);
  const [signX, signY] = project(centerX, 11, signZ);
  canvas.roundedRect(signX - 72, signY - 18, 144, 34, 8, [30, 31, 51], 0.96);
  canvas.roundedRect(signX - 68, signY - 14, 136, 26, 6, mix(top, [26, 30, 54], 0.35));
  canvas.outlineText(label, signX, signY - 8, 14, [255, 239, 95], 'center');
}

function drawConveyor(canvas) {
  const belt = data.world.conveyor;
  const halfWidth = belt.width / 2;
  const topY = belt.start[2];
  const endY = belt.end[2];
  const corners = [
    project(-halfWidth, belt.start[1], topY), project(halfWidth, belt.start[1], topY),
    project(halfWidth, belt.start[1], endY), project(-halfWidth, belt.start[1], endY)
  ];
  const lower = [
    project(-halfWidth, belt.start[1] - 1, topY), project(halfWidth, belt.start[1] - 1, topY),
    project(halfWidth, belt.start[1] - 1, endY), project(-halfWidth, belt.start[1] - 1, endY)
  ];
  canvas.polygon([corners[3], corners[2], lower[2], lower[3]], [27, 30, 42]);
  canvas.polygon([corners[0], corners[1], corners[2], corners[3]], [57, 61, 76]);
  for (let index = 0; index < 12; index += 1) {
    const z = topY + index * ((endY - topY) / 12);
    const [x, y] = project(0, belt.start[1] + 0.15, z);
    canvas.fillRect(x - 25, y, 50, 4, [255, 220, 62], 0.92);
    canvas.polygon([[x, y + 10], [x - 8, y + 2], [x + 8, y + 2]], [255, 220, 62]);
  }
  for (const side of [-1, 1]) {
    const start = project(side * halfWidth, belt.start[1] + 0.5, topY);
    const end = project(side * halfWidth, belt.start[1] + 0.5, endY);
    canvas.line(start[0], start[1], end[0], end[1], [255, 190, 35]);
  }
}

function drawPedestals(canvas, slots) {
  for (const slot of slots) {
    const [x, y] = project(slot[0], 4.25, slot[2]);
    canvas.ellipse(x, y + 3, 13, 5, [17, 36, 45], 0.28);
    canvas.polygon([[x - 12, y], [x, y - 5], [x + 12, y], [x, y + 5]], [225, 234, 247]);
    canvas.polygon([[x - 12, y], [x, y + 5], [x, y + 9], [x - 12, y + 4]], [150, 166, 191]);
    canvas.polygon([[x + 12, y], [x, y + 5], [x, y + 9], [x + 12, y + 4]], [172, 184, 207]);
  }
}

function drawAvatar(canvas, x, groundY, shirt, hat, label) {
  canvas.ellipse(x, groundY + 2, 17, 6, [16, 35, 42], 0.3);
  canvas.roundedRect(x - 12, groundY - 25, 9, 26, 3, [40, 43, 66]);
  canvas.roundedRect(x + 3, groundY - 25, 9, 26, 3, [40, 43, 66]);
  canvas.roundedRect(x - 16, groundY - 49, 32, 29, 5, shirt);
  canvas.roundedRect(x - 11, groundY - 74, 22, 27, 5, [244, 190, 130]);
  canvas.roundedRect(x - 13, groundY - 79, 26, 8, 3, hat);
  canvas.fillRect(x - 6, groundY - 66, 3, 4, [22, 24, 34]);
  canvas.fillRect(x + 4, groundY - 66, 3, 4, [22, 24, 34]);
  canvas.outlineText(label, x, groundY - 91, 10, [255, 242, 135], 'center');
}

function drawWideArena(canvas) {
  canvas.gradientRect(0, 0, 1280, 720, [100, 170, 238], [212, 242, 255]);
  canvas.ellipse(180, 216, 260, 95, [73, 181, 118], 0.45);
  canvas.ellipse(1100, 210, 290, 100, [63, 173, 112], 0.42);
  canvas.fillRect(0, 245, 1280, 475, [68, 178, 103]);
  const arena = [
    project(-80, 0, -80), project(80, 0, -80), project(80, 0, 80), project(-80, 0, 80)
  ];
  canvas.polygon(arena, [71, 184, 106]);
  for (let x = -60; x <= 60; x += 20) {
    const start = project(x, 0, -78);
    const end = project(x, 0, 78);
    canvas.line(start[0], start[1], end[0], end[1], [91, 198, 117], 0.28);
  }
  for (let z = -60; z <= 60; z += 20) {
    const start = project(-78, 0, z);
    const end = project(78, 0, z);
    canvas.line(start[0], start[1], end[0], end[1], [91, 198, 117], 0.28);
  }
  const wall = [project(-80, 0, -80), project(80, 0, -80), project(80, 8, -80), project(-80, 8, -80)];
  canvas.polygon(wall, [92, 77, 137]);
  drawBase(canvas, data.world.rivalBase, 'RIVAL BASE', false);
  drawPedestals(canvas, data.world.rivalSlots);
  drawConveyor(canvas);
  drawBase(canvas, data.world.playerBase, 'YOUR BASE', true);
  drawPedestals(canvas, data.world.playerSlots);
  for (const prop of data.world.props) if (prop.type === 'tree') drawTree(canvas, prop);
  const playerSlots = data.world.playerSlots;
  const ownedIds = ['tung', 'tralalero', 'ballerina', 'bombardiro', 'lirili', 'chimpanzini'];
  ownedIds.forEach((id, index) => {
    const slot = playerSlots[index];
    const [x, y] = project(slot[0], 5, slot[2]);
    drawBrainrot(canvas, brainrotMap.get(id), x, y, 12, index === 4 ? 'Golden' : 'None');
  });
  const conveyorItems = [['tralaleritos', -25, 11], ['bombardiro', -5, 13], ['lavaca', 18, 12], ['giraffa', 34, 13]];
  for (const [id, z, scale] of conveyorItems) {
    const [x, y] = project(0, 3.25, z);
    drawBrainrot(canvas, brainrotMap.get(id), x, y, scale, 'None');
  }
  const rivalItems = ['assassino', 'pot', 'cocco'];
  rivalItems.forEach((id, index) => {
    const slot = data.world.rivalSlots[index];
    const [x, y] = project(slot[0], 5, slot[2]);
    drawBrainrot(canvas, brainrotMap.get(id), x, y, 11, 'None');
  });
  drawAvatar(canvas, 470, 618, [48, 101, 239], [255, 202, 45], 'YOU');
  drawAvatar(canvas, 830, 296, [220, 48, 70], [84, 35, 146], 'RIVAL');
  for (const prop of data.world.props) {
    if (prop.type !== 'coin') continue;
    const [x, y] = project(prop.position[0], prop.position[1], prop.position[2]);
    canvas.ellipse(x, y, 10, 10, [255, 205, 46]);
    canvas.ellipse(x - 2, y - 2, 5, 5, [255, 241, 142]);
    canvas.text('$', x - 4, y - 8, 9, [166, 102, 16], 'center');
  }
  canvas.roundedRect(36, 648, 224, 43, 12, [22, 31, 58], 0.88);
  canvas.text('Q  SLAP RIVAL', 148, 662, 13, [255, 242, 158], 'center');
}

function floatingLabel(canvas, brainrot, x, y, width = 180, mutation = 'None') {
  const rarity = rarityMap.get(brainrot.rarity);
  const rarityColor = rgb(rarity.color);
  const mutationData = data.mutations.find((item) => item.name === mutation);
  const income = brainrot.income * mutationData.multiplier;
  panel(canvas, x, y, width, 67, [19, 22, 42], [68, 76, 112], 11, true);
  canvas.roundedRect(x, y, 6, 67, 3, rarityColor);
  canvas.text(brainrot.name, x + 14, y + 10, 9, [247, 248, 255]);
  canvas.text(brainrot.rarity.toUpperCase(), x + 14, y + 29, 8, rarityColor);
  if (mutation !== 'None') canvas.text(mutation.toUpperCase(), x + width - 12, y + 29, 8, rgb(mutationData.color), 'right');
  canvas.text(`$${income}/S`, x + width - 12, y + 46, 10, [111, 238, 168], 'right');
  canvas.line(x + width / 2, y + 67, x + width / 2, y + 78, [218, 226, 255], 0.55);
  canvas.ellipse(x + width / 2, y + 78, 3, 3, [218, 226, 255], 0.7);
}

function drawCloseScene(canvas) {
  canvas.gradientRect(0, 0, 1280, 720, [88, 157, 229], [200, 240, 248]);
  canvas.ellipse(130, 312, 220, 115, [64, 174, 105], 0.42);
  canvas.ellipse(1120, 330, 260, 130, [58, 166, 100], 0.38);
  canvas.fillRect(0, 220, 1280, 500, [65, 171, 100]);
  canvas.polygon([[42, 285], [850, 245], [899, 626], [92, 680]], [48, 112, 235]);
  canvas.polygon([[92, 680], [899, 626], [899, 672], [93, 724]], [24, 62, 156]);
  canvas.polygon([[850, 245], [899, 626], [899, 672], [850, 288]], [31, 73, 178]);
  canvas.line(42, 285, 850, 245, [111, 205, 255], 0.7);
  canvas.line(50, 291, 84, 681, [255, 212, 48], 0.9);
  canvas.line(842, 254, 891, 628, [255, 212, 48], 0.9);
  canvas.roundedRect(357, 195, 190, 44, 12, [30, 32, 53], 0.96);
  canvas.roundedRect(364, 202, 176, 30, 8, [56, 107, 220]);
  canvas.outlineText('YOUR BASE', 452, 210, 15, [255, 239, 93], 'center');
  const featured = [
    ['tung', 168, 406, 22, 'None', 72, 225, 188],
    ['tralalero', 453, 362, 23, 'None', 359, 178, 188],
    ['frigo', 748, 421, 23, 'None', 654, 241, 188],
    ['trippi', 217, 608, 20, 'Golden', 113, 478, 188],
    ['lavaca', 470, 625, 23, 'None', 375, 476, 190],
    ['pot', 727, 610, 20, 'None', 637, 479, 180]
  ];
  for (const [id, x, groundY, scale, mutation, labelX, labelY, labelWidth] of featured) {
    const brainrot = brainrotMap.get(id);
    canvas.ellipse(x, groundY + 3, brainrot.size[0] * scale * 0.7, brainrot.size[0] * scale * 0.2, [19, 38, 68], 0.32);
    canvas.ellipse(x, groundY, brainrot.size[0] * scale * 0.62, 11, [218, 232, 252]);
    drawBrainrot(canvas, brainrot, x, groundY, scale, mutation);
    floatingLabel(canvas, brainrot, labelX, labelY, labelWidth, mutation);
  }
  const roster = ['tung', 'tralalero', 'frigo', 'trippi', 'lavaca', 'pot'];
  panel(canvas, 925, 190, 330, 487, [22, 26, 51], [70, 82, 132], 20, true);
  canvas.roundedRect(944, 208, 292, 58, 14, [39, 45, 81]);
  canvas.text('BASE ROSTER', 963, 219, 11, [162, 174, 211]);
  canvas.text('6 / 12 PEDESTALS', 1213, 242, 10, [92, 231, 179], 'right');
  roster.forEach((id, index) => {
    const brainrot = brainrotMap.get(id);
    const rarity = rarityMap.get(brainrot.rarity);
    const y = 282 + index * 57;
    canvas.roundedRect(944, y, 292, 47, 11, [30, 35, 66]);
    canvas.roundedRect(952, y + 7, 34, 34, 9, rgb(brainrot.color));
    canvas.text(String(index + 1).padStart(2, '0'), 969, y + 16, 8, [29, 31, 48], 'center');
    canvas.text(brainrot.name, 998, y + 8, 9, [240, 242, 255]);
    canvas.text(brainrot.rarity.toUpperCase(), 998, y + 26, 8, rgb(rarity.color));
    canvas.text(`$${brainrot.income}/S`, 1219, y + 15, 10, [103, 235, 165], 'right');
  });
  canvas.roundedRect(944, 628, 292, 32, 10, [37, 165, 129]);
  // Base income is computed from the same GameData.json the game uses
  // (featured six: tung 2 + tralalero 3 + frigo 30 + trippi 35 Golden x2
  // + lavaca 25 + pot 110 = 240). The old hardcoded 174 was wrong.
  canvas.text(`BASE INCOME  ${scene2Base} / SEC`, 1090, 637, 10, [235, 255, 249], 'center');
}

function collectionCard(canvas, brainrot, index, owned) {
  const column = index % 4;
  const row = Math.floor(index / 4);
  const x = 48 + column * 208;
  // 6 rows must fit the 500-tall panel: 70px pitch, 64px cards. The old
  // 80px pitch pushed the 21st card out of the panel and off the screen.
  const y = 258 + row * 70;
  const rarity = rarityMap.get(brainrot.rarity);
  const rarityColor = rgb(rarity.color);
  panel(canvas, x, y, 196, 64, owned ? [35, 40, 72] : [25, 29, 54], mix(rarityColor, [55, 62, 96], 0.72), 11, false);
  canvas.roundedRect(x, y, 5, 64, 2, rarityColor);
  canvas.roundedRect(x + 8, y + 10, 32, 48, 8, mix(rgb(brainrot.color), [22, 25, 48], owned ? 0.2 : 0.45));
  drawBrainrot(canvas, brainrot, x + 24, y + 53, owned ? 5.2 : 4.6, 'None');
  const nameWidth = 137;
  if (canvas.textWidth(brainrot.name, 7) <= nameWidth) {
    canvas.text(brainrot.name, x + 46, y + 10, 7, owned ? [244, 246, 255] : [169, 177, 205]);
  } else {
    const words = brainrot.name.split(' ');
    const split = words.findIndex((word, wordIndex) => canvas.textWidth(words.slice(0, wordIndex + 1).join(' '), 7) > nameWidth);
    const first = words.slice(0, Math.max(1, split)).join(' ');
    const second = words.slice(Math.max(1, split)).join(' ');
    canvas.text(first, x + 46, y + 6, 7, owned ? [244, 246, 255] : [169, 177, 205]);
    canvas.text(second, x + 46, y + 15, 7, owned ? [244, 246, 255] : [169, 177, 205]);
  }
  canvas.text(brainrot.rarity.toUpperCase(), x + 46, y + 31, 7, rarityColor);
  canvas.text(`+$${brainrot.income}/S`, x + 46, y + 47, 8, owned ? [102, 237, 169] : [103, 170, 147]);
  canvas.text(`$${brainrot.price.toLocaleString('en-US')}`, x + 187, y + 47, 8, [238, 224, 144], 'right');
  if (owned) {
    canvas.ellipse(x + 183, y + 13, 7, 7, [83, 224, 157]);
    canvas.text('+', x + 183, y + 7, 8, [15, 52, 44], 'center');
  }
}

function rarityLadder(canvas) {
  panel(canvas, 910, 190, 342, 500, [22, 26, 51], [70, 82, 132], 20, true);
  canvas.text('RARITY LADDER', 934, 210, 15, [247, 248, 255]);
  canvas.text('INCOME / WEIGHT', 1226, 214, 8, [151, 162, 202], 'right');
  const ordered = [...data.rarities].reverse();
  ordered.forEach((rarity, index) => {
    const y = 258 + index * 57;
    const rarityColor = rgb(rarity.color);
    const count = data.brainrots.filter((brainrot) => brainrot.rarity === rarity.name).length;
    canvas.roundedRect(928, y, 306, 48, 10, [31, 36, 66]);
    canvas.roundedRect(928, y, 7, 48, 3, rarityColor);
    canvas.ellipse(954, y + 24, 11, 11, rarityColor);
    canvas.text(String(count), 954, y + 18, 7, rarity.name === 'Secret' ? [255, 255, 255] : [28, 31, 48], 'center');
    canvas.text(rarity.name.toUpperCase(), 976, y + 9, 10, rarityColor);
    canvas.text(`${rarity.income}/S`, 1217, y + 8, 9, [104, 234, 168], 'right');
    canvas.text(`W ${rarity.weight}`, 1217, y + 28, 8, [154, 163, 201], 'right');
    canvas.fillRect(976, y + 30, 132, 5, [17, 20, 41]);
    canvas.fillRect(976, y + 30, 132 * rarity.weight / 50, 5, rarityColor);
  });
  canvas.roundedRect(928, 658, 306, 20, 7, [36, 42, 75]);
  // Real mechanic: each rebirth is a permanent +50% income multiplier.
  // (The old "collection bonus +10%" line described no such mechanic.)
  canvas.text('REBIRTH  +50% INCOME EACH', 1081, 663, 7, [199, 207, 236], 'center');
}

function drawCollectionScene(canvas) {
  canvas.gradientRect(0, 0, 1280, 720, [31, 35, 69], [18, 23, 48]);
  canvas.ellipse(190, 280, 290, 190, [79, 49, 142], 0.22);
  canvas.ellipse(1080, 520, 320, 210, [38, 101, 132], 0.18);
  panel(canvas, 28, 190, 858, 500, [20, 24, 49], [66, 78, 126], 20, true);
  canvas.text('BRAINROT COLLECTION', 49, 207, 17, [248, 249, 255]);
  canvas.text('6 OWNED  /  21 DISCOVERED', 48, 232, 9, [148, 161, 201]);
  canvas.roundedRect(650, 207, 212, 34, 12, [34, 40, 70]);
  canvas.text('FILTER: ALL RARITIES', 756, 218, 8, [172, 183, 220], 'center');
  const owned = new Set(['tung', 'tralalero', 'frigo', 'trippi', 'lavaca', 'pot']);
  data.brainrots.forEach((brainrot, index) => collectionCard(canvas, brainrot, index, owned.has(brainrot.id)));
  rarityLadder(canvas);
}

// HUD incomes, computed from the same GameData.json the game uses instead
// of hardcoded numbers (the old 38/174/410 did not match the brainrots
// actually drawn). Base income sums each shown brainrot's $/s with its
// mutation multiplier; the HUD shows the total after the rebirth
// multiplier (rebirth 1 = x1.5, rebirth 3 = x2.5).
const incomeOf = (entries) => entries.reduce((total, [id, mutation = 'None']) => {
  const brainrot = brainrotMap.get(id);
  const multiplier = data.mutations.find((item) => item.name === mutation).multiplier;
  return total + brainrot.income * multiplier;
}, 0);
const scene1Base = incomeOf([['tung'], ['tralalero'], ['ballerina'], ['bombardiro'], ['lirili', 'Golden'], ['chimpanzini']]);
const scene2Base = incomeOf([['tung'], ['tralalero'], ['frigo'], ['trippi', 'Golden'], ['lavaca'], ['pot']]);
// Scene 3's owned six have no mutation (the collection shows them plain),
// so its base is 205, not scene2Base's 240 (which includes Golden trippi).
const scene3Base = incomeOf([['tung'], ['tralalero'], ['frigo'], ['trippi'], ['lavaca'], ['pot']]);

const scenes = [
  {
    name: '1-start.png',
    draw: (canvas) => {
      drawWideArena(canvas);
      drawHud(canvas, { cash: '$12,450', income: `${Math.floor(scene1Base * 1.5)}/S`, rebirth: '1  X1.5' });
    }
  },
  {
    name: '2-play.png',
    draw: (canvas) => {
      drawCloseScene(canvas);
      drawHud(canvas, { cash: '$18,420', income: `${Math.floor(scene2Base * 1.5)}/S`, rebirth: '1  X1.5' });
    }
  },
  {
    name: '3-end.png',
    draw: (canvas) => {
      drawCollectionScene(canvas);
      drawHud(canvas, { cash: '$42,680', income: `${Math.floor(scene3Base * 2.5)}/S`, rebirth: '3  X2.5' });
    }
  }
];

for (const scene of scenes) {
  const canvas = new Canvas(1280, 720);
  scene.draw(canvas);
  composedBadge(canvas);
  const png = encodePng(canvas);
  if (png.length > 262144) throw new Error(`${scene.name} exceeds 256 KiB`);
  writeFileSync(join(root, 'screenshots', scene.name), png);
  console.log(`${scene.name}: ${png.length} bytes, 1280x720 PNG`);
}
