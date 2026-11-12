import { test } from 'node:test';
import assert from 'node:assert/strict';
import zlib from 'node:zlib';
import { generateReceiptPdf } from './receipt_pdf.js';

function chunk(name, payload) {
  // Le lecteur n'utilise pas la CRC, mais une PNG de test suit le format du flux.
  const size = Buffer.alloc(4);
  size.writeUInt32BE(payload.length);
  return Buffer.concat([size, Buffer.from(name, 'ascii'), payload, Buffer.alloc(4)]);
}
function tinySignature() {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(2, 0); ihdr.writeUInt32BE(1, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8 bits, RGBA
  const scanline = Buffer.from([0, 20, 70, 90, 255, 20, 70, 90, 0]);
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(scanline)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
const base = {
  id: 'b1b1b1b1-1111-4111-a111-111111111111', type: 'don',
  beneficiary: 'Mme Payet - Service informatique', author: 'Administrateur',
  created_at: '2026-11-06T08:22:00.000Z',
  signer_name: 'Mme Payet', signed_at: '2026-11-06T08:25:00.000Z',
  equipment_type: 'Ordinateur', quantity: 1, content: 'Ordinateur avec accessoires',
};
const items = [
  { equipment_type: 'Ordinateur', quantity: 1 },
  { equipment_type: 'Souris', quantity: 1 },
  { equipment_type: 'Sacoche de transport', quantity: 1 },
  { equipment_type: 'Chargeur', quantity: 1 },
];

test('A4 don signé, matériel multiple et pièces jointes valides', () => {
  const pdf = generateReceiptPdf(base, items, tinySignature());
  assert.equal(pdf.subarray(0, 8).toString('ascii'), '%PDF-1.4');
  assert.match(pdf.subarray(-30).toString('ascii'), /%%EOF/);
  assert.match(pdf.toString('latin1'), /\/Subtype \/Image/);
});

test('Prêt rendu sans signature et nombreuses lignes : plusieurs pages', () => {
  const longItems = Array.from({ length: 20 }, (_, i) => ({
    equipment_type: `Accessoire avec numéro ${i + 1} et description détaillée`, quantity: i + 1,
  }));
  const pdf = generateReceiptPdf({
    ...base, type: 'pret', loan_status: 'rendu', returned_at: new Date(),
    returned_by: 'Service informatique', return_comment: 'Retour sans réserve.',
  }, longItems);
  assert.match(pdf.toString('latin1'), /\/Count [2-9]/);
});

test('Transmissions invalides refusées', () => {
  assert.throws(() => generateReceiptPdf({ ...base, type: 'autre' }, items));
});
