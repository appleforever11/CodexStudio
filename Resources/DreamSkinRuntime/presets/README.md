# Bundled theme gallery

This directory contains the themes included with Codex Theme Studio. Installation safely seeds each `preset-*/` folder into the managed local theme library without overwriting user-created themes.

## Gallery contents

- 200 original Studio themes across 10 visual families.
- Six compatibility themes retained from the upstream project.
- Every Studio theme has a unique 1600 x 1000 JPEG background, palette, interface tokens, chat-bubble styling, sidebar styling, composer styling, and English copy.

Run the gallery checks before publishing:

```bash
npm run themes:validate
```

The validator checks the exact theme count, unique IDs and visual signatures, image dimensions and format, English copy, and minimum color contrast.

## Theme package structure

```text
preset-<slug>/
├── theme.json
└── background.jpg
```

The folder name and manifest ID must use the `preset-<slug>` form. Backgrounds must be local files inside the theme folder. Use only original, public-domain, or properly licensed imagery that permits redistribution. Do not submit screenshots of the Codex interface as theme backgrounds.

The Studio gallery backgrounds are procedurally generated original artwork. Compatibility themes can carry separate notices or licensing terms; review `NOTICE.md` before redistributing third-party material.

## Adding or regenerating Studio themes

From the repository root:

```bash
npm run themes:generate
npm run themes:catalog
npm run themes:validate
```

After validation, test the home page, focused composer, project picker, task view, pull requests, and side panels in both relevant appearance modes. A visual preview is not proof that a theme was injected; native apply must also report a verified result.
