import express from 'express';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import argon2 from 'argon2';

import {
    checkDatabase,
    ensureDatabaseSchema,
    query
} from './db.js';

dotenv.config();

const app = express();
const NODE_ENV = process.env.NODE_ENV || 'development';
const PORT = Number(process.env.PORT || 3000);
const SESSION_DAYS = Number(process.env.SESSION_DAYS || 180);
const SECRET = process.env.VAULT_SECRET;

// En production, la collecte n'est activée qu'après validation RGPD par la collectivité.
const signaturesEnabled = NODE_ENV !== 'production' || process.env.ENABLE_SIGNATURES === 'true';
const MAX_SIGNATURE_BYTES = 300_000;
const PNG_MAGIC = Buffer.from('89504e470d0a1a0a', 'hex');

const configuredCorsOrigins = String(
    process.env.CORS_ORIGINS || process.env.CORS_ORIGIN || ''
)
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

if (!SECRET) {
    throw new Error('VAULT_SECRET manquant dans .env');
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendRoot = path.resolve(__dirname, '..');

const vaultPath = path.join(backendRoot, 'vault', 'users.vault.enc');

// ------------------------------------------------------------
// MIDDLEWARES
// ------------------------------------------------------------

app.use(express.json({ limit: '1mb' }));

app.disable('x-powered-by');

// Flutter Web a besoin de CORS. En développement, les origines localhost sont
// acceptées automatiquement. En production, seules les origines explicitement
// listées dans CORS_ORIGINS sont autorisées. Les applications Android natives
// ne sont pas concernées par CORS car elles n'envoient pas d'en-tête Origin.
app.use((request, response, next) => {
    const origin = request.headers.origin;
    const isLocalOrigin =
        NODE_ENV !== 'production' &&
        typeof origin === 'string' &&
        /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);

    const isConfiguredOrigin =
        typeof origin === 'string' &&
        configuredCorsOrigins.includes(origin);

    if (origin && (isLocalOrigin || isConfiguredOrigin)) {
        response.setHeader('Access-Control-Allow-Origin', origin);
        response.setHeader('Vary', 'Origin');
        response.setHeader(
            'Access-Control-Allow-Headers',
            'Content-Type, Authorization'
        );
        response.setHeader(
            'Access-Control-Allow-Methods',
            'GET, POST, PATCH, OPTIONS'
        );
    }

    if (request.method === 'OPTIONS') {
        if (origin && !(isLocalOrigin || isConfiguredOrigin)) {
            return response.status(403).json({ error: 'Origine non autorisée.' });
        }
        return response.sendStatus(204);
    }

    next();
});

// ------------------------------------------------------------
// CHIFFREMENT DU VAULT
// ------------------------------------------------------------

const encryptionKey = crypto
    .createHash('sha256')
    .update(SECRET)
    .digest();

function decrypt(payload) {
    const object = JSON.parse(payload);

    const decipher = crypto.createDecipheriv(
        'aes-256-gcm',
        encryptionKey,
        Buffer.from(object.iv, 'base64')
    );

    decipher.setAuthTag(Buffer.from(object.tag, 'base64'));

    return Buffer.concat([
        decipher.update(Buffer.from(object.data, 'base64')),
        decipher.final()
    ]).toString('utf8');
}

function readVault() {
    return JSON.parse(
        decrypt(
            fs.readFileSync(vaultPath, 'utf8')
        )
    );
}

// ------------------------------------------------------------
// SESSIONS POSTGRESQL
// ------------------------------------------------------------
// Les sessions sont elles aussi centralisées dans PostgreSQL. Ainsi, toutes
// les tablettes et tous les navigateurs qui utilisent le même backend partagent
// la même source de vérité, et plusieurs instances du backend peuvent fonctionner
// sans dépendre d'un fichier sessions.json local.

function hashToken(token) {
    return crypto
        .createHash('sha256')
        .update(token)
        .digest('hex');
}

function generateToken() {
    return crypto.randomBytes(48).toString('base64url');
}

async function findValidSession(token) {
    if (!token) {
        return null;
    }

    const result = await query(
        `
        SELECT user_id, created_at, expires_at
        FROM sessions
        WHERE token_hash = $1
          AND expires_at > NOW()
        `,
        [hashToken(token)]
    );

    if (result.rowCount === 0) {
        return null;
    }

    const row = result.rows[0];
    return {
        userId: row.user_id,
        createdAt: row.created_at,
        expiresAt: row.expires_at
    };
}

async function requireSession(request, response, next) {
    const authorization = request.headers.authorization || '';
    const [scheme, token] = authorization.split(' ');

    if (scheme?.toLowerCase() !== 'bearer' || !token) {
        return response.status(401).json({ error: 'Session manquante.' });
    }

    const session = await findValidSession(token);

    if (!session) {
        return response.status(401).json({ error: 'Session invalide ou expirée.' });
    }

    const vault = readVault();
    const user = vault.users.find((item) => item.id === session.userId);

    if (!user) {
        return response.status(401).json({ error: 'Utilisateur introuvable.' });
    }

    request.session = session;
    request.user = user;
    next();
}

function rowToTransmission(row) {
    return {
        id: row.id,
        type: row.type,
        equipmentType: row.equipment_type,
        equipmentModel: row.equipment_model,
        customEquipment: row.custom_equipment,
        quantity: row.quantity,
        beneficiary: row.beneficiary,
        content: row.content,
        author: row.author,
        authorId: row.author_id,
        loanStatus: row.loan_status ?? (row.type === 'pret' ? 'en_cours' : null),
        returnedAt: row.returned_at,
        returnedBy: row.returned_by,
        returnedById: row.returned_by_id,
        returnComment: row.return_comment,
        hasSignature: row.has_signature ?? Boolean(row.signature_png),
        signerName: row.signer_name ?? null,
        signedAt: row.signed_at ?? null,
        createdAt: row.created_at
    };
}

// ------------------------------------------------------------
// HEALTH CHECK
// ------------------------------------------------------------

app.get('/health', async (_, response) => {
    try {
        await checkDatabase();
        response.json({
            ok: true,
            service: 'Digital-Logbook Auth',
            database: 'connected'
        });
    } catch (error) {
        console.error('Health check PostgreSQL:', error);
        response.status(503).json({
            ok: false,
            service: 'Digital-Logbook Auth',
            database: 'disconnected'
        });
    }
});

// ------------------------------------------------------------
// AUTH
// ------------------------------------------------------------

app.post('/auth/login', async (request, response) => {
    const { identifier, password } = request.body || {};

    if (!identifier || !password) {
        return response.status(400).json({
            error: 'Identifiant et mot de passe requis.'
        });
    }

    const vault = readVault();
    const user = vault.users.find(
        (item) =>
            item.identifier.toLowerCase() ===
            String(identifier).toLowerCase()
    );

    if (!user) {
        return response.status(401).json({ error: 'Identifiants invalides.' });
    }

    const passwordValid = await argon2.verify(user.passwordHash, password);

    if (!passwordValid) {
        return response.status(401).json({ error: 'Identifiants invalides.' });
    }

    const token = generateToken();

    await query(
        `
        INSERT INTO sessions (token_hash, user_id, created_at, expires_at)
        VALUES (
            $1,
            $2,
            NOW(),
            NOW() + ($3::integer * INTERVAL '1 day')
        )
        `,
        [hashToken(token), user.id, SESSION_DAYS]
    );

    response.json({
        ok: true,
        user: {
            id: user.id,
            identifier: user.identifier,
            name: user.name
        },
        refreshToken: token,
        expiresInDays: SESSION_DAYS
    });
});

app.post('/auth/refresh', async (request, response) => {
    const token = request.body?.refreshToken;
    const session = await findValidSession(token);

    if (!session) {
        return response.status(401).json({
            error: 'Session invalide ou expirée.'
        });
    }

    response.json({
        ok: true,
        expiresAt: session.expiresAt
    });
});

app.post('/auth/logout', async (request, response) => {
    const token = request.body?.refreshToken;

    if (token) {
        await query(
            'DELETE FROM sessions WHERE token_hash = $1',
            [hashToken(token)]
        );
    }

    response.json({ ok: true });
});

// ------------------------------------------------------------
// CATALOGUE DE MATERIEL
// ------------------------------------------------------------

app.get('/equipment-catalog', requireSession, async (request, response) => {
    const type = String(request.query.type || '').trim().toLowerCase();

    if (!['don', 'pret'].includes(type)) {
        return response.status(400).json({
            error: 'Le paramètre type doit être "don" ou "pret".'
        });
    }

    const result = await query(
        `
        SELECT category, model
        FROM equipment_catalog
        WHERE transaction_type = $1
          AND active = TRUE
        ORDER BY sort_order ASC, category ASC, model ASC
        `,
        [type]
    );

    const grouped = new Map();

    for (const row of result.rows) {
        if (!grouped.has(row.category)) {
            grouped.set(row.category, {
                category: row.category,
                models: []
            });
        }

        if (row.model) {
            grouped.get(row.category).models.push(row.model);
        }
    }

    response.json({
        ok: true,
        items: [...grouped.values()]
    });
});

// ------------------------------------------------------------
// TRANSMISSIONS
// ------------------------------------------------------------

app.get('/transmissions', requireSession, async (request, response) => {
    const search = String(request.query.q || '').trim();
    const daysRaw = request.query.days;
    const days = daysRaw === undefined ? null : Number(daysRaw);

    if (days !== null && (!Number.isInteger(days) || days <= 0 || days > 36500)) {
        return response.status(400).json({ error: 'Paramètre days invalide.' });
    }

    const conditions = [];
    const params = [];

    if (days !== null) {
        params.push(days);
        conditions.push(
            `created_at >= NOW() - ($${params.length}::integer * INTERVAL '1 day')`
        );
    }

    if (search) {
        params.push(`%${search}%`);
        conditions.push(`
            CONCAT_WS(
                ' ',
                type,
                equipment_type,
                COALESCE(equipment_model, ''),
                COALESCE(custom_equipment, ''),
                beneficiary,
                content,
                author,
                COALESCE(loan_status, ''),
                COALESCE(return_comment, '')
            ) ILIKE $${params.length}
        `);
    }

    const where = conditions.length > 0
        ? `WHERE ${conditions.join(' AND ')}`
        : '';

    const result = await query(
        `
        SELECT id, type, equipment_type, equipment_model, custom_equipment,
               quantity, beneficiary, content, author, author_id, loan_status,
               returned_at, returned_by, returned_by_id, return_comment,
               created_at, signer_name, signed_at,
               (signature_png IS NOT NULL) AS has_signature
        FROM transmissions
        ${where}
        ORDER BY created_at DESC
        `,
        params
    );

    response.json({
        ok: true,
        count: result.rowCount,
        items: result.rows.map(rowToTransmission)
    });
});

// Image privée : jamais une URL publique ni une donnée incluse dans les listes/exports.
app.get('/transmissions/:id/signature', requireSession, async (request, response) => {
    if (!signaturesEnabled) {
        return response.status(403).json({ error: 'Consultation des signatures désactivée.' });
    }
    const id = String(request.params.id || '');
    if (!/^[0-9a-f-]{36}$/i.test(id)) {
        return response.status(400).json({ error: 'Identifiant invalide.' });
    }
    const result = await query(
        'SELECT signature_png FROM transmissions WHERE id = $1 AND signature_png IS NOT NULL',
        [id]
    );
    if (result.rowCount === 0) {
        return response.status(404).json({ error: 'Signature introuvable.' });
    }
    response.setHeader('Cache-Control', 'private, no-store, max-age=0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.type('png').send(result.rows[0].signature_png);
});

app.post('/transmissions', requireSession, async (request, response) => {
    const type = String(request.body?.type || '').trim().toLowerCase();
    const equipmentType = String(request.body?.equipmentType || '').trim();
    const equipmentModel = String(request.body?.equipmentModel || '').trim();
    const customEquipment = String(request.body?.customEquipment || '').trim();
    const beneficiary = String(request.body?.beneficiary || '').trim();
    const content = String(request.body?.content || '').trim();
    const quantity = Number(request.body?.quantity);
    const signerName = String(request.body?.signerName ?? '').trim();
    const signatureBase64 = request.body?.signaturePngBase64;
    let signaturePng = null;

    // Valider en entrée ; ne jamais collecter les trajectoires, pressions ou vitesses du stylet.
    if (signatureBase64 != null && signatureBase64 !== '') {
        if (!signaturesEnabled) {
            return response.status(403).json({ error: 'Collecte des signatures non activée.' });
        }
        if (typeof signatureBase64 !== 'string' ||
            signatureBase64.length > 405000 ||
            !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(signatureBase64)) {
            return response.status(400).json({ error: 'Format de signature invalide.' });
        }
        signaturePng = Buffer.from(signatureBase64, 'base64');
        if (signaturePng.length < 65 ||
            signaturePng.length > MAX_SIGNATURE_BYTES ||
            !signaturePng.subarray(0, 8).equals(PNG_MAGIC)) {
            return response.status(400).json({ error: 'La signature doit être une image PNG valide (300 Ko max).' });
        }
        if (signerName.length < 2 || signerName.length > 120) {
            return response.status(400).json({ error: 'Nom du signataire requis (2 à 120 caractères).' });
        }
    } else if (signerName !== '') {
        return response.status(400).json({ error: 'Ajoutez une signature ou effacez le nom du signataire.' });
    }

    if (!['don', 'pret'].includes(type)) {
        return response.status(400).json({
            error: 'Le type doit être "don" ou "pret".'
        });
    }

    if (!equipmentType) {
        return response.status(400).json({
            error: 'Le matériel est obligatoire.'
        });
    }

    const catalog = await query(
        `
        SELECT category, model
        FROM equipment_catalog
        WHERE transaction_type = $1
          AND category = $2
          AND active = TRUE
        `,
        [type, equipmentType]
    );

    if (catalog.rowCount === 0) {
        return response.status(400).json({
            error: 'Le matériel sélectionné n’est pas présent dans le catalogue.'
        });
    }

    const availableModels = catalog.rows
        .map((row) => row.model)
        .filter(Boolean);

    if (availableModels.length > 0) {
        if (!equipmentModel) {
            return response.status(400).json({
                error: 'Sélectionnez un modèle pour ce matériel.'
            });
        }

        if (!availableModels.includes(equipmentModel)) {
            return response.status(400).json({
                error: 'Le modèle sélectionné n’est pas valide.'
            });
        }
    }

    if (equipmentType === 'Autre' && !customEquipment) {
        return response.status(400).json({
            error: 'Précisez le matériel lorsque vous choisissez "Autre".'
        });
    }

    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 999) {
        return response.status(400).json({
            error: 'La quantité doit être comprise entre 1 et 999.'
        });
    }

    if (!beneficiary) {
        return response.status(400).json({
            error: 'Le bénéficiaire est obligatoire.'
        });
    }

    if (
        equipmentModel.length > 80 ||
        customEquipment.length > 80 ||
        beneficiary.length > 120 ||
        content.length > 1000
    ) {
        return response.status(400).json({
            error: 'Une ou plusieurs valeurs dépassent la taille autorisée.'
        });
    }

    const loanStatus = type === 'pret' ? 'en_cours' : null;

    const result = await query(
        `
        INSERT INTO transmissions (
            id,
            type,
            equipment_type,
            equipment_model,
            custom_equipment,
            quantity,
            beneficiary,
            content,
            author,
            author_id,
            loan_status,
            signer_name,
            signature_png,
            signed_at,
            created_at
        )
        VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
            $12, $13, CASE WHEN $13::bytea IS NOT NULL THEN NOW() END, NOW()
        )
        RETURNING *
        `,
        [
            crypto.randomUUID(),
            type,
            equipmentType,
            availableModels.length > 0 ? equipmentModel : null,
            equipmentType === 'Autre' ? customEquipment : null,
            quantity,
            beneficiary,
            content,
            request.user.name || request.user.identifier,
            request.user.id,
            loanStatus,
            signaturePng == null ? null : signerName,
            signaturePng
        ]
    );

    response.status(201).json({
        ok: true,
        item: rowToTransmission(result.rows[0])
    });
});

app.patch('/transmissions/:id/return', requireSession, async (request, response) => {
    const id = String(request.params.id || '').trim();
    const rawReturnComment = request.body?.returnComment;

    if (rawReturnComment != null && typeof rawReturnComment !== 'string') {
        return response.status(400).json({ error: 'Le commentaire de retour doit être du texte.' });
    }

    const returnComment = String(rawReturnComment ?? '').trim();
    if (returnComment.length > 1000) {
        return response.status(400).json({ error: 'Le commentaire de retour est limité à 1000 caractères.' });
    }

    const result = await query(
        `
        UPDATE transmissions
        SET
            loan_status = 'rendu',
            returned_at = NOW(),
            returned_by = $2,
            returned_by_id = $3,
            return_comment = NULLIF($4, '')
        WHERE id = $1
          AND type = 'pret'
          AND (loan_status = 'en_cours' OR loan_status IS NULL)
        RETURNING *
        `,
        [
            id,
            request.user.name || request.user.identifier,
            request.user.id,
            returnComment
        ]
    );

    if (result.rowCount === 0) {
        return response.status(404).json({
            error: 'Prêt introuvable ou déjà rendu.'
        });
    }

    response.json({
        ok: true,
        item: rowToTransmission(result.rows[0])
    });
});

// ------------------------------------------------------------
// GESTION DES ERREURS
// ------------------------------------------------------------

app.use((error, request, response, next) => {
    console.error(error);

    if (response.headersSent) {
        return next(error);
    }

    response.status(500).json({
        error: 'Erreur interne du serveur.'
    });
});

// ------------------------------------------------------------
// START SERVER
// ------------------------------------------------------------

async function startServer() {
    await ensureDatabaseSchema();
    await checkDatabase();
    await query('DELETE FROM sessions WHERE expires_at <= NOW()');

    app.listen(PORT, '0.0.0.0', () => {
        console.log(
            `Digital-Logbook Auth démarré sur le port ${PORT} (${NODE_ENV})`
        );
        console.log('PostgreSQL connecté.');
        if (NODE_ENV === 'production') {
            console.log(
                `Origines Web autorisées : ${configuredCorsOrigins.join(', ') || 'aucune'}`
            );
        }
    });
}

startServer().catch((error) => {
    console.error('Impossible de démarrer le backend :', error);
    process.exit(1);
});
