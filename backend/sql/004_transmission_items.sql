-- Extension additive : une transmission = plusieurs matériels et accessoires.
-- Aucun DROP / TRUNCATE / suppression des transmissions existantes.
CREATE TABLE IF NOT EXISTS transmission_items (
    transmission_id UUID NOT NULL REFERENCES transmissions(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL CHECK (line_number BETWEEN 0 AND 19),
    equipment_type TEXT NOT NULL CHECK (char_length(btrim(equipment_type)) BETWEEN 1 AND 80),
    equipment_model TEXT,
    custom_equipment TEXT,
    quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 999),
    PRIMARY KEY (transmission_id, line_number)
);

-- Tous les anciens dons et prêts deviennent une transmission à une seule ligne.
-- ON CONFLICT rend cette migration rejouable, même après redémarrage.
INSERT INTO transmission_items (
    transmission_id, line_number, equipment_type, equipment_model, custom_equipment, quantity
)
SELECT id, 0, equipment_type, equipment_model, custom_equipment, quantity
FROM transmissions
ON CONFLICT (transmission_id, line_number) DO NOTHING;
