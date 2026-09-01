/* Canonical cross-platform renderer manifest. The injector composes the
   ordered renderer modules into this single isolated IIFE before evaluation. */
((cssText, artDataUrl, themeConfig) => {
  __DREAM_SKIN_RENDERER_CODE__
})(__DREAM_SKIN_CSS_JSON__, __DREAM_SKIN_ART_JSON__, __DREAM_SKIN_THEME_JSON__)
