  const SELECTOR_CONTRACT = {"schema":"codex-dream-skin-selectors/1","selectors":[{"key":"shell-main","selector":"main:is(.main-surface, [data-app-shell-main-surface], [class*=\"_MainContentSurface_\"])","tier":"L1","scope":"all","required":true},{"key":"left-panel","selector":"aside.app-shell-left-panel","tier":"L1","scope":"all","required":true},{"key":"header-tint","selector":"header:is(.app-header-tint, [data-app-shell-header-edge-scroll], [class*=\"_Header_\"])","tier":"L1","scope":"all","required":true},{"key":"main-content-top-fade","selector":":is(.app-shell-main-content-top-fade, [data-app-shell-main-content-top-fade], [class*=\"_MainContentTopFade_\"])","tier":"L2","scope":"all","required":false},{"key":"home-icon","selector":"[data-testid=\"home-icon\"]","tier":"L1","scope":"home","required":true},{"key":"home-route","selector":"[role=\"main\"]:has([data-testid=\"home-icon\"])","tier":"L1","scope":"home","required":true},{"key":"home-route-css","selector":"[role=\"main\"]","tier":"L1","scope":"home","required":true},{"key":"home-banners","selector":".home-banners","tier":"L2","scope":"home","required":false},{"key":"composer-chrome","selector":":is(.composer-surface-chrome, [class*=\"_ComposerLayoutRoot_\"], [data-composer-surface-variant][data-composer-radius-variant])","tier":"L2","scope":"home+thread","required":false},{"key":"composer-toolbar","selector":":is(.composer-surface-chrome [class*=\"_footer_\"], [class*=\"_ComposerLayoutRoot_\"] [class*=\"_ComposerLayoutFooter_\"], [data-composer-surface-variant][data-composer-radius-variant] :is([data-composer-footer-responsive], [class*=\"_ComposerLayoutFooter_\"], [class*=\"_footer_\"]))","tier":"L2","scope":"home+thread","required":false},{"key":"home-utility","selector":":is([class*=\"_homeUtilityBar_\"], [class*=\"_ComposerHomeUtilityBar_\"])","tier":"L2","scope":"home","required":false},{"key":"game-source","selector":"[data-feature=\"game-source\"]","tier":"L2","scope":"home","required":false},{"key":"home-suggestions","selector":".group\\/home-suggestions","tier":"L2","scope":"home","required":false},{"key":"project-selector","selector":".group\\/project-selector","tier":"L2","scope":"home config","required":false},{"key":"markdown","selector":"[class*=\"_markdown\"]","tier":"L2","scope":"thread","required":false},{"key":"thread-surface","selector":".thread-scroll-container","tier":"L2","scope":"thread","required":false},{"key":"message","selector":":is([data-message-author-role], [data-local-conversation-user-anchor], [data-local-conversation-final-assistant])","tier":"L2","scope":"thread","required":false},{"key":"settings-panel","selector":"[data-settings-panel-slug=\"general-settings\"]","tier":"L2","scope":"settings","required":false},{"key":"appearance-radio","selector":"input[name=\"appearance-theme\"]","tier":"L2","scope":"settings","required":false},{"key":"overlay-menu","selector":"[role=\"menu\"]","tier":"L2","scope":"overlay","required":false},{"key":"overlay-dialog","selector":"[role=\"dialog\"]","tier":"L2","scope":"overlay","required":false},{"key":"overlay-popper","selector":"[data-radix-popper-content-wrapper]","tier":"L2","scope":"overlay","required":false}],"stableTestids":["app-shell-header-context-menu-surface","home-icon","theme-preview"]};
  const STATE_KEY = "__CODEX_DREAM_SKIN_STATE__";
  const DISABLED_KEY = "__CODEX_DREAM_SKIN_DISABLED__";
  const STYLE_REGISTRY_KEY = "__CODEX_DREAM_SKIN_STYLE_SHEETS__";
  const STYLE_ID = "codex-dream-skin-style";
  const SHELL_ATTR = "data-dream-shell";
  const PART_ATTR = "data-ds-part";
  const STUDIO_ORIGINAL_TEXT_ATTR = "data-dream-studio-original-text";
  const COMPOSER_BORDER_BRIDGES = [
    "border-color", "border-top-color", "border-right-color", "border-bottom-color",
    "border-left-color", "border-width", "border-top-width", "border-right-width",
    "border-bottom-width", "border-left-width", "border-style", "border-top-style",
    "border-right-style", "border-bottom-style", "border-left-style",
  ].map((property) => ({
    property,
    variable: `--ds-community-composer-${property}`,
  })).filter(({ variable }) => cssText.includes(`${variable}:`));
  const ROOT_ATTRS = [
    "data-dream-skin", SHELL_ATTR,
    "data-dream-art-wide", "data-dream-art-safe", "data-dream-task-mode",
    "data-dream-art-safe-area", "data-dream-art-task-mode", "data-dream-art-aspect",
    "data-dream-art-ready",
  ];
  const initialRoute = new URLSearchParams(String(location.search || ""))
    .get("initialRoute") || "";
  const pathname = String(location.pathname || "");
  const excludedPetSurface = location.protocol === "app:" && (
    pathname.endsWith("/avatar-overlay-composition-surface.html") ||
    initialRoute === "/avatar-overlay" || initialRoute.startsWith("/avatar-overlay/")
  );
  if (excludedPetSurface) {
    const previous = window[STATE_KEY];
    if (typeof previous?.cleanup === "function") previous.cleanup();
    window[DISABLED_KEY] = true;
    return;
  }
  const VERSION = __DREAM_SKIN_VERSION_JSON__;
  const STYLE_REVISION = __DREAM_SKIN_STYLE_REVISION_JSON__;
  const PAYLOAD_REVISION = __DREAM_SKIN_PAYLOAD_REVISION_JSON__;
  const THEME = themeConfig && typeof themeConfig === "object" ? themeConfig : {};
  const ART = THEME.art && typeof THEME.art === "object" ? THEME.art : {};
  const ART_METADATA = THEME.artMetadata && typeof THEME.artMetadata === "object"
    ? THEME.artMetadata : null;
  const ANALYSIS_CACHE_KEY = "__CODEX_DREAM_SKIN_ANALYSIS_CACHE__";
  const STUDIO_TOKEN_VARIABLES = {
    appBackground: "--dream-studio-app-background",
    sidebarBackground: "--dream-studio-sidebar-background",
    surface: "--dream-studio-surface",
    surfaceElevated: "--dream-studio-surface-elevated",
    surfaceHover: "--dream-studio-surface-hover",
    surfaceSelected: "--dream-studio-surface-selected",
    border: "--dream-studio-border",
    text: "--dream-studio-text",
    textMuted: "--dream-studio-text-muted",
    textFaint: "--dream-studio-text-faint",
    accent: "--dream-studio-accent",
    accentHover: "--dream-studio-accent-hover",
    accentContrast: "--dream-studio-accent-contrast",
    userBubble: "--dream-studio-user-bubble",
    assistantBubble: "--dream-studio-assistant-bubble",
    toolBubble: "--dream-studio-tool-bubble",
    codeBackground: "--dream-studio-code-background",
    composerBackground: "--dream-studio-composer-background",
    composerBorder: "--dream-studio-composer-border",
    danger: "--dream-studio-danger",
    sidebarWidth: "--dream-studio-sidebar-width",
    radiusSm: "--dream-studio-radius-sm",
    radiusMd: "--dream-studio-radius-md",
    radiusLg: "--dream-studio-radius-lg",
    panelOpacity: "--dream-studio-panel-opacity",
    backdropBlur: "--dream-studio-backdrop-blur",
    fontScale: "--dream-studio-font-scale",
    density: "--dream-studio-density",
  };
  const THEME_VARIABLES = [
    "--ds-bg", "--ds-panel", "--ds-panel-2", "--ds-green", "--ds-lime", "--ds-on-accent",
    "--ds-cyan", "--ds-purple", "--ds-text", "--ds-muted", "--ds-line",
    "--ds-bg-rgb", "--ds-panel-rgb", "--ds-panel-2-rgb", "--ds-accent-rgb",
    "--ds-accent-alt-rgb", "--ds-secondary-rgb", "--ds-highlight-rgb",
    "--ds-text-rgb", "--ds-muted-rgb", "--ds-line-rgb",
    "--dream-art-focus-x", "--dream-art-focus-y", "--dream-art-position",
    "--dream-skin-focus-x", "--dream-skin-focus-y", "--dream-skin-art-position",
    "--dream-skin-name", "--dream-skin-tagline", "--dream-skin-project-prefix",
    "--dream-skin-project-label", "--dream-skin-brand-subtitle", "--dream-skin-status",
    "--dream-skin-quote", "--dream-skin-art",
    "--ds-theme-color-background", "--ds-theme-color-panel",
    "--ds-theme-color-panel-alt", "--ds-theme-color-accent",
    "--ds-theme-color-accent-alt", "--ds-theme-color-secondary",
    "--ds-theme-color-highlight", "--ds-theme-color-text",
    "--ds-theme-color-muted", "--ds-theme-color-line",
    "--ds-theme-font-family", "--ds-theme-font-scale",
    "--ds-theme-surface-radius", "--ds-theme-surface-opacity",
    "--ds-theme-surface-blur", "--ds-theme-surface-border-alpha",
    "--ds-theme-surface-shadow", "--ds-theme-image-focus-x",
    "--ds-theme-image-focus-y", "--ds-theme-image-zoom",
    "--ds-theme-image-dim", "--ds-theme-image-task-intensity",
    "--ds-theme-density-scale", "--ds-theme-motion-level",
    ...Object.values(STUDIO_TOKEN_VARIABLES),
  ];
  const selectorByKey = new Map(SELECTOR_CONTRACT.selectors.map((entry) => [entry.key, entry]));
  const stableTestidSelector = (testid) => SELECTOR_CONTRACT.stableTestids?.includes(testid)
    ? `[data-testid="${testid}"]` : null;
  const installToken = {};
  const existingAnalysisCache = window[ANALYSIS_CACHE_KEY];
  const analysisCache = existingAnalysisCache && typeof existingAnalysisCache.get === "function" &&
    typeof existingAnalysisCache.set === "function" ? existingAnalysisCache : new Map();
  window[ANALYSIS_CACHE_KEY] = analysisCache;
  let artAnalysis = typeof THEME.artKey === "string" ? analysisCache.get(THEME.artKey) ?? null : null;
  let analysisTimer = null;
  let rootObserver = null;
  let partObserver = null;
  let bodyReadyHandler = null;
  let styleMode = null;
  let styleNode = null;
  let styleSheet = null;
  const studioTextNodeOriginals = new Map();
  const now = () => typeof performance === "object" && typeof performance.now === "function"
    ? performance.now() : Date.now();
  const metrics = {
    ensureCalls: 0,
    rootPasses: 0,
    routePasses: 0,
    layoutReads: 0,
    attributeWrites: 0,
    styleWrites: 0,
    styleRepairs: 0,
    partPasses: 0,
    partWrites: 0,
    textWrites: 0,
    navigationEvents: 0,
    safetyPasses: 0,
    analysisRuns: 0,
    analysisCacheHits: artAnalysis ? 1 : 0,
    firstEnsureMs: null,
    analysisMs: null,
  };

  const previous = window[STATE_KEY];
  if (typeof previous?.cleanup === "function") previous.cleanup();
  window[DISABLED_KEY] = false;

  const existingStyleRegistry = window[STYLE_REGISTRY_KEY];
  const styleRegistry = existingStyleRegistry instanceof Set ? existingStyleRegistry : new Set();
  window[STYLE_REGISTRY_KEY] = styleRegistry;
  const artUrl = (() => {
    const comma = artDataUrl.indexOf(",");
    const mime = /^data:([^;,]+)/.exec(artDataUrl)?.[1] || "image/png";
    const binary = atob(artDataUrl.slice(comma + 1));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return URL.createObjectURL(new Blob([bytes], { type: mime }));
  })();

  const cssString = (value) => JSON.stringify(String(value ?? ""));

  const setStyleProperty = (root, name, value) => {
    if (root.style.getPropertyValue(name) !== value) {
      root.style.setProperty(name, value);
      metrics.styleWrites += 1;
    }
  };

  const setAttribute = (root, name, value) => {
    const normalized = String(value);
    if (root.getAttribute(name) !== normalized) {
      root.setAttribute(name, normalized);
      metrics.attributeWrites += 1;
    }
  };

  const setTextContent = (node, value) => {
    if (node && node.textContent !== value) {
      node.textContent = value;
      metrics.textWrites += 1;
    }
  };

  const setStudioLabel = (node, value) => {
    if (!node || typeof value !== "string") return;
    let target = Array.from(node.childNodes || [])
      .find((child) => child.nodeType === Node.TEXT_NODE && child.textContent.trim());
    if (!target) {
      const candidates = Array.from(node.querySelectorAll?.("span, p") || [])
        .filter((candidate) => candidate.children.length === 0 && candidate.textContent.trim());
      target = candidates[candidates.length - 1];
    }
    if (!target) return;
    if (target.nodeType === Node.TEXT_NODE) {
      if (!studioTextNodeOriginals.has(target)) studioTextNodeOriginals.set(target, target.textContent);
      setTextContent(target, value);
      return;
    }
    if (!target.hasAttribute(STUDIO_ORIGINAL_TEXT_ATTR)) {
      target.setAttribute(STUDIO_ORIGINAL_TEXT_ATTR, target.textContent);
    }
    setTextContent(target, value);
  };

  const applyStudioCopy = () => {
    const studio = THEME.studio && typeof THEME.studio === "object" ? THEME.studio : null;
    if (!studio) return;
    const sidebarLabels = Array.isArray(studio.sidebarLabels) ? studio.sidebarLabels : [];
    const sidebarNav = selectorNodes("left-panel")[0]?.querySelector("nav");
    const sidebarItems = Array.from(sidebarNav?.querySelectorAll("button, a") || []);
    sidebarLabels.forEach((label, index) => setStudioLabel(sidebarItems[index], label));

    const suggestionLabels = Array.isArray(studio.suggestionLabels) ? studio.suggestionLabels : [];
    const suggestionButtons = Array.from(selectorNodes("home-suggestions")[0]?.querySelectorAll("button") || []);
    suggestionLabels.forEach((label, index) => setStudioLabel(suggestionButtons[index], label));
  };
