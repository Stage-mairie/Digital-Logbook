// Générateur PDF A4 autonome : aucune dépendance npm supplémentaire.
// Les reçus sont construits en mémoire et ne sont jamais stockés dans PostgreSQL.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const PAGE_W = 595.28;
const PAGE_H = 841.89;
const LEFT = 42;
const RIGHT = PAGE_W - LEFT;
const BOTTOM = 780;
const TEAL = '#164A58';
const MUTED = '#597681';
const LIGHT = '#E8F0F2';
const GOLD = '#D9B75B';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

function number(value) { return Number(value).toFixed(2); }
function rgb(hex) {
  const n = parseInt(hex.substring(1), 16);
  return [n >> 16, (n >> 8) & 255, n & 255].map(x => number(x / 255)).join(' ');
}
const windows1252 = new Map(Object.entries({
  '€': 128, '‚': 130, 'ƒ': 131, '„': 132, '…': 133, '†': 134, '‡': 135,
  'ˆ': 136, '‰': 137, 'Š': 138, '‹': 139, 'Œ': 140, 'Ž': 142,
  '‘': 145, '’': 146, '“': 147, '”': 148, '•': 149, '–': 150, '—': 151,
  '˜': 152, '™': 153, 'š': 154, '›': 155, 'œ': 156, 'ž': 158, 'Ÿ': 159,
}).map(([k, v]) => [k, v]));
function textHex(input) {
  const normalized = String(input ?? '').normalize('NFC');
  const bytes = [];
  for (const character of normalized) {
    const n = character.codePointAt(0);
    if (n >= 32 && n <= 126 || n >= 160 && n <= 255) bytes.push(n);
    else bytes.push(windows1252.get(character) ?? 63);
  }
  return Buffer.from(bytes).toString('hex').toUpperCase();
}
function sizeOf(input, fontSize, bold = false) {
  let amount = 0;
  for (const ch of String(input)) {
    if (ch === ' ') amount += 0.26;
    else if ('ilI.,:;!|'.includes(ch)) amount += 0.25;
    else if ('WwMm'.includes(ch)) amount += 0.78;
    else if (ch >= 'A' && ch <= 'Z') amount += 0.65;
    else amount += 0.53;
  }
  return amount * fontSize * (bold ? 1.04 : 1);
}
function wrap(value, width, fontSize, bold = false) {
  const result = [];
  for (const raw of String(value ?? '').replace(/\r/g, '').split('\n')) {
    let line = '';
    for (let word of raw.trim().split(/\s+/).filter(Boolean)) {
      // Découper les mots exceptionnellement longs pour éviter le débordement.
      while (sizeOf(word, fontSize, bold) > width) {
        let cut = 1;
        while (cut < word.length && sizeOf(word.slice(0, cut + 1), fontSize, bold) < width) cut++;
        if (line) { result.push(line); line = ''; }
        result.push(word.slice(0, cut));
        word = word.slice(cut);
      }
      const combined = line ? `${line} ${word}` : word;
      if (line && sizeOf(combined, fontSize, bold) > width) {
        result.push(line);
        line = word;
      } else line = combined;
    }
    result.push(line);
  }
  return result.length ? result : [''];
}
function fmtDate(value) {
  if (!value) return 'Non renseignée';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return 'Non renseignée';
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Indian/Reunion', dateStyle: 'medium', timeStyle: 'short',
  }).format(d);
}
function equipmentLabel(item) {
  const type = String(item.equipment_type || 'Matériel').trim();
  const model = String(item.equipment_model || '').trim();
  const custom = String(item.custom_equipment || '').trim();
  return type.toLocaleLowerCase('fr') === 'autre' && custom ? custom :
    model ? `${type} - ${model}` : type;
}

class PdfWriter {
  constructor() { this.objects = [null]; }
  reserve() { this.objects.push(null); return this.objects.length - 1; }
  set(id, body) { this.objects[id] = Buffer.isBuffer(body) ? body : Buffer.from(body, 'latin1'); }
  add(body) { const id = this.reserve(); this.set(id, body); return id; }
  stream(dict, bytes) {
    return this.add(Buffer.concat([
      Buffer.from(`<< ${dict} /Length ${bytes.length} >>\nstream\n`, 'ascii'),
      bytes, Buffer.from('\nendstream', 'ascii'),
    ]));
  }
  finish(root) {
    const out = [Buffer.from('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n', 'latin1')];
    const offsets = [0];
    let current = out[0].length;
    for (let id = 1; id < this.objects.length; id++) {
      if (!this.objects[id]) throw new Error(`Objet PDF ${id} manquant`);
      const section = Buffer.concat([
        Buffer.from(`${id} 0 obj\n`, 'ascii'), this.objects[id],
        Buffer.from('\nendobj\n', 'ascii'),
      ]);
      offsets.push(current); out.push(section); current += section.length;
    }
    const xref = current;
    let table = `xref\n0 ${this.objects.length}\n0000000000 65535 f \n`;
    for (const offset of offsets.slice(1)) table += `${String(offset).padStart(10, '0')} 00000 n \n`;
    table += `trailer\n<< /Size ${this.objects.length} /Root ${root} 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
    out.push(Buffer.from(table, 'ascii'));
    return Buffer.concat(out);
  }
}
function parsePng(png) {
  // PNG enregistrés par l'outil de signature Flutter : PNG RVB ou RGBA 8 bits.
  if (!Buffer.isBuffer(png) || png.length < 67 || !png.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex'))) {
    throw new Error('Signature PNG invalide.');
  }
  let offset = 8, width, height, depth, colorType, interlace;
  const parts = [];
  while (offset + 12 <= png.length) {
    const length = png.readUInt32BE(offset);
    const tag = png.toString('ascii', offset + 4, offset + 8);
    offset += 8;
    if (length > png.length - offset - 4) throw new Error('PNG tronqué.');
    const bytes = png.subarray(offset, offset + length);
    if (tag === 'IHDR') {
      if (length !== 13) throw new Error('PNG IHDR invalide.');
      width = bytes.readUInt32BE(0); height = bytes.readUInt32BE(4);
      depth = bytes[8]; colorType = bytes[9]; interlace = bytes[12];
    } else if (tag === 'IDAT') parts.push(bytes);
    offset += length + 4; // CRC
    if (tag === 'IEND') break;
  }
  if (!width || !height || width > 3000 || height > 3000 || width * height > 3_000_000 ||
      depth !== 8 || ![0, 2, 4, 6].includes(colorType) || interlace !== 0 || !parts.length) {
    throw new Error('Format PNG de signature non pris en charge.');
  }
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[colorType];
  const stride = width * channels;
  const expected = (stride + 1) * height;
  const raw = zlib.inflateSync(Buffer.concat(parts), { maxOutputLength: expected + 1 });
  if (raw.length !== expected) throw new Error('Taille des pixels PNG invalide.');
  const decoded = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const srcStart = y * (stride + 1), dstStart = y * stride;
    const filter = raw[srcStart];
    if (filter > 4) throw new Error('Filtre PNG non pris en charge.');
    for (let x = 0; x < stride; x++) {
      const value = raw[srcStart + 1 + x];
      const a = x >= channels ? decoded[dstStart + x - channels] : 0;
      const b = y > 0 ? decoded[dstStart - stride + x] : 0;
      const c = x >= channels && y > 0 ? decoded[dstStart - stride + x - channels] : 0;
      let predict = 0;
      if (filter === 1) predict = a;
      if (filter === 2) predict = b;
      if (filter === 3) predict = Math.floor((a + b) / 2);
      if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        predict = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      decoded[dstStart + x] = (value + predict) & 255;
    }
  }
  const pixels = width * height;
  const rgbBytes = Buffer.alloc(pixels * 3), alphaBytes = Buffer.alloc(pixels);
  let transparent = false;
  for (let i = 0; i < pixels; i++) {
    const o = i * channels, r = i * 3;
    const gray = decoded[o];
    rgbBytes[r] = channels <= 2 ? gray : decoded[o];
    rgbBytes[r + 1] = channels <= 2 ? gray : decoded[o + 1];
    rgbBytes[r + 2] = channels <= 2 ? gray : decoded[o + 2];
    const alpha = channels === 2 ? decoded[o + 1] : channels === 4 ? decoded[o + 3] : 255;
    alphaBytes[i] = alpha;
    if (alpha < 255) transparent = true;
  }
  return { width, height, rgbBytes, alphaBytes: transparent ? alphaBytes : null };
}
function addPng(writer, png) {
  const img = parsePng(png);
  let alpha = '';
  if (img.alphaBytes) {
    const mask = writer.stream(`/Type /XObject /Subtype /Image /Width ${img.width} /Height ${img.height} /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode`, zlib.deflateSync(img.alphaBytes));
    alpha = `/SMask ${mask} 0 R`;
  }
  const id = writer.stream(`/Type /XObject /Subtype /Image /Width ${img.width} /Height ${img.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode ${alpha}`, zlib.deflateSync(img.rgbBytes));
  return { id, width: img.width, height: img.height };
}

class Layout {
  constructor(writer, fonts, images) {
    this.writer = writer; this.fonts = fonts; this.images = images;
    this.pages = []; this.start();
  }
  start() {
    this.ops = []; this.y = 149;
    this.pages.push(this.ops);
    this.rect(0, 0, PAGE_W, 108, TEAL);
    this.rect(42, 103, 62, 5, GOLD);
    this.text('VILLE DE SAINT-ANDRÉ  /  CAHIER DE TRANSMISSION', 42, 29, 9, '#E3F0F1', true);
    this.text('REÇU DE TRANSMISSION', 42, 54, 23, '#FFFFFF', true);
    if (this.images.logo) {
      this.rect(444, 19, 109, 69, '#FFFFFF');
      this.image('Logo', this.images.logo, 449, 27, 99, 52);
    }
  }
  rect(x, y, w, h, color) { this.ops.push(`${rgb(color)} rg ${number(x)} ${number(PAGE_H-y-h)} ${number(w)} ${number(h)} re f`); }
  line(x, y, x2, y2, color = LIGHT) { this.ops.push(`${rgb(color)} RG 0.7 w ${number(x)} ${number(PAGE_H-y)} m ${number(x2)} ${number(PAGE_H-y2)} l S`); }
  text(value, x, y, size = 10, color = TEAL, bold = false) {
    this.ops.push(`${rgb(color)} rg BT /${bold ? 'F2' : 'F1'} ${number(size)} Tf 1 0 0 1 ${number(x)} ${number(PAGE_H - y - size)} Tm <${textHex(value)}> Tj ET`);
  }
  image(name, img, x, y, w, h) {
    this.ops.push(`q ${number(w)} 0 0 ${number(h)} ${number(x)} ${number(PAGE_H-y-h)} cm /${name} Do Q`);
  }
  ensure(height) { if (this.y + height > BOTTOM) this.start(); }
  paragraph(value, options = {}) {
    const { x = LEFT, width = RIGHT - LEFT, fontSize = 10, lineHeight = 15, color = TEAL, bold = false } = options;
    for (const line of wrap(value, width, fontSize, bold)) {
      this.ensure(lineHeight);
      this.text(line, x, this.y, fontSize, color, bold);
      this.y += lineHeight;
    }
  }
  section(title) {
    this.ensure(43);
    this.y += 12;
    this.text(title, LEFT, this.y, 11, TEAL, true);
    this.y += 21;
    this.line(LEFT, this.y - 3, RIGHT, this.y - 3);
    this.y += 6;
  }
  field(label, value) {
    const v = String(value ?? '').trim() || 'Non renseigné';
    const lines = wrap(v, 342, 10);
    this.ensure(lines.length * 16 + 5);
    this.text(label, LEFT, this.y, 9.5, MUTED, true);
    for (const line of lines) {
      this.text(line, 184, this.y, 10, TEAL);
      this.y += 16;
    }
    this.y += 4;
  }
  items(items) {
    this.ensure(36);
    this.rect(LEFT, this.y, RIGHT - LEFT, 27, TEAL);
    this.text('MATÉRIEL / ACCESSOIRE', LEFT + 10, this.y + 7, 9, '#FFFFFF', true);
    this.text('QTÉ', RIGHT - 43, this.y + 7, 9, '#FFFFFF', true);
    this.y += 27;
    for (const item of items) {
      const lines = wrap(equipmentLabel(item), RIGHT - LEFT - 92, 10);
      const rowHeight = Math.max(27, lines.length * 15 + 10);
      if (this.y + rowHeight > BOTTOM) {
        this.start();
        this.rect(LEFT, this.y, RIGHT - LEFT, 27, TEAL);
        this.text('MATÉRIEL / ACCESSOIRE (SUITE)', LEFT + 10, this.y + 7, 9, '#FFFFFF', true);
        this.text('QTÉ', RIGHT - 43, this.y + 7, 9, '#FFFFFF', true);
        this.y += 27;
      }
      this.rect(LEFT, this.y, RIGHT - LEFT, rowHeight, items.indexOf(item) % 2 ? '#FFFFFF' : '#F4F8F9');
      lines.forEach((line, index) => this.text(line, LEFT + 10, this.y + 6 + index * 15, 10));
      this.text(String(item.quantity ?? 1), RIGHT - 40, this.y + 6, 10, TEAL, true);
      this.y += rowHeight;
    }
    this.y += 4;
  }
  footer() {
    this.pages.forEach((ops, index) => {
      ops.push(`${rgb(LIGHT)} RG 0.8 w ${number(LEFT)} 44 m ${number(RIGHT)} 44 l S`);
      ops.push(`${rgb(MUTED)} rg BT /F1 8 Tf 1 0 0 1 ${number(LEFT)} 29 Tm <${textHex('Généré depuis Digital-Logbook - Document interne')}> Tj ET`);
      ops.push(`${rgb(MUTED)} rg BT /F1 8 Tf 1 0 0 1 ${number(RIGHT - 80)} 29 Tm <${textHex(`Page ${index + 1} / ${this.pages.length}`)}> Tj ET`);
    });
  }
}

/** Génère un reçu pour un don ou un prêt, signé uniquement lors de la remise. */
export function generateReceiptPdf(record, equipmentItems, signaturePng = null) {
  if (!record || !['don', 'pret'].includes(record.type)) throw new Error('Transmission invalide.');
  const writer = new PdfWriter();
  const f1 = writer.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
  const f2 = writer.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');
  const pagesRef = writer.reserve();
  const images = {};
  const logoPath = path.join(__dirname, 'receipt-logo.jpg');
  if (fs.existsSync(logoPath)) {
    const logoBytes = fs.readFileSync(logoPath);
    const logoId = writer.stream('/Type /XObject /Subtype /Image /Width 540 /Height 278 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode', logoBytes);
    images.logo = { id: logoId };
  }
  if (signaturePng) images.signature = addPng(writer, signaturePng);
  const l = new Layout(writer, { f1, f2 }, images);
  l.text(record.type === 'don' ? 'BON DE DON DE MATÉRIEL' : 'BON DE PRÊT DE MATÉRIEL', LEFT, 123, 12, TEAL, true);
  l.y = 164;
  l.field('Référence', String(record.id));
  l.field('Type', record.type === 'don' ? 'Don de matériel' : 'Prêt de matériel');
  if (record.type === 'pret') {
    l.field('Statut du prêt', record.loan_status === 'rendu' ? 'Rendu' : 'En cours');
  }
  l.section('INFORMATIONS DE LA REMISE');
  l.field('Bénéficiaire / service', record.beneficiary);
  l.field('Date de remise', fmtDate(record.created_at));
  l.field('Enregistré par', record.author);
  l.section('MATÉRIEL REMIS');
  const items = Array.isArray(equipmentItems) && equipmentItems.length ? equipmentItems : [record];
  l.items(items);
  if (String(record.content || '').trim()) {
    l.section('COMMENTAIRE À LA REMISE');
    l.paragraph(record.content, { width: RIGHT - LEFT });
  }
  if (record.type === 'pret' && (record.loan_status === 'rendu' || record.returned_at)) {
    l.section('RESTITUTION DU MATÉRIEL');
    l.field('Date de restitution', fmtDate(record.returned_at));
    l.field('Retour enregistré par', record.returned_by);
    if (String(record.return_comment || '').trim()) {
      l.paragraph(record.return_comment, { width: RIGHT - LEFT });
    }
    l.paragraph('Aucune signature de retour n’est enregistrée par l’application.', { fontSize: 9, color: MUTED });
  }
  l.section('ACCUSÉ DE REMISE');
  l.field('Nom du signataire', signaturePng ? record.signer_name : 'Aucune signature enregistrée');
  if (signaturePng) {
    l.field('Date de signature', fmtDate(record.signed_at));
    l.ensure(102);
    l.rect(LEFT, l.y, 235, 88, '#F4F8F9');
    // Respecte le ratio de la signature, sans l'étirer.
    const ratio = images.signature.width / images.signature.height;
    const width = Math.min(215, 66 * ratio);
    const height = width / ratio;
    l.image('Signature', images.signature, LEFT + (235 - width) / 2, l.y + (88 - height) / 2, width, height);
    l.y += 97;
  }
  l.y += 8;
  l.paragraph('Document généré à partir des données enregistrées dans le Cahier de Transmission. Il atteste de la remise, et non d’une signature supplémentaire lors d’un retour.', { fontSize: 8, lineHeight: 12, color: MUTED });
  l.footer();
  const pageIds = [];
  const resources = `<< /Font << /F1 ${f1} 0 R /F2 ${f2} 0 R >> /XObject << ${images.logo ? `/Logo ${images.logo.id} 0 R` : ''} ${images.signature ? `/Signature ${images.signature.id} 0 R` : ''} >> >>`;
  for (const ops of l.pages) {
    const compressed = zlib.deflateSync(Buffer.from(ops.join('\n') + '\n', 'ascii'));
    const contents = writer.stream('/Filter /FlateDecode', compressed);
    const page = writer.add(`<< /Type /Page /Parent ${pagesRef} 0 R /MediaBox [0 0 ${number(PAGE_W)} ${number(PAGE_H)}] /Resources ${resources} /Contents ${contents} 0 R >>`);
    pageIds.push(page);
  }
  writer.set(pagesRef, `<< /Type /Pages /Kids [${pageIds.map(id => `${id} 0 R`).join(' ')}] /Count ${pageIds.length} >>`);
  const root = writer.add(`<< /Type /Catalog /Pages ${pagesRef} 0 R >>`);
  return writer.finish(root);
}
