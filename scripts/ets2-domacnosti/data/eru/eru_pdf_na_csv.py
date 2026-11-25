# eru_pdf_na_csv.py – převod PDF ERÚ „Výsledné ceny tepelné energie v ČR – <rok>“ na CSV (jedna řádka = cenová lokalita).
# Zdroj: https://eru.gov.cz/vysledne-ceny-tepelne-energie-v-cr-2024 (PDF z Excelu, tabulka na 51 stranách).
# Spuštění: python3 eru_pdf_na_csv.py <vstup.pdf> <vystup.csv>    (potřebuje balíček pdfplumber)
# Jde jen o přípravu dat (PDF -> tabulka); veškeré výpočty dělá R (09_silc_archetypy.R).
import sys, csv, pdfplumber

UROVNE = ["vyroba_nad_10MW", "vyroba_do_10MW", "tuv_na_zdroji", "primarni_rozvod", "cvs",
          "tuv_na_cvs", "blokova_kotelna", "sekundarni_rozvody", "domovni_predavaci_stanice", "domovni_kotelna"]
HLAVICKA = (["lokalita", "kraj", "uhli_pct", "plyn_pct", "biomasa_oze_pct", "odpady_pct", "jina_pct",
             "vykon_mwt", "odberatelu", "odbernych_mist"]
            + [f"{u}_{x}" for u in UROVNE for x in ("cena_kc_gj", "mnozstvi_gj")])

def cislo(x):
    x = (x or "").replace(" ", "").replace(" ", "").replace(",", ".").strip()
    return x

vstup, vystup = sys.argv[1], sys.argv[2]
radky = []
with pdfplumber.open(vstup) as pdf:
    for pg in pdf.pages:
        for tab in pg.extract_tables():
            for r in tab:
                if not r or len(r) != 30 or not r[0] or r[0].startswith(("Ceny tepelné", "Cenová lokalita")):
                    continue
                radky.append([r[0].replace("\n", " ").strip(), (r[1] or "").strip()] + [cislo(x) for x in r[2:]])
with open(vystup, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(HLAVICKA); w.writerows(radky)
print(f"{len(radky)} lokalit -> {vystup}")
