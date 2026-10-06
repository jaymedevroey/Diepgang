# Release-audit, ronde 2 (2026-10-06): opdracht voor de reviewers

Jayme laat de audit opnieuw doen op **v0.10.0**: "super kritisch, zoals de vorige keer".

**Volg eerst [release_audit_opdracht.md](release_audit_opdracht.md).** Die regels gelden onveranderd:
- de lat is een publieke Steam-demo;
- in scope: gameplay en gevoel, en uiterlijk;
- je verandert niets aan het spel;
- bewijs bij elke bevinding, dezelfde ernstniveaus, en een rapport in het Nederlands;
- beter iets onterecht slecht vinden dan iets slechts goedkeuren.

## Wat er nieuw is aan deze ronde

### 1. Elk vorig punt opnieuw beoordelen

- **Waar je ze vindt:** de bevindingen van jouw rol uit ronde 1 staan in `logs/review/<rol>/rapport.md`.
- **Wat het team zegt dat het deed:** dat staat in [release_audit_voortgang.md](release_audit_voortgang.md), met wat er gedaan is en hoe het geverifieerd werd.
- **Geloof dat niet op hun woord.** Bekijk elk punt zelf opnieuw, op dezelfde plek en hetzelfde moment als in ronde 1. Leg je oude beeld en je nieuwe beeld naast elkaar.
- **Oordeel per punt:**
  - **opgelost**: op demo-niveau;
  - **beter, niet genoeg**: wat er nog ontbreekt;
  - **niet opgelost**;
  - **erger geworden**: een regressie.

### 2. Nieuwe bevindingen

De nieuwe bevindingen krijgen de ID `<rol>2-<nr>`. Kijk vooral naar wat er sinds ronde 1 bijkwam (zie de release-notes van v0.10.0 in `docs/playtest-m3.md`):
- **Gevaar:**
  - de graafworm (op de sonar, lokken met lawaai, lichtbakens op G);
  - gasbellen;
  - instortingen die met de diepte toenemen;
  - bevingen met rotsen.
- **Neergaan en redden:** de ragdoll, dragen naar de Mol, en de drone na het smelten.
- **Economie:**
  - de taxatiepoort met onthulling en het verkoopluik;
  - de winkel aan drie toonbanken: boor T2, boorkop T2, handscanner (Q), helmlamp, laadruim;
  - de gewichtslimiet, schuld en proeftijd;
  - contracten met voorwaarden.
- **Planeten:** buit per planeet, Titan-skeletten in stukken, zwaar dragen met twee, breekbare kristallen, en de zijscan voor passagiers.
- **Gevoel:** sprint, hurken, de handen, een zware Mol, een nieuw volgshot in de drop, korter ophalen.
- **Beeld:**
  - grotten met eigen licht, lagen per planeet, nieuw magma;
  - de hub met slijtage;
  - scherpere planeten, props in het middenplan, de romp van het schip, de verweerde Mol.
- **Interface:** de nieuwe contractbalie, het rapport, de waarschuwingen, de aftelling, en het nieuwe menu.

### 3. De playtest van 6 oktober

- **Waar:** [playtest_2026-10-06.md](playtest_2026-10-06.md).
- **Wat ze vonden:** Ian en Anir vonden "niet genoeg gevaar" en wilden meer dingen om mee te spelen.
- **Jouw oordeel:** is dat nu opgelost, vanuit jouw rol?

### 4. "Ter goedkeuring van Jayme"

- **Waar:** zo staat het in de voortgangslijst bij de modellen en keuzes die het team zelf maakte (de worm, de scanner, de hand, de vondsten, de nissen, de Mol, het schip, de badlands, de schuld en de contracten).
- **Wat je doet:** geef er een eerlijk oordeel over. Jayme beslist.

## Praktisch

- **Bewijs** komt in `C:\Dev\Diepgang\logs\review2\<rol>\`. Je rapport staat in `logs\review2\<rol>\rapport.md`.
- **Je rapport heeft twee delen:**
  1. een tabel met **alle** vorige ID's van je rol (oordeel en een korte reden);
  2. je nieuwe bevindingen, gerangschikt van Blokkerend naar Klein.
- **Je eindoordeel:** sluit af met één alinea. Haalt dit deel van het spel de lat van een publieke Steam-demo? Zo niet, wat zijn de drie dingen die het meest ontbreken?
- **Nettests** draai je op je eigen poort:
  - ontwerp 24900;
  - gevoel 24910;
  - buiten 24920;
  - binnen 24930;
  - ui 24940.
- **Processen:** stop een Godot-proces nooit op procesnaam, enkel op PID. Andere reviewers draaien tegelijk.
- **Je antwoord aan de lead:** hooguit 50 regels. Begin met de tellingen van je oude punten (opgelost, beter, niet, erger), dan je zwaarste nieuwe bevindingen en je eindoordeel, en het pad naar je rapport.
