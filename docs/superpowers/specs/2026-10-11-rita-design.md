# Rita — spécification de conception

Date : 11/10/2026 · Statut : en revue

## 1. Objectif

Une application macOS minimale qui transforme **une image** (dessin scanné, texture, photo…) en
**brush Krita** dont le comportement suit la **pression** du stylet. On ouvre une image, on prépare la
pointe, on règle les courbes de pression en voyant un aperçu de trait, puis on exporte un `.bundle`
à importer dans Krita.

Pour un usage personnel (Laetitia), avec Krita 5.3.4.1.

Critères de réussite :
- Une image déposée → un `.bundle` importé dans Krita 5.3.4 sans erreur, la brush apparaît, peint
  avec la pointe attendue, et la pression agit sur les réglages activés selon les courbes choisies.
- Les trois modes de pointe (Masque, Image couleur, Carte de luminosité) se comportent dans Krita
  comme sélectionnés dans Rita.
- App native : raccourcis standard, glisser-déposer, mode clair/sombre, réglages mémorisés.

## 2. Contraintes

- Swift 6.4, macOS 27 pour le développement ; **cible minimale macOS 14**.
- **Swift Package** (`swift build`, `swift test`) ; Xcode est installé, donc plus besoin du chemin
  forcé vers le plugin Swift Testing utilisé dans Baguette. `scripts/bundle.sh` assemble `Rita.app`.
- **Aucune dépendance externe** : ImageIO / CoreGraphics pour les images, `Compression` (ou zlib du
  système) pour le bloc `zTXt`, zip écrit à la main (entrées « stockées », sans compression).
- Repo public `laetitiaperez/rita`, licence MIT, commits fréquents. CI et publication par tag
  `vX.Y.Z` reprises de Baguette.

## 3. Hors périmètre (pour l'instant)

Plusieurs images à la fois · partir d'un preset Krita existant · installation directe dans le
dossier de ressources de Krita · capteurs autres que la pression (inclinaison, aléatoire, vitesse) ·
textures, masking brush, autres moteurs que « pinceau pixel » (`paintbrush`).

## 4. Interface

Fenêtre unique.

- **Ouvrir** une image : glisser-déposer, ⌘O, « Ouvrir avec › Rita ». Tous les formats lus par ImageIO.
- **Colonne gauche — la pointe**
  - Mode : *Masque* · *Image couleur* · *Carte de luminosité*. À l'ouverture, Rita propose
    *Image couleur* si l'image contient de la couleur (voir 5.2), sinon *Masque*.
  - Préparation : seuil du fond (0–255, 245 par défaut : les pixels plus clairs deviennent
    transparents ; 255 = désactivé), contraste (−100…+100), inverser, recadrage automatique (activé
    par défaut), taille max de la pointe (64–1024 px, 512 par défaut), angle (0–360°).
  - Aperçu de la pointe sur damier.
- **Colonne droite — le comportement**
  - Taille de base (1–1000 px, 40 par défaut), espacement (0,02–5, 0,1 par défaut).
  - Six réglages pilotés par la pression : **Taille, Opacité, Flux, Rotation, Dispersion,
    Espacement**. Chacun : case d'activation, intensité (0–100 %), **éditeur de courbe**
    (clic = ajouter un point, glisser = déplacer, double-clic = supprimer ; les points x = 0 et
    x = 1 ne se suppriment pas et ne bougent que verticalement) et trois préréglages :
    *Linéaire* `0,0;1,1;`, *Douce* `0,0;0.5,0.25;1,1;`, *Ferme* `0,0;0.5,0.75;1,1;`.
  - Par défaut : Taille et Opacité activées (linéaire, 100 %), les autres désactivées.
- **Bas — aperçu de trait** : une vague horizontale tracée avec la pointe, la pression simulée
  allant de 0 à 1 puis 1 à 0. Recalculé à chaque changement (au plus ~30 ms sur la pointe max).
  C'est une approximation du moteur de Krita, pas un rendu identique.
- **Exporter** (⌘⇧E) : feuille demandant le nom de la brush (prérempli avec le nom de l'image),
  puis panneau d'enregistrement de `<nom>.bundle`. Après export : rappel
  « Dans Krita : Paramètres › Gérer les ressources › Importer un bundle ».
- Les réglages de la dernière brush sont mémorisés (UserDefaults).

## 5. Architecture

```
Sources/RitaCore   bibliothèque sans interface, entièrement testée
Sources/Rita       app SwiftUI (affichage + liaison)
Tests/RitaCoreTests
scripts/bundle.sh, scripts/make-icon.swift
.github/workflows/ci.yml, release.yml
docs/reference/    presets Krita de référence (lecture seule)
```

### 5.1 `RGBAImage`
Pixels RGBA 8 bits non prémultipliés, chargement et écriture PNG
via ImageIO. Repris et adapté de Baguette (WandCore). À l'ouverture, l'image source est réduite à
2048 px sur son plus grand côté (la pointe ne dépasse jamais 1024 px) pour garder l'aperçu fluide.

### 5.2 `TipMaker`
Entrée : `RGBAImage` + `TipOptions` (seuil, contraste, inverser, recadrer, taille max, angle, mode).
Sortie : `RGBAImage` de la pointe.
Étapes dans l'ordre : contraste → inversion → seuil du fond (luminance ≥ seuil → alpha 0 ; entre
seuil − 16 et seuil, alpha en rampe pour adoucir le bord) → rotation de l'angle → recadrage sur la
boîte englobante des pixels d'alpha > 0 (marge 2 px) → réduction si un côté dépasse la taille max
(jamais d'agrandissement).
Selon le mode, la pointe écrite est :
- *Masque* : niveaux de gris (la luminance remplace R, G, B), alpha conservé ;
- *Image couleur* et *Carte de luminosité* : couleurs conservées.
`suggestedMode(for:)` : *Image couleur* si plus de 2 % des pixels opaques ont une saturation > 0,15,
sinon *Masque*.
Erreur `TipError.empty` si aucun pixel ne reste après le seuil.

### 5.3 `PressureCurve`
Points (x, y) dans [0,1], triés par x, avec au moins les points x = 0 et x = 1. Deux points de même x :
le dernier ajouté remplace l'autre.
`value(at:)` : interpolation par spline cubique naturelle, comme le `KisCubicCurve` de Krita
(`KisCubicSpline`). Résultat borné à [0,1].
`description` / `init(string:)` : format Krita `x,y;x,y;` (6 décimales max, point-virgule final).
Le parseur accepte l'absence de point-virgule final et rejette les valeurs hors [0,1].

### 5.4 `BrushSettings`
`name`, `tipMode`, `diameter`, `spacing`, et `options: [PressureOption.Kind: PressureOption]` pour
`size, opacity, flow, rotation, scatter, spacing`. `PressureOption` = `enabled`, `strength` (0–1),
`curve`. `Codable` (mémorisation).

### 5.5 `PresetXML`
`BrushSettings` + nom du fichier de pointe → XML `<Preset paintopid="paintbrush" name="…">`, une
suite de `<param type="string" name="…"><![CDATA[…]]></param>` triés par nom, comme le preset de
référence `docs/reference/j)_WaterC_Flat_Decay_Tilt.kpp`.
Pour chaque option, avec `X` ∈ {Size, Opacity, Flow, Rotation, Scatter, Spacing} :
- `PressureX` = `true|false` (sauf Opacity et Flow, non cochables dans Krita : pas de `PressureOpacity`/`PressureFlow`) ;
- `XSensor` = `<!DOCTYPE params> <params id="pressure"> <curve>…</curve> </params> ` ;
- `XUseCurve` = `true` (pour Opacity et Flow : `true` si l'option est activée, `false` sinon, c'est leur « Enable pen settings »), `XUseSameCurve` = `true`, `XcommonCurve` = la courbe, `XcurveMode` = `0` ;
- `XValue` = l'intensité.
Ajouter aussi les paramètres fixes : `paintop` = `paintbrush`, `CompositeOp` = `normal`,
`EraserMode` = `false`, `Scattering/AxisX|AxisY` = `true`, `Spacing/Isotropic` = `false`,
`Texture/Pattern/Enabled` = `false`, `MaskingBrush/Enabled` = `false`, `lodUserAllowed` = `true`,
`requiredBrushFile` = `requiredBrushFilesList` = nom de la pointe.
`brush_definition` = `<Brush type="png_brush" filename="<pointe>.png" BrushVersion="2" scale="…"
spacing="…" angle="0" useAutoSpacing="0" autoSpacingCoeff="1" ColorAsMask="…"
preserveLightness="…" brushApplication="…" BrightnessAdjustment="0" ContrastAdjustment="0"
AdjustmentMidPoint="127"/>`, avec `scale` = diamètre ÷ plus grand côté de la pointe.
Correspondance des modes : Masque → `ColorAsMask="1" preserveLightness="0" brushApplication="0"` ;
Image couleur → `0 / 0 / 1` ; Carte de luminosité → `0 / 1 / 2`.
Les attributs `ColorAsMask` et `preserveLightness` sont les anciens (Krita 4), `brushApplication`
est celui de Krita 5. On écrit les deux.

### 5.6 `PNGChunks`
Lecture : liste des blocs d'un PNG (type + données), décompression des `zTXt`.
Écriture : insère après `IHDR` un bloc `zTXt` (clé `preset`, méthode 0, zlib) et un bloc `tEXt`
(clé `version`, valeur `2.2`), avec un CRC32 correct.

### 5.7 `KPPFile`
Vignette 200×200 RGB (le trait d'aperçu en noir sur blanc) + XML → données `.kpp`.

### 5.8 `BundleWriter`
Écrit un zip dont les entrées sont stockées : `mimetype` en premier (`application/x-krita-resourcebundle`),
`META-INF/manifest.xml` (une entrée par ressource avec media-type `brushes` ou `paintoppresets`,
et le md5 de la ressource), `meta.xml` (generator `Rita <version>`, auteur, description, dates
au format `dd/MM/yyyy`, bundle-version 1), `preview.png` (256×256),
`brushes/<nom>.png`, `paintoppresets/<nom>.kpp`.
Le nom de fichier est assaini : caractères `/:\` et contrôles retirés, espaces conservés, nom vide → « Rita ».

### 5.9 `StrokeSimulator`
Pour une pointe et des `BrushSettings`, dessine une vague (sinusoïde, une période) dans une image
donnée. Le long du trait, la pression p va de 0 à 1 puis revient à 0. Chaque empreinte est posée à
l'intervalle `espacement × diamètre effectif`, avec :
taille = diamètre × f(Size) ; opacité = f(Opacity) × f(Flow) ; rotation = angle + 360° × f(Rotation) ;
dispersion = décalage perpendiculaire aléatoire (graine fixe) jusqu'à diamètre × f(Scatter) ;
espacement multiplié par f(Spacing).
Ici f(X) = 1 − force × (1 − courbe(p)) si l'option est activée, et 1 sinon. Les empreintes sont
composées en *source-over*, en noir pour Masque et Carte de luminosité, avec les couleurs de la
pointe pour Image couleur.

### 5.10 App
`AppModel` (`@Observable`) : image source, `TipOptions`, `BrushSettings`, pointe et aperçu
recalculés en tâche de fond quand un réglage change, avec abandon du calcul précédent.
Vues : `ContentView`, `TipPanel`, `BehaviorPanel`, `CurveEditor`, `StrokePreview`, `Export`.

## 6. Erreurs

- Image illisible → alerte « Impossible de lire cette image », l'état précédent est conservé.
- Pointe vide après le seuil → message dans l'aperçu, bouton Exporter désactivé.
- Échec d'écriture du bundle → alerte avec le message du système.

## 7. Tests (TDD, Swift Testing)

- `PressureCurve` : aller-retour texte ; `value(0)` et `value(1)` égales aux points extrêmes ;
  les trois préréglages donnent une courbe croissante ; tri et bornage ; rejet des valeurs invalides.
- `TipMaker` : fond blanc → alpha 0 au seuil ; recadrage exact sur une image de test 20×20 ;
  inversion ; réduction à la taille max ; `suggestedMode` (gris vs couleur) ; erreur `empty`.
- `PresetXML` : XML relu par `XMLParser` ; présence et valeur de `PressureSize`, `SizeSensor`,
  `SizecommonCurve`, `brush_definition` (filename, mode) ; pour les options communes, les noms de
  paramètres générés sont présents dans le preset de référence.
- `PNGChunks` / `KPPFile` : relecture du vrai preset de référence (XML commençant par
  `<Preset paintopid="paintbrush"`, version `2.2`) ; aller-retour écriture/lecture ; PNG relu par ImageIO.
- `BundleWriter` : `unzip -t` OK ; `mimetype` en premier et non compressé ; md5 du manifeste
  corrects ; noms assainis.
- `StrokeSimulator` : trait non vide ; avec Taille activée, les empreintes du milieu (p = 1) sont plus
  grandes que celles des bords.
- **Essai final dans Krita 5.3.4.1** (manuel, avec Laetitia et la tablette) : import du bundle,
  la brush peint, chaque mode de pointe et chaque option de pression agissent.

## 8. Risques

- **Format d'écriture de Krita 5.3** : le seul modèle disponible vient de Krita 4, même s'il est
  livré avec la 5.3 et lu par elle. On en tient compte dans le plan : dès la première tâche
  d'export, on importe un bundle minimal dans Krita. Si un réglage est ignoré (notamment
  `brushApplication` et l'intensité de Rotation/Dispersion), on enregistre depuis Krita 5.3 un
  preset de comparaison, on le copie dans `docs/reference/` et on aligne `PresetXML` dessus.
- **Aperçu ≠ Krita** : c'est assumé. L'aperçu sert à comparer des courbes entre elles, pas à
  prédire le rendu au pixel près.
