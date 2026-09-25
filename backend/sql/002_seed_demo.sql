-- Fausses données de démonstration.
-- Le script est rejouable : les UUID fixes évitent les doublons.

INSERT INTO transmissions (
    id, type, equipment_type, equipment_model, custom_equipment,
    quantity, beneficiary, content, author, author_id,
    loan_status, returned_at, returned_by, returned_by_id, created_at
)
VALUES
    (
        '10000000-0000-0000-0000-000000000001',
        'don', 'Toner', 'E-STUDIO2518A', NULL,
        2, 'Service État civil', 'Toners noirs remis pour l’imprimante du guichet principal.',
        'Compte démo', 'demo', NULL, NULL, NULL, NULL,
        NOW() - INTERVAL '1 day'
    ),
    (
        '10000000-0000-0000-0000-000000000002',
        'don', 'Souris', NULL, NULL,
        4, 'Service Ressources humaines', 'Souris USB filaires.',
        'Compte démo', 'demo', NULL, NULL, NULL, NULL,
        NOW() - INTERVAL '2 days'
    ),
    (
        '10000000-0000-0000-0000-000000000003',
        'don', 'Toner', 'E-STUDIO6516AC', NULL,
        1, 'Direction générale', 'Remplacement du toner de l’étage.',
        'Compte démo', 'demo', NULL, NULL, NULL, NULL,
        NOW() - INTERVAL '5 days'
    ),
    (
        '10000000-0000-0000-0000-000000000004',
        'pret', 'VPJ', NULL, NULL,
        1, 'Salle du Conseil', 'Vidéoprojecteur prêté pour une réunion.',
        'Compte démo', 'demo', 'en_cours', NULL, NULL, NULL,
        NOW() - INTERVAL '1 day'
    ),
    (
        '10000000-0000-0000-0000-000000000005',
        'pret', 'Chargeur USB-C', NULL, NULL,
        1, 'Service Communication', 'Chargeur 65 W prêté avec câble.',
        'Compte démo', 'demo', 'rendu', NOW() - INTERVAL '1 day', 'Compte démo', 'demo',
        NOW() - INTERVAL '4 days'
    ),
    (
        '10000000-0000-0000-0000-000000000006',
        'pret', 'Airbox', NULL, NULL,
        1, 'Équipe évènementiel', 'Airbox utilisée lors d’un évènement extérieur.',
        'Compte démo', 'demo', 'en_cours', NULL, NULL, NULL,
        NOW() - INTERVAL '10 days'
    ),
    (
        '10000000-0000-0000-0000-000000000007',
        'don', 'Autre', NULL, 'Bac de récupération',
        1, 'Service Reprographie', 'Bac de récupération remplacé ; référence notée sur le matériel.',
        'Compte démo', 'demo', NULL, NULL, NULL, NULL,
        NOW() - INTERVAL '18 days'
    ),
    (
        '10000000-0000-0000-0000-000000000008',
        'pret', 'Ordinateur', NULL, NULL,
        1, 'Service Finances', 'PC portable avec chargeur et sacoche.',
        'Compte démo', 'demo', 'rendu', NOW() - INTERVAL '20 days', 'Compte démo', 'demo',
        NOW() - INTERVAL '28 days'
    )
ON CONFLICT (id) DO NOTHING;
