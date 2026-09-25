import dotenv from 'dotenv';
import { ensureDatabaseSchema, pool } from './db.js';

dotenv.config();

try {
    await ensureDatabaseSchema();
    console.log('Schéma PostgreSQL initialisé.');
} finally {
    await pool.end();
}
