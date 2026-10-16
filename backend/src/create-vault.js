import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import readline from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import argon2 from 'argon2';

dotenv.config();

const secret = process.env.VAULT_SECRET;
if (!secret || secret.length < 32) {
    throw new Error('VAULT_SECRET doit contenir au moins 32 caractères aléatoires.');
}

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(backendRoot, 'vault', 'users.vault.enc');
const overwrite = process.argv.includes('--force');

if (fs.existsSync(output) && !overwrite) {
    throw new Error('Vault existant : création refusée. Utiliser --force uniquement pour réinitialiser les DEUX comptes (toutes les sessions précédentes deviendront invalides après révocation).');
}
if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error('Un terminal interactif est nécessaire pour saisir les mots de passe sans les exposer.');
}

// Désactive l'écho du terminal pendant la saisie des mots de passe.
const rl = readline.createInterface({ input: stdin, output: stdout, terminal: true });

async function hiddenPrompt(label) {
    const originalWrite = rl._writeToOutput;

    rl._writeToOutput = function (value) {
        if (value.includes('\n') || value.includes('\r')) {
            originalWrite.call(this, value);
        }
    };

    try {
        return await rl.question(label);
    } finally {
        rl._writeToOutput = originalWrite;
    }
}


async function passwordFor(account) {
    const password = await hiddenPrompt(`Mot de passe ${account} : `);
    const confirmation = await hiddenPrompt(`Confirmer ${account} : `);
    if (password !== confirmation) {
        throw new Error(`Confirmation incorrecte pour ${account}.`);
    }
    if (password.length < 14 || Buffer.byteLength(password, 'utf8') > 1024) {
        throw new Error(`Le mot de passe ${account} doit contenir entre 14 et 1024 caractères (UTF-8).`);
    }
    return argon2.hash(password, { type: argon2.argon2id });
}

try {
    console.log('Création des deux comptes partagés (terrain et admin).');
    if (overwrite) console.log('ATTENTION : le vault existant sera remplacé.');
    const terrainHash = await passwordFor('terrain');
    const adminHash = await passwordFor('admin');
    const users = [
        { id: 'user-001', identifier: 'terrain', name: 'Compte terrain', passwordHash: terrainHash },
        { id: 'user-002', identifier: 'admin', name: 'Administrateur', passwordHash: adminHash }
    ];
    const key = crypto.createHash('sha256').update(secret).digest();
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    const encrypted = Buffer.concat([
        cipher.update(JSON.stringify({ version: 1, users }), 'utf8'),
        cipher.final()
    ]);
    const payload = JSON.stringify({
        iv: iv.toString('base64'),
        tag: cipher.getAuthTag().toString('base64'),
        data: encrypted.toString('base64')
    });
    fs.mkdirSync(path.dirname(output), { recursive: true, mode: 0o700 });
    const temporaryPath = `${output}.${crypto.randomBytes(8).toString('hex')}.tmp`;
    fs.writeFileSync(temporaryPath, payload, { mode: 0o600, flag: 'wx' });
    fs.renameSync(temporaryPath, output);
    console.log('Vault créé : deux comptes terrain et admin. Aucun mot de passe affiché.');
} finally {
    rl.close();
}
