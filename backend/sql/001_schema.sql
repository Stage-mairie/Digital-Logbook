CREATE TABLE IF NOT EXISTS equipment_catalog (
    id BIGSERIAL PRIMARY KEY,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('don', 'pret')),
    category TEXT NOT NULL,
    model TEXT NOT NULL DEFAULT '',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 100,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (transaction_type, category, model)
);


CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_expires_at_idx
    ON sessions (expires_at);

CREATE TABLE IF NOT EXISTS transmissions (
    id UUID PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('don', 'pret')),
    equipment_type TEXT NOT NULL,
    equipment_model TEXT,
    custom_equipment TEXT,
    quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 999),
    beneficiary TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    author TEXT NOT NULL,
    author_id TEXT NOT NULL,
    loan_status TEXT,
    returned_at TIMESTAMPTZ,
    returned_by TEXT,
    returned_by_id TEXT,
    return_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT transmissions_loan_status_check CHECK (
        (type = 'don' AND loan_status IS NULL)
        OR
        (type = 'pret' AND loan_status IN ('en_cours', 'rendu'))
    )
);

-- Migration idempotente pour les bases déjà initialisées.
ALTER TABLE transmissions ADD COLUMN IF NOT EXISTS return_comment TEXT;

-- Signature d'accusé de remise : image PNG statique uniquement (aucune biométrie dynamique).
-- Colonnes nullable pour conserver la compatibilité avec les opérations existantes.
ALTER TABLE transmissions ADD COLUMN IF NOT EXISTS signature_png BYTEA;
ALTER TABLE transmissions ADD COLUMN IF NOT EXISTS signer_name TEXT;
ALTER TABLE transmissions ADD COLUMN IF NOT EXISTS signed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS transmissions_created_at_idx
    ON transmissions (created_at DESC);

CREATE INDEX IF NOT EXISTS transmissions_type_idx
    ON transmissions (type);

CREATE INDEX IF NOT EXISTS transmissions_loan_status_idx
    ON transmissions (loan_status)
    WHERE type = 'pret';

-- Compatibilité avec d'anciennes données créées avant l'ajout du statut de prêt.
-- Un prêt sans statut est considéré comme étant encore en cours.
UPDATE transmissions
SET loan_status = 'en_cours'
WHERE type = 'pret'
  AND loan_status IS NULL;

-- Suggestions partagees entre le Web et les tablettes.
CREATE TABLE IF NOT EXISTS person_suggestions (
    id BIGSERIAL PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('beneficiary', 'signer')),
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 120),
    normalized_name TEXT GENERATED ALWAYS AS (
        lower(regexp_replace(btrim(name), '\s+', ' ', 'g'))
    ) STORED,
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (kind, normalized_name)
);

CREATE INDEX IF NOT EXISTS person_suggestions_recent_idx
    ON person_suggestions (kind, last_used_at DESC);

-- Memorise les noms dans la transaction de creation.
CREATE OR REPLACE FUNCTION remember_transmission_people()
RETURNS TRIGGER AS $$
BEGIN
    IF char_length(btrim(NEW.beneficiary)) BETWEEN 2 AND 120 THEN
        INSERT INTO person_suggestions (kind, name)
        VALUES ('beneficiary', regexp_replace(btrim(NEW.beneficiary), '\s+', ' ', 'g'))
        ON CONFLICT (kind, normalized_name)
        DO UPDATE SET last_used_at = NOW();
    END IF;

    IF NEW.signature_png IS NOT NULL AND NEW.signer_name IS NOT NULL
       AND char_length(btrim(NEW.signer_name)) BETWEEN 2 AND 120 THEN
        INSERT INTO person_suggestions (kind, name)
        VALUES ('signer', regexp_replace(btrim(NEW.signer_name), '\s+', ' ', 'g'))
        ON CONFLICT (kind, normalized_name)
        DO UPDATE SET last_used_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER transmissions_remember_people
AFTER INSERT ON transmissions
FOR EACH ROW EXECUTE FUNCTION remember_transmission_people();

-- Recuperation des noms des transmissions existantes.
INSERT INTO person_suggestions (kind, name)
SELECT 'beneficiary', regexp_replace(btrim(beneficiary), '\s+', ' ', 'g')
FROM transmissions
WHERE char_length(btrim(beneficiary)) BETWEEN 2 AND 120
ON CONFLICT (kind, normalized_name) DO NOTHING;

INSERT INTO person_suggestions (kind, name)
SELECT 'signer', regexp_replace(btrim(signer_name), '\s+', ' ', 'g')
FROM transmissions
WHERE signature_png IS NOT NULL
  AND signer_name IS NOT NULL
  AND char_length(btrim(signer_name)) BETWEEN 2 AND 120
ON CONFLICT (kind, normalized_name) DO NOTHING;

-- Catalogue des dons
INSERT INTO equipment_catalog (transaction_type, category, model, sort_order)
VALUES
    ('don', 'Toner', 'E-STUDIO2518A', 10),
    ('don', 'Toner', 'E-STUDIO2515A', 11),
    ('don', 'Toner', 'E-STUDIO6516AC', 12),
    ('don', 'Souris', '', 20),
    ('don', 'Clavier', '', 30),
    ('don', 'Ordinateur', '', 40),
    ('don', 'Casque audio TT', '', 50),
    ('don', 'Autre', '', 90)
ON CONFLICT (transaction_type, category, model) DO NOTHING;

-- Les bacs de récupération restent volontairement hors catalogue pour le moment.
-- Utiliser "Autre" et préciser la référence dans le champ libre / commentaire.
-- Quand les références exactes seront stabilisées, elles pourront être ajoutées ici
-- sans republier l'application Flutter.

-- Catalogue des prêts
INSERT INTO equipment_catalog (transaction_type, category, model, sort_order)
VALUES
    ('pret', 'Clé', '', 10),
    ('pret', 'VPJ', '', 20),
    ('pret', 'Chargeur ordinateur', '', 30),
    ('pret', 'Chargeur USB-C', '', 40),
    ('pret', 'Ordinateur', '', 50),
    ('pret', 'Airbox', '', 60),
    ('pret', 'Flybox', '', 70),
    ('pret', 'Enrouleur', '', 80),
    ('pret', 'Téléphone', '', 85),
    ('pret', 'Autre', '', 90)
ON CONFLICT (transaction_type, category, model) DO NOTHING;
