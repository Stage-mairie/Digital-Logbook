import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import dotenv from 'dotenv';
import argon2 from 'argon2';

dotenv.config();

const secret =
    process.env.VAULT_SECRET;

if (!secret) {

    throw new Error(
        'VAULT_SECRET manquant.'
    );
}

const key =
    crypto
        .createHash('sha256')
        .update(secret)
        .digest();

function encrypt(text) {

    const iv =
        crypto.randomBytes(12);

    const cipher =
        crypto.createCipheriv(
            'aes-256-gcm',
            key,
            iv
        );

    const data =
        Buffer.concat([

            cipher.update(
                text,
                'utf8'
            ),

            cipher.final()
        ]);

    return JSON.stringify({

        iv:
            iv.toString('base64'),

        tag:
            cipher
                .getAuthTag()
                .toString('base64'),

        data:
            data.toString('base64')
    });
}

// ------------------------------------------------------------
// COMPTES INITIAUX
//
// Les mots de passe sont transformés en Argon2id.
// Ils ne sont PAS enregistrés en clair dans le vault.
// ------------------------------------------------------------

const users = [

    {

        id:
            'user-001',

        identifier:
            'terrain',

        name:
            'Compte terrain',

        passwordHash:
            await argon2.hash(
                'Terrain2026!',
                {
                    type:
                        argon2.argon2id
                }
            )
    },

    {

        id:
            'user-002',

        identifier:
            'admin',

        name:
            'Administrateur',

        passwordHash:
            await argon2.hash(
                'Admin2026!',
                {
                    type:
                        argon2.argon2id
                }
            )
    }
];

const vault = {

    version:
        1,

    users
};

const output =
    path.resolve(
        'vault/users.vault.enc'
    );

fs.mkdirSync(
    path.dirname(output),
    {
        recursive: true
    }
);

fs.writeFileSync(

    output,

    encrypt(
        JSON.stringify(
            vault,
            null,
            2
        )
    )
);

console.log('');
console.log(
    '================================'
);
console.log(
    'VAULT CREE AVEC SUCCES'
);
console.log(
    '================================'
);
console.log('');

console.log(
    'Compte terrain :'
);

console.log(
    'identifiant = terrain'
);

console.log(
    'mot de passe = Terrain2026!'
);

console.log('');

console.log(
    'Compte administrateur :'
);

console.log(
    'identifiant = admin'
);

console.log(
    'mot de passe = Admin2026!'
);

console.log('');
