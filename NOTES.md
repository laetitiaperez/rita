# Rita — notes de projet

## Objectif
App macOS en Swift : une image (dessin, texture, photo…) → une brush Krita, avec la pression.
Pour Laetitia seule. Krita 5.3.4.1.

## Format .kpp (observé sur docs/reference/j)_WaterC_Flat_Decay_Tilt.kpp, 11/10/2026)
- PNG 200×200 RGB (vignette) + bloc `zTXt` clé `preset` (XML) + `tEXt` clé `version` = `2.2`.
- Ce fichier est livré tel quel dans Krita 5.3.4 (identique à celui du .app) → format lu par 5.3.
- XML : `<Preset paintopid="paintbrush" name="…">` puis des `<param type="string" name="…"><![CDATA[…]]></param>`.
- Pointe : `brush_definition` = `<Brush type="png_brush" filename="spike_blob.png" scale spacing angle
  BrushVersion="2" ColorAsMask preserveLightness BrightnessAdjustment ContrastAdjustment …/>`
  + `requiredBrushFile` / `requiredBrushFilesList`. La pointe est référencée par **nom de fichier**,
  pas embarquée → il faut la livrer à côté (dossier `brushes/` d'un .bundle).
- Pression, par option X (Size, Opacity, Flow, Rotation, Scatter, Spacing, Softness, Sharpness, Darken, Mix, Ratio, Rate…) :
  - `PressureX` = true/false (option active)
  - `XSensor` = `<!DOCTYPE params> <params id="pressure"> <curve>x,y;x,y;</curve> </params>`
    ou plusieurs capteurs : `<params id="sensorslist"> <ChildSensor id="pressure"><curve>…</curve></ChildSensor> <ChildSensor id="fuzzy"/> </params>`
    (autres id vus : fuzzy, ascension = inclinaison/tilt)
  - `XUseCurve`, `XUseSameCurve`, `XcommonCurve`, `XcurveMode` (0 = multiplier), `XValue` (force 0–1)
- Courbe : points `x,y;` séparés par `;`, x et y dans [0,1].
- Les vieux presets (Krita 3) embarquent un motif de texture en base64 (`Texture/Pattern/Pattern`).

## Format .bundle (observé sur Charcoal_pencils.bundle)
- Zip : `mimetype` (application/x-krita-resourcebundle), `META-INF/manifest.xml` (entrées avec
  media-type = dossier de ressource et md5sum), `meta.xml` (auteur, description, dates…), `preview.png`,
  puis les ressources : `paintoppresets/*.kpp`, `brushes/*.png|gbr`.

## Décisions
- `XValue` = force de l'option (`strength`, 0–1).
- Le diamètre passe par l'attribut `scale` de `brush_definition` (diamètre ÷ plus grand côté de la pointe), pas par un paramètre séparé.
- Les nombres du XML (force, espacement, échelle) utilisent `kritaNumber` (6 décimales max, sans zéros finaux), comme les courbes.
- `PressureKind` est `CodingKeyRepresentable` : `options` est encodé en JSON comme un objet (clés `size`, `opacity`…) et non comme un tableau.
- Une option absente de `BrushSettings.options` est écrite comme désactivée, linéaire, force 1.
- Le XML commence directement par `<Preset …>` (pas de déclaration `<?xml?>`), comme le preset de référence.
