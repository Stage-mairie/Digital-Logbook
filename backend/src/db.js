import fs from 'fs/promises';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';

const { Pool } = pg;

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendRoot = path.resolve(__dirname, '..');

const isProduction = (process.env.NODE_ENV || 'development') === 'production';
const ssl = String(process.env.DB_SSL || '').toLowerCase() === 'true'
    ? { rejectUnauthorized: false }
    : false;

if (isProduction && !process.env.DATABASE_URL && !process.env.DB_PASSWORD) {
    throw new Error(
        'Configuration PostgreSQL de production incomplète : DB_PASSWORD ou DATABASE_URL manquant.'
    );
}

const commonPoolConfig = {
    max: Number(process.env.DB_POOL_MAX || 10),
    idleTimeoutMillis: Number(process.env.DB_IDLE_TIMEOUT_MS || 30000),
    connectionTimeoutMillis: Number(process.env.DB_CONNECT_TIMEOUT_MS || 5000),
    application_name: 'digital-logbook'
};

const poolConfig = process.env.DATABASE_URL
    ? {
        ...commonPoolConfig,
        connectionString: process.env.DATABASE_URL,
        ssl
    }
    : {
        ...commonPoolConfig,
        host: process.env.DB_HOST || '127.0.0.1',
        port: Number(process.env.DB_PORT || 5432),
        database: process.env.DB_NAME || 'digital_logbook',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || '',
        ssl
    };

export const pool = new Pool(poolConfig);

pool.on('error', (error) => {
    console.error('Erreur PostgreSQL inattendue :', error);
});

export async function query(text, params = []) {
    return pool.query(text, params);
}

export async function checkDatabase() {
    await query('SELECT 1');
}

export async function runSqlFile(relativePath) {
    const filePath = path.join(backendRoot, relativePath);
    const sql = await fs.readFile(filePath, 'utf8');
    await query(sql);
}

export async function ensureDatabaseSchema() {
    await runSqlFile(path.join('sql', '001_schema.sql'));
}
