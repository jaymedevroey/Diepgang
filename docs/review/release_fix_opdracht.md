# Release-audit: opdracht voor de bouwers

Jayme wil dat **alle bevindingen** van de release-audit aangepakt worden. Morgen doet hij de audit opnieuw, met dezelfde lat: een publieke Steam-demo.

- **Bevindingen in detail:** `logs/review/<rol>/rapport.md`. Daar staat ook het bewijs.
- **Samenvatting:** [release_audit.md](release_audit.md).
- **Verdeling per pakket:** [release_audit_voortgang.md](release_audit_voortgang.md).

## Je pakket

- Je werkt in je eigen worktree. Je bevindingen staan in je opdracht.
- **Lees eerst:**
  - `CLAUDE.md`;
  - de bovenste secties van `tasks/lessons.md`;
  - je bevindingen in de rapporten, inclusief het bewijs (bekijk de beelden).
- **Je bestanden.** Je pakket heeft eigen bestanden.
  - Moet je in een bestand van een ander pakket? Hou het dan bij een kleine, afgebakende toevoeging en meld het.
  - De andere pakketten werken tegelijk, en de lead voegt alles samen.
- **Het ontwerp volgen.** `docs/GDD.md`, `docs/stijlgids.md` en de research in `docs/research/` gelden.
  - Waar een bevinding tegen het GDD ingaat, volg je het GDD. Een voorbeeld: de Mol rijdt ±1,5 m/s.
  - Waar het GDD zwijgt, kies je wat het beste werkt voor de speler, en schrijf je de keuze op.
- **Nieuwe of sterk herwerkte modellen** (een hand, een wezen, een prop):
  - eerst een korte referentiestudie, die je in je rapport zet;
  - dan bouwen in de stijl van de bestaande assets;
  - in je rapport markeren met **"ter goedkeuring van Jayme"**;
  - geen betaalde beeldgeneratie gebruiken.
- **Wat buiten de opdracht valt:**
  - **Geluid** (Jayme, M6). Een plek voorzien mag wel: een signaal of een hook.
  - Steam en voice (M5).
  - De Godot-versie.
- **Vaste regels uit `CLAUDE.md`:**
  - "gevoel"-waarden in `game/data/tuning/`;
  - terrein enkel via `TerrainAPI`;
  - tekst in het spel in het Engels, volgens de woordenlijst in lessons.md;
  - docs en commentaar in het Nederlands;
  - in het netwerk aanvaardt de host wat de client voorspelt.

## Verifiëren (verplicht)

1. **Eenmalig in je worktree:** `tools\godot.cmd --headless --path game --import`.
2. **Beelden voor en na** van elke zichtbare wijziging, op dezelfde plek en hetzelfde moment.
   - Gebruik de scenario's, of Movie Maker (`--write-movie … --fixed-fps 30`) voor beweging.
   - **Kijk zelf naar elk beeld.** Bewaar ze in `C:\Dev\Diepgang\logs\review_fix\<pakket>\`.
3. **Tests.**
   - De headless tests uit `CLAUDE.md` die bij je bestanden horen. Bij twijfel: allemaal.
   - Bij netwerkcode ook `py -3.11 tools/net_test.py` (en `--scenario=net_ship_test` / `net_drop_flow_test`).
   - **Een test die faalt, los je op.** Je zet hem niet uit.
   - Past een test niet meer bij het nieuwe gedrag? Pas hem dan aan en zeg waarom.
4. **Committen** in je worktree, in kleine commits met een Nederlandse boodschap. Elke boodschap eindigt met `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Niet pushen.

## Rapport aan de lead

- Hooguit 60 regels.
- **Per bevinding-ID:**
  - de status: **klaar**, **deels** of **niet**;
  - wat je veranderde;
  - hoe je het verifieerde (de beelden en de tests);
  - wat er nog openstaat, en waarom.
- **Daarnaast:**
  - welke bestanden van andere pakketten je raakte;
  - wat ter goedkeuring van Jayme is;
  - een les voor `tasks/lessons.md`, als je er een had.
- **Wees eerlijk.** "Deels" met een reden is beter dan "klaar" dat niet klopt. Morgen kijkt een nieuwe audit met dezelfde strengheid.
- **Wees zuinig.** Grondig werken, maar geen herhaalde volledige runs als één gerichte run volstaat.


## Golf 3 (na ronde 2, 2026-10-06)

- **Bevindingen in detail:** `logs/review2/<rol>/rapport.md`. Daar staat ook het bewijs, onder `logs/review2/<rol>/`.
- **Samenvatting:** [release_audit_ronde2.md](release_audit_ronde2.md).
- **Verdeling per pakket:** [release_audit_ronde2_voortgang.md](release_audit_ronde2_voortgang.md).
- **Beelden voor en na:** in `C:\Dev\Diepgang\logs\review_fix3\<pakket>\`.
- **Voorstellen:** die van de reviewers (deel 3 van hun rapporten) die bij je punten horen, mag je meenemen. Waar ze het GDD veranderen, schrijf je dat op in `docs/GDD.md`, met "(golf 3)".
- **Geluid:** Jayme wil geen geluid dat met code gemaakt is ("da trekt op niks"). Maak dus geen synthetische klanken. Voorzie wel haken (signalen) op elke plek waar een geluid hoort. De echte opnames komen apart.
- **Nettests:** draai ze op je eigen poort:
  - G1: 25000
  - G2: 25010
  - G3: 25020
  - G4: 25030
  - G5: 25040
  - G6: 25050
- **Processen:** stop een Godot-proces nooit op procesnaam, enkel op PID. De andere pakketten draaien tegelijk.
- **Tests:** de volledige lijst staat in CLAUDE.md. Daar zitten nu ook `economy_test`, `threat_test`, `net_economy_test` en `net_threat_test` in.
