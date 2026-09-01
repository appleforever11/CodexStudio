  const parseRgb = (value) => {
    if (!value || value === "transparent") return null;
    const hex = String(value).trim().match(/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
    if (hex) {
      const digits = hex[1];
      const rgbHex = digits.length <= 4
        ? digits.slice(0, 3).split("").map((digit) => `${digit}${digit}`).join("")
        : digits.slice(0, 6);
      const alphaHex = digits.length === 4
        ? `${digits[3]}${digits[3]}`
        : digits.length === 8 ? digits.slice(6, 8) : "ff";
      const number = Number.parseInt(rgbHex, 16);
      return {
        r: number >> 16,
        g: (number >> 8) & 255,
        b: number & 255,
        alpha: Number.parseInt(alphaHex, 16) / 255,
      };
    }
    const m = String(value).trim().match(
      /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)$/i,
    );
    if (!m) return null;
    return {
      r: Number(m[1]),
      g: Number(m[2]),
      b: Number(m[3]),
      alpha: m[4] === undefined ? 1 : Math.min(1, Math.max(0, Number(m[4]))),
    };
  };

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  const rgbString = (value) => {
    const rgb = parseRgb(value);
    return rgb ? [rgb.r, rgb.g, rgb.b]
      .map((channel) => Math.round(clamp(channel, 0, 255)))
      .join(" ") : null;
  };

  const rgbToHex = ({ r, g, b }) => `#${[r, g, b]
    .map((value) => clamp(Math.round(value), 0, 255).toString(16).padStart(2, "0"))
    .join("")}`;

  const relativeLuminance = ({ r, g, b }) => {
    const channels = [r, g, b].map((value) => {
      const normalized = clamp(value, 0, 255) / 255;
      return normalized <= 0.04045
        ? normalized / 12.92
        : ((normalized + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
  };

  const compositeColor = (value, background, alphaOverride = null) => {
    const foreground = parseRgb(value);
    if (!foreground) return background;
    const alpha = clamp(alphaOverride ?? foreground.alpha ?? 1, 0, 1);
    return {
      r: clamp(foreground.r, 0, 255) * alpha + background.r * (1 - alpha),
      g: clamp(foreground.g, 0, 255) * alpha + background.g * (1 - alpha),
      b: clamp(foreground.b, 0, 255) * alpha + background.b * (1 - alpha),
    };
  };

  const readableAccentInk = (accent, panel) => {
    // The send button sits on the composer surface, which renders panel RGB
    // at 94% regardless of the panel color's declared alpha. Compare against
    // both possible backdrop extremes so artwork cannot flip the decision.
    const luminances = [0, 255].map((backdrop) => {
      const surface = compositeColor(
        panel,
        { r: backdrop, g: backdrop, b: backdrop },
        0.94,
      );
      return relativeLuminance(compositeColor(accent, surface));
    });
    const whiteContrast = Math.min(...luminances.map((value) => 1.05 / (value + 0.05)));
    const blackContrast = Math.min(...luminances.map((value) => (value + 0.05) / 0.05));
    return whiteContrast >= blackContrast ? "rgb(255 255 255)" : "rgb(0 0 0)";
  };

  const rgbToHsl = ({ r, g, b }) => {
    const values = [r, g, b].map((value) => value / 255);
    const max = Math.max(...values);
    const min = Math.min(...values);
    const lightness = (max + min) / 2;
    if (max === min) return { h: 0, s: 0, l: lightness };
    const delta = max - min;
    const saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    let hue;
    if (max === values[0]) hue = (values[1] - values[2]) / delta + (values[1] < values[2] ? 6 : 0);
    else if (max === values[1]) hue = (values[2] - values[0]) / delta + 2;
    else hue = (values[0] - values[1]) / delta + 4;
    return { h: hue * 60, s: saturation, l: lightness };
  };

  const hslToRgb = ({ h, s, l }) => {
    const hue = ((h % 360) + 360) % 360 / 360;
    if (s === 0) {
      const neutral = Math.round(l * 255);
      return { r: neutral, g: neutral, b: neutral };
    }
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    const channel = (offset) => {
      let t = hue + offset;
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };
    return { r: channel(1 / 3) * 255, g: channel(0) * 255, b: channel(-1 / 3) * 255 };
  };

  const detectShellAppearance = () => {
    const root = document.documentElement;
    if (root?.classList?.contains("electron-dark")) return "dark";
    if (root?.classList?.contains("electron-light")) return "light";
    try { return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"; } catch {}
    return "light";
  };

  const makeAdaptivePalette = (sample, shell) => {
    const source = sample || { r: 108, g: 126, b: 136 };
    const hsl = rgbToHsl(source);
    const hue = hsl.s < 0.12 ? 214 : hsl.h;
    const saturation = clamp(hsl.s, 0.38, 0.72);
    const accent = hslToRgb({ h: hue, s: saturation, l: shell === "light" ? 0.42 : 0.66 });
    const accentAlt = hslToRgb({ h: hue + 12, s: saturation * 0.82, l: shell === "light" ? 0.52 : 0.73 });
    const secondary = hslToRgb({ h: hue - 24, s: saturation * 0.64, l: shell === "light" ? 0.56 : 0.62 });
    const highlight = hslToRgb({ h: hue + 24, s: saturation * 0.76, l: shell === "light" ? 0.36 : 0.58 });
    const neutral = (lightness, chroma = 0.08) => rgbToHex(hslToRgb({ h: hue, s: chroma, l: lightness }));
    return shell === "light" ? {
      background: neutral(0.965, 0.07),
      panel: neutral(0.987, 0.035),
      panelAlt: neutral(0.945, 0.09),
      accent: rgbToHex(accent),
      accentAlt: rgbToHex(accentAlt),
      secondary: rgbToHex(secondary),
      highlight: rgbToHex(highlight),
      text: neutral(0.13, 0.10),
      muted: neutral(0.42, 0.08),
      line: `rgba(${Math.round(accent.r)}, ${Math.round(accent.g)}, ${Math.round(accent.b)}, .24)`,
    } : {
      background: neutral(0.055, 0.045),
      panel: neutral(0.085, 0.04),
      panelAlt: neutral(0.125, 0.05),
      accent: rgbToHex(accent),
      accentAlt: rgbToHex(accentAlt),
      secondary: rgbToHex(secondary),
      highlight: rgbToHex(highlight),
      text: neutral(0.93, 0.025),
      muted: neutral(0.69, 0.03),
      line: `rgba(${Math.round(accent.r)}, ${Math.round(accent.g)}, ${Math.round(accent.b)}, .28)`,
    };
  };

  const resolvedShell = () => {
    if (THEME.appearance === "light" || THEME.appearance === "dark") return THEME.appearance;
    // Image luminance may tune accents and scrims, but auto appearance follows
    // Codex/ChatGPT (or the OS fallback) so a bright wallpaper cannot flip a
    // native dark session back to a light shell after analysis.
    return detectShellAppearance();
  };

  const applyTheme = (root, shell) => {
    const declaredColors = THEME.colors && typeof THEME.colors === "object" ? THEME.colors : {};
    const legacyPalette = THEME.palette && typeof THEME.palette === "object" ? THEME.palette : {};
    // macOS themes use the full `colors` contract; older Windows themes used
    // `palette.accent`. Accept both while keeping one renderer source.
    const colors = Object.keys(declaredColors).length ? declaredColors : legacyPalette;
    const hasExplicitKeyList = Array.isArray(THEME.explicitColorKeys);
    const explicit = new Set(hasExplicitKeyList ? THEME.explicitColorKeys : []);
    if (!hasExplicitKeyList && (THEME.colorMode === "explicit" || !Object.hasOwn(THEME, "colorMode"))) {
      for (const key of Object.keys(declaredColors)) explicit.add(key);
    }
    if (typeof legacyPalette.accent === "string") explicit.add("accent");
    const adaptive = makeAdaptivePalette(artAnalysis?.accentRgb, shell);
    const legacyLight = (THEME.appearance === undefined || THEME.appearance === "auto")
      && THEME.colorMode !== "explicit" && shell === "light";
    const structural = new Set(["background", "panel", "panelAlt", "text", "muted"]);
    const pick = (name) => {
      const allowExplicit = explicit.has(name) && !(legacyLight && structural.has(name));
      return allowExplicit && typeof colors[name] === "string" ? colors[name] : adaptive[name];
    };
    const accent = pick("accent");
    const accentAlt = explicit.has("accentAlt") ? pick("accentAlt") : (explicit.has("accent") ? accent : adaptive.accentAlt);
    const variables = {
      "--ds-bg": pick("background"),
      "--ds-panel": pick("panel"),
      "--ds-panel-2": pick("panelAlt"),
      "--ds-green": accent,
      "--ds-lime": accentAlt,
      "--ds-cyan": pick("secondary"),
      "--ds-purple": pick("highlight"),
      "--ds-text": pick("text"),
      "--ds-muted": pick("muted"),
      "--ds-line": explicit.has("line") && typeof colors.line === "string" ? colors.line : adaptive.line,
    };
    const studioTokens = THEME.studio?.tokens && typeof THEME.studio.tokens === "object"
      ? THEME.studio.tokens : null;
    if (studioTokens) {
      Object.assign(variables, {
        "--ds-bg": studioTokens.appBackground,
        "--ds-panel": studioTokens.surface,
        "--ds-panel-2": studioTokens.surfaceElevated,
        "--ds-green": studioTokens.accent,
        "--ds-lime": studioTokens.accentHover,
        "--ds-cyan": studioTokens.toolBubble,
        "--ds-purple": studioTokens.surfaceSelected,
        "--ds-text": studioTokens.text,
        "--ds-muted": studioTokens.textMuted,
        "--ds-line": studioTokens.border,
      });
    }

    for (const [name, value] of Object.entries(variables)) {
      if (typeof value === "string" && value) setStyleProperty(root, name, value);
    }
    if (explicit.has("accent")) {
      const accentInk = readableAccentInk(
        accent,
        variables["--ds-panel"],
      );
      if (accentInk) setStyleProperty(root, "--ds-on-accent", accentInk);
    }
    const publicColors = {
      "--ds-theme-color-background": variables["--ds-bg"],
      "--ds-theme-color-panel": variables["--ds-panel"],
      "--ds-theme-color-panel-alt": variables["--ds-panel-2"],
      "--ds-theme-color-accent": variables["--ds-green"],
      "--ds-theme-color-accent-alt": variables["--ds-lime"],
      "--ds-theme-color-secondary": variables["--ds-cyan"],
      "--ds-theme-color-highlight": variables["--ds-purple"],
      "--ds-theme-color-text": variables["--ds-text"],
      "--ds-theme-color-muted": variables["--ds-muted"],
      "--ds-theme-color-line": variables["--ds-line"],
    };
    for (const [name, value] of Object.entries(publicColors)) {
      if (typeof value === "string" && value) setStyleProperty(root, name, value);
    }
    setStyleProperty(root, "--ds-theme-surface-radius", "12px");
    setStyleProperty(root, "--ds-theme-surface-opacity", "1");
    setStyleProperty(root, "--ds-theme-surface-blur", "0px");
    setStyleProperty(root, "--ds-theme-font-family", "system");
    setStyleProperty(root, "--ds-theme-font-scale", "1");
    setStyleProperty(root, "--ds-theme-surface-border-alpha", "0.14");
    setStyleProperty(root, "--ds-theme-surface-shadow", "soft");
    setStyleProperty(root, "--ds-theme-image-zoom", "1");
    setStyleProperty(root, "--ds-theme-image-dim", "0");
    setStyleProperty(root, "--ds-theme-image-task-intensity", "0.35");
    setStyleProperty(root, "--ds-theme-density-scale", "standard");
    setStyleProperty(root, "--ds-theme-motion-level", "standard");
    if (studioTokens) {
      for (const [key, name] of Object.entries(STUDIO_TOKEN_VARIABLES)) {
        if (Object.hasOwn(studioTokens, key)) setStyleProperty(root, name, String(studioTokens[key]));
      }
      setStyleProperty(root, "--ds-on-accent", studioTokens.accentContrast);
      setStyleProperty(root, "--ds-theme-font-scale", String(studioTokens.fontScale));
      setStyleProperty(root, "--ds-theme-surface-radius", `${studioTokens.radiusMd}px`);
      setStyleProperty(root, "--ds-theme-surface-opacity", String(studioTokens.panelOpacity));
      setStyleProperty(root, "--ds-theme-surface-blur", `${studioTokens.backdropBlur}px`);
      setStyleProperty(root, "--ds-theme-density-scale", studioTokens.density);
      setAttribute(root, "data-dream-studio-density", studioTokens.density);
    } else {
      root.removeAttribute("data-dream-studio-density");
    }
    const rgbVariables = {
      "--ds-bg-rgb": variables["--ds-bg"],
      "--ds-panel-rgb": variables["--ds-panel"],
      "--ds-panel-2-rgb": variables["--ds-panel-2"],
      "--ds-accent-rgb": variables["--ds-green"],
      "--ds-accent-alt-rgb": variables["--ds-lime"],
      "--ds-secondary-rgb": variables["--ds-cyan"],
      "--ds-highlight-rgb": variables["--ds-purple"],
      "--ds-text-rgb": variables["--ds-text"],
      "--ds-muted-rgb": variables["--ds-muted"],
      "--ds-line-rgb": variables["--ds-line"],
    };
    for (const [name, value] of Object.entries(rgbVariables)) {
      const rgb = rgbString(value);
      if (rgb) setStyleProperty(root, name, rgb);
    }
    setStyleProperty(root, "--dream-skin-name", cssString(THEME.name || "Codex Dream Skin"));
    const studioCopy = THEME.studio?.copy && typeof THEME.studio.copy === "object" ? THEME.studio.copy : {};
    const copyValue = (key, fallback) => typeof studioCopy[key] === "string" && studioCopy[key].trim()
      ? studioCopy[key] : fallback;
    setStyleProperty(root, "--dream-skin-tagline", cssString(copyValue("tagline", THEME.tagline || "A visual workspace for focused Codex sessions.")));
    setStyleProperty(root, "--dream-skin-quote", cssString(copyValue("quote", THEME.quote || "MAKE SOMETHING WONDERFUL")));
    setStyleProperty(root, "--dream-skin-brand-subtitle", cssString(
      copyValue("brandSubtitle", THEME.brandSubtitle || "CODEX DREAM SKIN"),
    ));
    setStyleProperty(root, "--dream-skin-status", cssString(copyValue("statusText", THEME.statusText || "DREAM SKIN ONLINE")));
    setStyleProperty(root, "--dream-skin-project-prefix", cssString(copyValue("projectPrefix", THEME.projectPrefix || "Project · ")));
    setStyleProperty(root, "--dream-skin-project-label", cssString(copyValue("projectLabel", THEME.projectLabel || "Choose project")));
  };

  const applyArtMetadata = (root) => {
    const profile = artAnalysis || ART_METADATA;
    const inferredSafe = profile?.safeArea || "center";
    const safeArea = ART.safeArea && ART.safeArea !== "auto" ? ART.safeArea : inferredSafe;
    const canonicalSafe = ["left", "right", "center", "none"].includes(safeArea)
      ? safeArea : "center";
    const focusX = typeof ART.focusX === "number" ? ART.focusX
      : profile?.focusX ?? (safeArea === "left" ? 0.72 : safeArea === "right" ? 0.28 : 0.5);
    const focusY = typeof ART.focusY === "number" ? ART.focusY : profile?.focusY ?? 0.5;
    const taskMode = ART.taskMode && ART.taskMode !== "auto"
      ? ART.taskMode : profile?.taskMode || "ambient";
    const wide = profile?.wide || profile?.aspect === "wide" || profile?.aspect === "ultrawide";
    const aspect = profile?.aspect || "unknown";
    const focusXValue = `${(clamp(focusX, 0, 1) * 100).toFixed(2)}%`;
    const focusYValue = `${(clamp(focusY, 0, 1) * 100).toFixed(2)}%`;

    setAttribute(root, "data-dream-art-wide", wide ? "true" : "false");
    setAttribute(root, "data-dream-art-safe", canonicalSafe);
    setAttribute(root, "data-dream-task-mode", taskMode);
    setAttribute(root, "data-dream-art-safe-area", safeArea);
    setAttribute(root, "data-dream-art-task-mode", taskMode);
    setAttribute(root, "data-dream-art-aspect", aspect);
    setAttribute(root, "data-dream-art-ready", artAnalysis ? "true" : "false");
    setStyleProperty(root, "--dream-art-focus-x", focusXValue);
    setStyleProperty(root, "--dream-art-focus-y", focusYValue);
    setStyleProperty(root, "--dream-art-position", `${focusXValue} ${focusYValue}`);
    setStyleProperty(root, "--dream-skin-focus-x", focusXValue);
    setStyleProperty(root, "--dream-skin-focus-y", focusYValue);
    setStyleProperty(root, "--dream-skin-art-position", `${focusXValue} ${focusYValue}`);
    setStyleProperty(root, "--ds-theme-image-focus-x", String(Number(focusX.toFixed(4))));
    setStyleProperty(root, "--ds-theme-image-focus-y", String(Number(focusY.toFixed(4))));
  };
