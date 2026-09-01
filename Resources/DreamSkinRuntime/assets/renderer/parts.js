  const selectorHit = (key) => {
    const selector = selectorByKey.get(key)?.selector;
    if (!selector) return false;
    try { return Boolean(document.querySelector(selector)); } catch { return false; }
  };

  const stableTestidHit = (testid) => {
    const selector = stableTestidSelector(testid);
    if (!selector) return false;
    try { return Boolean(document.querySelector(selector)); } catch { return false; }
  };

  const partNodes = new Set();
  const composerBorderRestores = new Map();
  const queryAll = (selector) => {
    if (!selector) return [];
    try { return [...document.querySelectorAll(selector)]; } catch { return []; }
  };
  const selectorNodes = (key) => queryAll(selectorByKey.get(key)?.selector);
  const genericNodes = (selector) => queryAll(selector)
    .filter((node) => node && typeof node.setAttribute === "function");
  const genericInputNodes = () => genericNodes(
    'textarea, [contenteditable="true"], [role="textbox"]',
  ).filter((node) => !node.closest?.('[role="dialog"], [aria-modal="true"]'));
  const resolvedMainNode = () => {
    const exact = selectorNodes("shell-main")[0];
    if (exact) return exact;
    for (const input of genericInputNodes()) {
      const main = input.closest?.('main, [role="main"]');
      if (main && typeof main.setAttribute === "function") return main;
    }
    return genericNodes('main, [role="main"]')
      .find((node) => !node.closest?.('[role="dialog"], [aria-modal="true"]')) ?? null;
  };
  const fallbackMainNodes = () => selectorNodes("shell-main").length
    ? [] : [resolvedMainNode()].filter(Boolean);
  const fallbackSidebarNodes = () => {
    if (selectorNodes("left-panel").length) return [];
    const main = resolvedMainNode();
    const mainParent = main?.parentElement;
    if (!main || !mainParent) return [];
    const candidate = genericNodes('aside, nav[aria-label]')
      .filter((node) => !main.contains?.(node))
      .filter((node) => !node.closest?.('[role="dialog"], [aria-modal="true"]'))
      .find((node) => node.parentElement === mainParent
        || node.parentElement?.parentElement === mainParent
        || node.parentElement === mainParent.parentElement);
    return candidate ? [candidate] : [];
  };
  const fallbackComposerNodes = () => selectorNodes("composer-chrome").length
    ? [] : (() => {
      const main = resolvedMainNode();
      for (const input of genericInputNodes()) {
        if (main && !main.contains?.(input)) continue;
        const layoutRoot = input.closest?.('[class*="_ComposerLayoutRoot_"]');
        if (layoutRoot && (!main || main.contains?.(layoutRoot))) return [layoutRoot];
        const semanticOwner = input.closest?.(
          '.composer-surface-chrome, [data-composer-surface-variant][data-composer-radius-variant], ' +
          '[class*="_ComposerLayoutRoot_"]',
        );
        if (semanticOwner && (!main || main.contains?.(semanticOwner))) return [semanticOwner];
        const ownerSelector =
          '[data-testid*="composer" i], [data-testid*="prompt" i], ' +
          '[class*="composer" i], [class*="prompt" i]';
        const nearest = input.closest?.(ownerSelector);
        if (!nearest || (main && !main.contains?.(nearest))) continue;
        let owner = nearest;
        for (let parent = nearest.parentElement; parent && parent !== main;
          parent = parent.parentElement) {
          if (parent.matches?.(ownerSelector)) owner = parent;
        }
        return [owner];
      }
      return [];
    })();
  const fallbackComposerToolbarNodes = (composerNodes) => {
    if (selectorNodes("composer-toolbar").length || !composerNodes.length) return [];
    return genericNodes(
      '[data-composer-footer-responsive], [class*="_ComposerLayoutFooter_"], [class*="_footer_"]',
    ).filter((node) => composerNodes.some((composer) =>
      composer !== node && composer.contains?.(node)));
  };
  const addPart = (desired, part, nodes) => {
    for (const node of nodes) {
      if (node && typeof node.setAttribute === "function" && !desired.has(node)) {
        desired.set(node, part);
      }
    }
  };
  const restoreComposerBorders = (node) => {
    const saved = composerBorderRestores.get(node);
    if (!saved) return;
    for (const [property, { value, priority }] of saved) {
      if (value) node.style.setProperty(property, value, priority);
      else node.style.removeProperty(property);
      metrics.styleWrites += 1;
    }
    composerBorderRestores.delete(node);
  };
  const refreshComposerBorders = (composerNodes) => {
    const desired = new Set(COMPOSER_BORDER_BRIDGES.length ? composerNodes : []);
    for (const node of composerBorderRestores.keys()) {
      if (!desired.has(node)) restoreComposerBorders(node);
    }
    for (const node of desired) {
      if (!node?.style || composerBorderRestores.has(node)) continue;
      const saved = new Map();
      for (const { property, variable } of COMPOSER_BORDER_BRIDGES) {
        saved.set(property, {
          value: node.style.getPropertyValue(property),
          priority: node.style.getPropertyPriority(property),
        });
        node.style.setProperty(property, `var(${variable})`, "important");
        metrics.styleWrites += 1;
      }
      composerBorderRestores.set(node, saved);
    }
  };
  const resolvedMessageNodes = () => selectorNodes("message").map((node) => {
    if (!node?.hasAttribute?.("data-local-conversation-user-anchor")) return node;
    // Current Codex user anchors span the conversation column. Prefer the
    // adaptive native bubble, while retaining the older anchor as a fallback.
    return node.querySelector?.(
      '[class*="max-w-"][class*="rounded-2xl"][class*="text-start"]',
    ) ?? node;
  });
  const refreshParts = () => {
    metrics.partPasses += 1;
    const desired = new Map();
    addPart(desired, "root", [document.documentElement]);
    addPart(desired, "sidebar", [...selectorNodes("left-panel"), ...fallbackSidebarNodes()]);
    addPart(desired, "header", selectorNodes("header-tint"));
    // Route-specific parts win when a generic shell collapses home and main
    // onto the same element.
    addPart(desired, "home", selectorNodes("home-route"));
    addPart(desired, "main", [...selectorNodes("shell-main"), ...fallbackMainNodes()]);
    addPart(desired, "project-list", selectorNodes("project-selector"));
    addPart(desired, "thread", selectorNodes("thread-surface"));
    addPart(desired, "message", resolvedMessageNodes());
    const composerNodes = [...selectorNodes("composer-chrome"), ...fallbackComposerNodes()];
    addPart(desired, "composer", composerNodes);
    addPart(desired, "composer-toolbar", [
      ...selectorNodes("composer-toolbar"), ...fallbackComposerToolbarNodes(composerNodes),
    ]);
    addPart(desired, "dialog", selectorNodes("overlay-dialog"));
    const homeHero = selectorNodes("game-source")[0] ??
      selectorNodes("home-icon")[0]?.parentElement;
    addPart(desired, "home-hero", homeHero ? [homeHero] : []);

    for (const node of partNodes) {
      if (!desired.has(node)) {
        node.removeAttribute?.(PART_ATTR);
        metrics.partWrites += 1;
      }
    }
    partNodes.clear();
    for (const [node, part] of desired) {
      if (node.getAttribute?.(PART_ATTR) !== part) {
        node.setAttribute(PART_ATTR, part);
        metrics.partWrites += 1;
      }
      partNodes.add(node);
    }
    refreshComposerBorders(composerNodes);
    applyStudioCopy();
  };

  const removeParts = () => {
    for (const node of [...composerBorderRestores.keys()]) restoreComposerBorders(node);
    for (const node of partNodes) node.removeAttribute?.(PART_ATTR);
    partNodes.clear();
    for (const node of queryAll(`[${PART_ATTR}]`)) node.removeAttribute?.(PART_ATTR);
  };
