definitions = {
    'SK': [
        {'code': 'CRF2',  # vnitřní graf, políčko 1                 PRŮMYSLOVÉ PROCESY
         'label': 'Průmyslové procesy (výroba cementu, oceli...)',
         'sum': ['CRF2'],
         'color': '#8A2BE2',
         'breakdown': [
             {'code': 'CRF2C',  # vnější graf políčko 1.1
              'label': 'Zpracování oceli a kovů',
              'color': '#68228B',
              'sum': ['CRF2C']},
             {'code': 'CRF2A',  # vnější graf políčko 1.2
              'label': 'Minerální produkce (cement, vápno...)',
              'color': '#9A32CD',
              'sum': ['CRF2A']},
             {'code': 'CRF2B',  # vnější graf políčko 1.3
              'label': 'Chemický průmysl',
              'color': '#B23AEE',
              'sum': ['CRF2B']},
             {'code': 'CRF2_dif',  # vnější graf políčko 1.3 - rozdíl
              'label': 'Další průmyslové procesy',
              'color': '#BF3EFF',
              'reminder': True}]},
        {'code': 'CRF1A3_CRF1D1A',  # vnitřní graf, políčko 2         DOPRAVA
         'label': 'Doprava (včetně letecké)',
         'sum': ['CRF1A3', 'CRF1D1A'],
         'color': '#B22222',
         'breakdown': [
             {'code': 'CRF1A3B1',  # vnější graf políčko 2.1
              'label': 'Osobní automobilová doprava',
              'color': '#8B1A1A',
              'sum': ['CRF1A3B1']},
             {'code': 'CRF1A3B2_CRF1A3B3',  # vnější graf políčko 2.2
              'label': 'Nákladní a autobusová doprava',
              'color': '#CD2626',
              'sum': ['CRF1A3B2', 'CRF1A3B3']},
             {'code': 'CRF1D1A_CRF1A3A',  # vnější graf políčko 2.3
              'label': 'Letecká doprava',
              'color': '#EE2C2C',
              'sum': ['CRF1D1A', 'CRF1A3A']},
             {'code': 'CRF1A3_dif',  # vnější graf políčko 2.4 - rozdíl
              'label': 'Jiná doprava',
              'color': '#FF3030',
              'reminder': True}]},
        {'code': 'CRF1A2',  # vnitřní graf, políčko 3                 SPALOVÁNÍ V PRŮMYSLU
         'label': 'Spalování v průmyslu',
         'sum': ['CRF1A2'],
         'color': '#009ACD',
         'breakdown': [
             {'code': 'CRF1A2A_CRF1A2B',  # vnější graf políčko 3.1
              'label': 'Spalování při zpracování oceli a kovů',
              'color': '#00688B',
              'sum': ['CRF1A2A', 'CRF1A2B']},
             {'code': 'CRF1A2_dil',  # vnější graf políčko 3.2 - rozdíl
              'label': 'Další spalování v průmyslu',
              'color': '#00B2EE',
              'reminder': True}]},
        {'code': 'CRF1A1',  # vnitřní graf, políčko 4                 ENERGETIKA
         'label': 'Energetika',
         'sum': ['CRF1A1'],
         'color': '#FF4500',
         'breakdown': [
             {'code': 'CRF1A1C_CRF1A1B',  # vnější graf políčko 4.1
              'label': 'Rafinace, výroba a úprava paliv',
              'color': '#CD3700',
              'sum': ['CRF1A1C', 'CRF1A1B']},
             {'code': 'CRF1A2_dif_X',  # vnější graf políčko 4.2 - rozdíl
              'label': 'Teplárny a elektrárny',
              'color': '#EE4000',
              'reminder': True}]},
        {'code': 'CRF1A4',  # vnitřní graf, políčko 5                 SPALOVÁNÍ V DOM, INST A ZEMĚĎ
         'label': 'Spalování v domácnostech, institucích a zemědělství',
         'sum': ['CRF1A4'],
         'color': '#6495ED'},
        {'code': 'CRF3',  # vnitřní graf, políčko 6                   ZEMĚDĚLSTVÍ
         'label': 'Zemědělství',
         'sum': ['CRF3'],
         'color': '#48D1CC'},
        {'code': 'CRF5',  # vnitřní graf, políčko 7                   ODPADOVÉ HOSPODÁŘSTVÍ
         'label': 'Odpadové hospodářství',
         'sum': ['CRF5'],
         'color': '#3CB371'},
        {'code': 'TOTAL_DIF',  # vnitřní graf, políčko 8                   JINÉ
         'label': 'Jiné',
         'color': '#FFD700',
         'reminder': True}
    ],
    'CZ': [
        {'code': 'CRF1A1',  # vnitřní graf, políčko 4                 ENERGETIKA
         'label': 'Energetika',
         'sum': ['CRF1A1'],
         'color': '#FF4500',
         'breakdown': [
             {'code': 'CRF1A1C_CRF1A1B',  # vnější graf políčko 4.1
              'label': 'Rafinace, výroba a úprava paliv',
              'color': '#CD3700',
              'sum': ['CRF1A1C', 'CRF1A1B']},
             {'code': 'CRF1A2_dif_X',  # vnější graf políčko 4.2 - rozdíl
              'label': 'Teplárny a elektrárny',
              'color': '#EE4000',
              'reminder': True}]},
        {'code': 'CRF1A3_CRF1D1A',  # vnitřní graf, políčko 2         DOPRAVA
         'label': 'Doprava (včetně letecké)',
         'sum': ['CRF1A3', 'CRF1D1A'],
         'color': '#B22222',
         'breakdown': [
             {'code': 'CRF1A3B1',  # vnější graf políčko 2.1
              'label': 'Osobní automobilová doprava',
              'color': '#8B1A1A',
              'sum': ['CRF1A3B1']},
             {'code': 'CRF1A3B2_CRF1A3B3',  # vnější graf políčko 2.2
              'label': 'Nákladní a autobusová doprava',
              'color': '#CD2626',
              'sum': ['CRF1A3B2', 'CRF1A3B3']},
             {'code': 'CRF1D1A_CRF1A3A',  # vnější graf políčko 2.3
              'label': 'Letecká doprava',
              'color': '#EE2C2C',
              'sum': ['CRF1D1A', 'CRF1A3A']},
             {'code': 'CRF1A3_dif',  # vnější graf políčko 2.4 - rozdíl
              'label': 'Jiná doprava',
              'color': '#FF3030',
              'reminder': True}]},
        {'code': 'CRF2',  # vnitřní graf, políčko 1                 PRŮMYSLOVÉ PROCESY
         'label': 'Průmyslové procesy (výroba cementu, oceli...)',
         'sum': ['CRF2'],
         'color': '#8A2BE2',
         'breakdown': [
             {'code': 'CRF2C',  # vnější graf políčko 1.1
              'label': 'Zpracování oceli a kovů',
              'color': '#68228B',
              'sum': ['CRF2C']},
             {'code': 'CRF2A',  # vnější graf políčko 1.2
              'label': 'Minerální produkce (cement, vápno...)',
              'color': '#9A32CD',
              'sum': ['CRF2A']},
             {'code': 'CRF2B',  # vnější graf políčko 1.3
              'label': 'Chemický průmysl',
              'color': '#B23AEE',
              'sum': ['CRF2B']},
             {'code': 'CRF2_dif',  # vnější graf políčko 1.3 - rozdíl
              'label': 'Další průmyslové procesy',
              'color': '#BF3EFF',
              'reminder': True}]},
        {'code': 'CRF1A2',  # vnitřní graf, políčko 3                 SPALOVÁNÍ V PRŮMYSLU
         'label': 'Spalování v průmyslu',
         'sum': ['CRF1A2'],
         'color': '#009ACD',
         'breakdown': [
             {'code': 'CRF1A2A_CRF1A2B',  # vnější graf políčko 3.1
              'label': 'Spalování při zpracování oceli a kovů',
              'color': '#00688B',
              'sum': ['CRF1A2A', 'CRF1A2B']},
             {'code': 'CRF1A2_dil',  # vnější graf políčko 3.2 - rozdíl
              'label': 'Další spalování v průmyslu',
              'color': '#00B2EE',
              'reminder': True}]},
        {'code': 'CRF1A4',  # vnitřní graf, políčko 5                 SPALOVÁNÍ V DOM, INST A ZEMĚĎ
         'label': 'Spalování v domácnostech, institucích a zemědělství',
         'sum': ['CRF1A4'],
         'color': '#6495ED'},
        {'code': 'CRF3',  # vnitřní graf, políčko 6                   ZEMĚDĚLSTVÍ
         'label': 'Zemědělství',
         'sum': ['CRF3'],
         'color': '#48D1CC'},
        {'code': 'CRF5',  # vnitřní graf, políčko 7                   ODPADOVÉ HOSPODÁŘSTVÍ
         'label': 'Odpadové hospodářství',
         'sum': ['CRF5'],
         'color': '#3CB371'},
        {'code': 'TOTAL_DIF',  # vnitřní graf, políčko 8                   JINÉ
         'label': 'Jiné',
         'color': '#FFD700',
         'reminder': True}
    ],
'EU_28': [
        {'code': 'CRF1A1',  # vnitřní graf, políčko 4                 ENERGETIKA
         'label': 'Energetika',
         'sum': ['CRF1A1'],
         'color': '#FF4500',
         'breakdown': [
             {'code': 'CRF1A1C_CRF1A1B',  # vnější graf políčko 4.1
              'label': 'Rafinace, výroba a úprava paliv',
              'color': '#CD3700',
              'sum': ['CRF1A1C', 'CRF1A1B']},
             {'code': 'CRF1A2_dif_X',  # vnější graf políčko 4.2 - rozdíl
              'label': 'Teplárny a elektrárny',
              'color': '#EE4000',
              'reminder': True}]},
        {'code': 'CRF1A3_CRF1D1A',  # vnitřní graf, políčko 2         DOPRAVA
         'label': 'Doprava (včetně letecké)',
         'sum': ['CRF1A3', 'CRF1D1A'],
         'color': '#B22222',
         'breakdown': [
             {'code': 'CRF1A3B1',  # vnější graf políčko 2.1
              'label': 'Osobní automobilová doprava',
              'color': '#8B1A1A',
              'sum': ['CRF1A3B1']},
             {'code': 'CRF1A3B2_CRF1A3B3',  # vnější graf políčko 2.2
              'label': 'Nákladní a autobusová doprava',
              'color': '#CD2626',
              'sum': ['CRF1A3B2', 'CRF1A3B3']},
             {'code': 'CRF1D1A_CRF1A3A',  # vnější graf políčko 2.3
              'label': 'Letecká doprava',
              'color': '#EE2C2C',
              'sum': ['CRF1D1A', 'CRF1A3A']},
             {'code': 'CRF1A3_dif',  # vnější graf políčko 2.4 - rozdíl
              'label': 'Jiná doprava',
              'color': '#FF3030',
              'reminder': True}]},
        {'code': 'CRF1A4',  # vnitřní graf, políčko 5                 SPALOVÁNÍ V DOM, INST A ZEMĚĎ
         'label': 'Spalování v domácnostech, institucích a zemědělství',
         'sum': ['CRF1A4'],
         'color': '#6495ED'},
        {'code': 'CRF1A2',  # vnitřní graf, políčko 3                 SPALOVÁNÍ V PRŮMYSLU
         'label': 'Spalování v průmyslu',
         'sum': ['CRF1A2'],
         'color': '#009ACD'},
        {'code': 'CRF3',  # vnitřní graf, políčko 6                   ZEMĚDĚLSTVÍ
         'label': 'Zemědělství',
         'sum': ['CRF3'],
         'color': '#48D1CC'},
        {'code': 'CRF2',  # vnitřní graf, políčko 1                 PRŮMYSLOVÉ PROCESY
         'label': 'Průmyslové procesy (výroba cementu, oceli...)',
         'sum': ['CRF2'],
         'color': '#8A2BE2'},
        {'code': 'CRF5',  # vnitřní graf, políčko 7                   ODPADOVÉ HOSPODÁŘSTVÍ
         'label': 'Odpadové hospodářství',
         'sum': ['CRF5'],
         'color': '#3CB371'},
        {'code': 'TOTAL_DIF',  # vnitřní graf, políčko 8                   JINÉ
         'label': 'Jiné',
         'color': '#FFD700',
         'reminder': True}
    ],
}
