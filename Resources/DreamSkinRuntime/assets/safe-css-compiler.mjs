// Runtime-layer CSS compiler and compatibility bridges.

import {
  COMPOSER_BORDER_BRIDGE_PROPERTIES,
  CORE_BACKGROUND_IMAGE_PARTS,
  RUNTIME_CASCADE_LAYER,
} from "./safe-css-contract.mjs";

export function compileRuntimeCss(parsed) {
  const compiledRules = [];
  const composerBaseBorderProperties = new Set();
  for (const { selector, declarations } of parsed.rules) {
    if (selector.part !== "composer" || selector.state) continue;
    for (const { property } of declarations) {
      if (COMPOSER_BORDER_BRIDGE_PROPERTIES.has(property)) {
        composerBaseBorderProperties.add(property);
      }
    }
  }
  for (const { selector: selectorRecord, declarations } of parsed.rules) {
    const { part, selector } = selectorRecord;
    const runtimeDeclarations = [];
    for (const declaration of declarations) {
      runtimeDeclarations.push(declaration);
      if (
        declaration.property === "background-color"
        && CORE_BACKGROUND_IMAGE_PARTS.has(part)
      ) {
        runtimeDeclarations.push({ property: "background-image", value: "none" });
      }
      if (
        part === "composer"
        && composerBaseBorderProperties.has(declaration.property)
      ) {
        runtimeDeclarations.push({
          property: `--ds-community-composer-${declaration.property}`,
          value: declaration.value,
        });
      }
    }
    const body = runtimeDeclarations
      .map(({ property, value }) => `    ${property}: ${value} !important;`)
      .join("\n");
    compiledRules.push(`  ${selector} {\n${body}\n  }`);

    if (part === "root") {
      const bodyDeclarations = [];
      for (const declaration of declarations) {
        if (![
          "background-color", "color", "font-family", "font-size", "font-weight",
          "letter-spacing", "line-height",
        ].includes(declaration.property)) continue;
        bodyDeclarations.push(declaration);
      }
      if (bodyDeclarations.length > 0) {
        const bodyBridge = bodyDeclarations
          .map(({ property, value }) => `    ${property}: ${value} !important;`)
          .join("\n");
        compiledRules.push(`  ${selector} body {\n${bodyBridge}\n  }`);
      }
    }

    const toolbarColor = part === "composer-toolbar"
      ? declarations.find(({ property }) => property === "color") : null;
    if (toolbarColor) {
      const controls = `${selector} :where(button:not([class~="bg-token-foreground"]), ` +
        `button:not([class~="bg-token-foreground"]) *)`;
      compiledRules.push(`  ${controls} {\n    color: ${toolbarColor.value} !important;\n  }`);
    }
  }
  const rules = compiledRules.join("\n");
  return `@layer ${RUNTIME_CASCADE_LAYER} {\n${rules}\n}\n`;
}
