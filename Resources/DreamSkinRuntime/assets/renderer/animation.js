  // Animated WebP reuses the existing artwork surface. Freeze it when motion is
  // unwanted or the document is hidden; never animate text or input controls.
  const animationQuery = THEME.animatedArtwork && typeof matchMedia === "function"
    ? matchMedia("(prefers-reduced-motion: reduce)") : null;
  let frozenArtwork = null;
  let animationDisposed = false;
  const animationAllowed = () => !document.hidden && !animationQuery?.matches;
  const artworkValue = () => THEME.animatedArtwork && !animationAllowed()
    ? (frozenArtwork ? `url("${frozenArtwork}")` : "none")
    : `url("${artUrl}")`;
  const syncArtworkAnimation = () => {
    if (animationDisposed) return;
    setStyleProperty(document.documentElement, "--dream-skin-art", artworkValue());
  };
  if (THEME.animatedArtwork) {
    const still = new Image();
    still.onload = () => {
      if (animationDisposed) return;
      try {
        const canvas = document.createElement("canvas");
        canvas.width = still.naturalWidth;
        canvas.height = still.naturalHeight;
        canvas.getContext("2d").drawImage(still, 0, 0);
        frozenArtwork = canvas.toDataURL("image/png");
        syncArtworkAnimation();
      } catch {}
      still.removeAttribute("src");
    };
    still.src = artUrl;
    document.addEventListener("visibilitychange", syncArtworkAnimation);
    animationQuery?.addEventListener?.("change", syncArtworkAnimation);
  }
  const disposeArtworkAnimation = () => {
    animationDisposed = true;
    frozenArtwork = null;
    document.removeEventListener("visibilitychange", syncArtworkAnimation);
    animationQuery?.removeEventListener?.("change", syncArtworkAnimation);
  };
