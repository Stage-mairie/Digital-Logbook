import express from 'express';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import argon2 from 'argon2';

dotenv.config();

const app = express();

app.use(express.json());

const PORT =
    Number(process.env.PORT || 3000);

const SESSION_DAYS =
    Number(process.env.SESSION_DAYS || 180);

const SECRET =
    process.env.VAULT_SECRET;

if (!SECRET) {

    throw new Error(
        'VAULT_SECRET manquant dans .env'
    );
}

// ------------------------------------------------------------
// CLE DE CHIFFREMENT
// ------------------------------------------------------------

const encryptionKey =
    crypto
        .createHash('sha256')
        .update(SECRET)
        .digest();

// ------------------------------------------------------------
// FICHIERS
// ------------------------------------------------------------

const vaultPath =
    path.resolve(
        'vault/users.vault.enc'
    );

const sessionsPath =
    path.resolve(
        'data/sessions.json'
    );

// ------------------------------------------------------------
// AES-256-GCM
// ------------------------------------------------------------

function encrypt(text) {

    const iv =
        crypto.randomBytes(12);

    const cipher =
        crypto.createCipheriv(
            'aes-256-gcm',
            encryptionKey,
            iv
        );

    const encrypted =
        Buffer.concat([
            cipher.update(
                text,
                'utf8'
            ),
            cipher.final()
        ]);

    const tag =
        cipher.getAuthTag();

    return JSON.stringify({

        iv:
            iv.toString('base64'),

        tag:
            tag.toString('base64'),

        data:
            encrypted.toString('base64')
    });
}

function decrypt(payload) {

    const object =
        JSON.parse(payload);

    const decipher =
        crypto.createDecipheriv(
            'aes-256-gcm',
            encryptionKey,
            Buffer.from(
                object.iv,
                'base64'
            )
        );

    decipher.setAuthTag(
        Buffer.from(
            object.tag,
            'base64'
        )
    );

    return Buffer.concat([

        decipher.update(
            Buffer.from(
                object.data,
                'base64'
            )
        ),

        decipher.final()

    ]).toString('utf8');
}

// ------------------------------------------------------------
// VAULT
// ------------------------------------------------------------

function readVault() {

    return JSON.parse(
        decrypt(
            fs.readFileSync(
                vaultPath,
                'utf8'
            )
        )
    );
}

// ------------------------------------------------------------
// SESSIONS
// ------------------------------------------------------------

function readSessions() {

    if (!fs.existsSync(
        sessionsPath
    )) {

        return {};
    }

    return JSON.parse(
        fs.readFileSync(
            sessionsPath,
            'utf8'
        )
    );
}

function writeSessions(
    sessions
) {

    fs.mkdirSync(
        path.dirname(
            sessionsPath
        ),
        {
            recursive: true
        }
    );

    fs.writeFileSync(

        sessionsPath,

        JSON.stringify(
            sessions,
            null,
            2
        )
    );
}

// ------------------------------------------------------------
// TOKEN
// ------------------------------------------------------------

function hashToken(
    token
) {

    return crypto
        .createHash('sha256')
        .update(token)
        .digest('hex');
}

function generateToken() {

    return crypto
        .randomBytes(48)
        .toString('base64url');
}

// ------------------------------------------------------------
// HEALTH CHECK
// ------------------------------------------------------------

app.get(
    '/health',
    (_, response) => {

        response.json({

            ok: true,

            service:
                'Digital-Logbook Auth'
        });
    }
);

// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------

app.post(
    '/auth/login',
    async (request, response) => {

        const {
            identifier,
            password
        } = request.body || {};

        if (!identifier ||
            !password) {

            return response
                .status(400)
                .json({

                    error:
                        'Identifiant et mot de passe requis.'
                });
        }

        const vault =
            readVault();

        const user =
            vault.users.find(

                item =>
                    item.identifier
                        .toLowerCase()
                    ===
                    String(identifier)
                        .toLowerCase()
            );

        if (!user) {

            return response
                .status(401)
                .json({

                    error:
                        'Identifiants invalides.'
                });
        }

        const passwordValid =
            await argon2.verify(
                user.passwordHash,
                password
            );

        if (!passwordValid) {

            return response
                .status(401)
                .json({

                    error:
                        'Identifiants invalides.'
                });
        }

        // Token aléatoire.
        const token =
            generateToken();

        const sessions =
            readSessions();

        // On ne stocke jamais le token
        // en clair côté serveur.

        sessions[
            hashToken(token)
        ] = {

            userId:
                user.id,

            createdAt:
                Date.now(),

            expiresAt:
                Date.now()
                +
                SESSION_DAYS
                *
                24
                *
                60
                *
                60
                *
                1000
        };

        writeSessions(
            sessions
        );

        response.json({

            ok: true,

            user: {

                id:
                    user.id,

                identifier:
                    user.identifier,

                name:
                    user.name
            },

            refreshToken:
                token,

            expiresInDays:
                SESSION_DAYS
        });
    }
);

// ------------------------------------------------------------
// REFRESH SESSION
// ------------------------------------------------------------

app.post(
    '/auth/refresh',
    (request, response) => {

        const token =
            request.body?.refreshToken;

        if (!token) {

            return response
                .status(401)
                .json({

                    error:
                        'Token manquant.'
                });
        }

        const sessions =
            readSessions();

        const tokenKey =
            hashToken(token);

        const session =
            sessions[tokenKey];

        if (!session) {

            return response
                .status(401)
                .json({

                    error:
                        'Session invalide.'
                });
        }

        if (
            session.expiresAt
            <=
            Date.now()
        ) {

            delete sessions[
                tokenKey
            ];

            writeSessions(
                sessions
            );

            return response
                .status(401)
                .json({

                    error:
                        'Session expirée.'
                });
        }

        response.json({

            ok: true,

            expiresAt:
                session.expiresAt
        });
    }
);

// ------------------------------------------------------------
// LOGOUT
// ------------------------------------------------------------

app.post(
    '/auth/logout',
    (request, response) => {

        const token =
            request.body?.refreshToken;

        if (token) {

            const sessions =
                readSessions();

            delete sessions[
                hashToken(token)
            ];

            writeSessions(
                sessions
            );
        }

        response.json({
            ok: true
        });
    }
);

// ------------------------------------------------------------
// START SERVER
// ------------------------------------------------------------

app.listen(
    PORT,
    () => {

        console.log(
            `Digital-Logbook Auth démarré sur http://localhost:${PORT}`
        );
    }
);
