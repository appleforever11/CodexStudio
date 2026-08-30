import Foundation

enum ThemeCatalog {
    static let curated: [Theme] = [
        make(
            id: "preset-signature-violet-salt-dunes",
            name: "Violet Salt Dunes",
            category: "Landscape",
            description: "Dark dunes fold around pools that hold the last light.",
            palette: palette("#0B0920", "#19122E", "#2A1D42", "#C68BC8", "#E4B3D9", "#604C7D", "#9A86B5", "#F8F1FA", "#B7A9C2", "rgba(198,139,200,0.31)"),
            focusX: 0.76,
            focusY: 0.42,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-obsidian-cobalt",
            name: "Obsidian Cobalt",
            category: "Minimal",
            description: "A true-black canvas with one electric seam for long coding sessions.",
            palette: palette("#000000", "#080A0E", "#10141B", "#3972FF", "#76A0FF", "#252B38", "#BFD1FF", "#FFFFFF", "#A6ADBB", "rgba(57,114,255,0.40)"),
            focusX: 0.72,
            focusY: 0.24,
            safeArea: "left",
            taskMode: "off"
        ),
        make(
            id: "preset-signature-solar-stained-observatory",
            name: "Solar Stained Observatory",
            category: "Glass",
            description: "Antique glass maps a radiant sun and invented orbital paths.",
            palette: palette("#070818", "#11152D", "#202047", "#E6A43C", "#FFD17A", "#3D63A7", "#9A4C70", "#FFF7E4", "#B9B0B8", "rgba(230,164,60,0.34)"),
            focusX: 0.78,
            focusY: 0.35,
            safeArea: "left",
            taskMode: "banner"
        ),
        make(
            id: "preset-signature-cast-glass-tide",
            name: "Cast Glass Tide",
            category: "Glass",
            description: "Sea-green refractions, softened edges, and a cool studio rhythm.",
            palette: palette("#07171B", "#10272A", "#1C3D3B", "#61D1BD", "#B0F5E6", "#2F6A69", "#8DD6CC", "#EFFDF8", "#A9C9C2", "rgba(97,209,189,0.32)"),
            focusX: 0.69,
            focusY: 0.38,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-brutalist-solstice",
            name: "Brutalist Solstice",
            category: "Graphic",
            description: "Hard planes, mineral yellow, and high-signal contrast for decisive work.",
            palette: palette("#11110F", "#1D1C18", "#333028", "#E9B949", "#FFE6A3", "#61502B", "#B7A47A", "#FFF9EA", "#BDB5A1", "rgba(233,185,73,0.34)"),
            focusX: 0.82,
            focusY: 0.28,
            safeArea: "left",
            taskMode: "banner"
        ),
        make(
            id: "preset-signature-walnut-terminal",
            name: "Walnut Terminal",
            category: "Material",
            description: "Warm wood, amber phosphor, and the quiet confidence of a real workbench.",
            palette: palette("#17110F", "#251914", "#38231A", "#D58A52", "#F2B982", "#704A34", "#C99F7B", "#FFF2E6", "#C5AFA0", "rgba(213,138,82,0.32)"),
            focusX: 0.74,
            focusY: 0.44,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-rose-window-modern",
            name: "Rose Window Modern",
            category: "Color",
            description: "A dusky rose study with a measured, editorial interface system.",
            palette: palette("#1A0D17", "#2A1525", "#44203B", "#F08CA8", "#FFC4D1", "#7A3E5F", "#D28CA5", "#FFF2F6", "#CBAEBB", "rgba(240,140,168,0.30)"),
            focusX: 0.75,
            focusY: 0.40,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-cyanotype-herbarium",
            name: "Cyanotype Herbarium",
            category: "Botanical",
            description: "Pressed leaves and blueprint blues make space for careful thinking.",
            palette: palette("#07151D", "#102631", "#1C3A48", "#65C6DD", "#B7F0F4", "#2E6070", "#8CBECB", "#ECFBFF", "#A4C4CC", "rgba(101,198,221,0.31)"),
            focusX: 0.68,
            focusY: 0.34,
            safeArea: "left",
            taskMode: "off"
        ),
        make(
            id: "preset-signature-ember-maple-railway",
            name: "Ember Maple Railway",
            category: "Landscape",
            description: "A low autumn sun, a long rail line, and a little copper in every action.",
            palette: palette("#1D110E", "#2B1915", "#40251C", "#E47A45", "#FFC18D", "#75402E", "#C88A68", "#FFF1E8", "#C5A89A", "rgba(228,122,69,0.34)"),
            focusX: 0.79,
            focusY: 0.36,
            safeArea: "left",
            taskMode: "banner"
        ),
        make(
            id: "preset-signature-luminous-kelp-canyon",
            name: "Luminous Kelp Canyon",
            category: "Ocean",
            description: "A deep-water interface with phosphorescent green highlights and soft depth.",
            palette: palette("#061412", "#0C221E", "#143A31", "#74E2A9", "#B7F7D0", "#28604E", "#8CCCA6", "#EEFFF5", "#A7C8B3", "rgba(116,226,169,0.30)"),
            focusX: 0.72,
            focusY: 0.42,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-stained-light",
            name: "Stained Light",
            category: "Color",
            description: "Prismatic panes give every state a little more atmosphere without losing clarity.",
            palette: palette("#111022", "#1D1A35", "#302553", "#A78BFA", "#D9C9FF", "#61499B", "#B7A3E5", "#FAF7FF", "#BDB1CE", "rgba(167,139,250,0.31)"),
            focusX: 0.78,
            focusY: 0.38,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-signature-moonlit-glasshouse",
            name: "Moonlit Glasshouse",
            category: "Botanical",
            description: "Leaf shadows, blue glass, and a cool nocturnal surface for deep work.",
            palette: palette("#071319", "#10242A", "#1A3B3A", "#79C6B2", "#C2F2D9", "#37685F", "#9FD2C2", "#F0FFF7", "#A8C6BA", "rgba(121,198,178,0.30)"),
            focusX: 0.74,
            focusY: 0.35,
            safeArea: "left",
            taskMode: "off"
        ),
        make(
            id: "preset-gothic-void-crusade",
            name: "Gothic Void Crusade",
            category: "Cinematic",
            description: "A restrained science-fiction atmosphere with a strong cinematic focal point.",
            palette: palette("#090B12", "#171A25", "#252B3A", "#D05C8A", "#F2A5C4", "#553B57", "#B38EA8", "#FFF5FA", "#B4A9B4", "rgba(208,92,138,0.34)"),
            focusX: 0.74,
            focusY: 0.46,
            safeArea: "left",
            taskMode: "ambient"
        ),
        make(
            id: "preset-arina-hashimoto",
            name: "Arina — Soft Studio",
            category: "Portrait",
            description: "A quiet portrait-led workspace with a soft editorial balance.",
            palette: palette("#171416", "#272022", "#3B3032", "#E39A83", "#FFD1BF", "#76514D", "#C89F95", "#FFF7F2", "#CBB8B0", "rgba(227,154,131,0.30)"),
            focusX: 0.72,
            focusY: 0.45,
            safeArea: "left",
            taskMode: "auto"
        ),
        make(
            id: "preset-neon-moon-pavilion",
            name: "Neon Moon Pavilion",
            category: "Neon",
            description: "An electric pavilion of moonlight, blue glass, and a precise pink signal.",
            palette: palette("#070B18", "#11182A", "#1A2A46", "#6EE7FF", "#D2FAFF", "#385A91", "#96C5E1", "#F2FCFF", "#A8BFCE", "rgba(110,231,255,0.34)"),
            focusX: 0.78,
            focusY: 0.32,
            safeArea: "left",
            taskMode: "banner"
        )
    ]

    private static func make(
        id: String,
        name: String,
        category: String,
        description: String,
        palette: ThemePalette,
        focusX: Double,
        focusY: Double,
        safeArea: String,
        taskMode: String
    ) -> Theme {
        Theme(
            id: id,
            name: name,
            author: "Codex Studio",
            description: description,
            category: category,
            collection: "Studio Collection",
            appearance: "dark",
            palette: palette,
            imagePath: nil,
            previewPath: nil,
            origin: .curated,
            isInstalled: false,
            isCurated: true,
            isFavorite: false,
            focusX: focusX,
            focusY: focusY,
            safeArea: safeArea,
            taskMode: taskMode
        )
    }

    private static func palette(
        _ background: String,
        _ panel: String,
        _ panelAlt: String,
        _ accent: String,
        _ accentAlt: String,
        _ secondary: String,
        _ highlight: String,
        _ text: String,
        _ muted: String,
        _ line: String
    ) -> ThemePalette {
        ThemePalette(
            background: background,
            panel: panel,
            panelAlt: panelAlt,
            accent: accent,
            accentAlt: accentAlt,
            secondary: secondary,
            highlight: highlight,
            text: text,
            muted: muted,
            line: line
        )
    }
}
