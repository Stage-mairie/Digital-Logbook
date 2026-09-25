import dotenv from 'dotenv';
import { ensureDatabaseSchema, pool, runSqlFile } from './db.js';

dotenv.config();

try {
    await ensureDatabaseSchema();
    await runSqlFile('sql/002_seed_demo.sql');
    console.log('Fausses données PostgreSQL ajoutées.');
} finally {
    await pool.end();
}
