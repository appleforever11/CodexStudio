  const createWorkspaceReading = (controls) => {
    let thread = null, resize = null, mutation = null, frame = null;
    let reading = false, unread = false, inputUntil = 0, anchor = null, anchorY = 0;
    let previousTop = 0, previousHeight = 0, route = '';
    const reverse = () => getComputedStyle(thread).flexDirection === 'column-reverse';
    const distance = () => reverse() ? Math.abs(thread.scrollTop)
      : Math.max(0, thread.scrollHeight - thread.clientHeight - thread.scrollTop);
    const routeKey = () => document.querySelector('[data-app-action-sidebar-thread-selected="true"]')
      ?.getAttribute('data-app-action-sidebar-thread-id') || '';
    const remember = () => {
      if (!thread) return;
      const r = thread.getBoundingClientRect();
      let hit = document.elementFromPoint(Math.min(r.right - 24, r.x + r.width * .45), r.y + 90);
      anchor = hit?.closest('[data-content-search-unit-key], [data-local-conversation-item-target-ids], [data-message-author-role]');
      if (anchor && !thread.contains(anchor)) anchor = null;
      anchorY = anchor?.getBoundingClientRect().top ?? 0;
      previousTop = thread.scrollTop; previousHeight = thread.scrollHeight;
    };
    const update = () => {
      if (!thread?.isConnected) { controls.latestHost.hidden = true; return; }
      const away = distance() > 64;
      if (!away) unread = false;
      const blocked = getComputedStyle(thread).overflowY === 'hidden' || !!document.querySelector('[aria-modal="true"]');
      const visible = workspaceSettings.showLatest && away && !blocked;
      controls.latestHost.hidden = !visible;
      const label = unread ? '↓ New activity · Return to latest' : '↓ Return to latest';
      if (controls.latest.textContent !== label) controls.latest.textContent = label;
      document.documentElement.toggleAttribute('data-dream-latest-owned', Boolean(workspaceSettings.showLatest && !blocked));
      if (visible) {
        const r = thread.getBoundingClientRect();
        const composer = document.querySelector('[data-thread-scroll-footer] [data-ds-part="composer"]')?.getBoundingClientRect();
        const x = composer?.width ? composer.x + composer.width / 2 : r.x + r.width / 2;
        const y = composer?.height ? composer.top - 48 : r.bottom - 64;
        controls.latestHost.style.left = `${Math.max(140, Math.min(innerWidth - 140, x))}px`;
        controls.latestHost.style.top = `${Math.max(r.top + 48, y)}px`;
      }
    };
    const reconcile = () => {
      frame = null;
      if (!thread?.isConnected) return;
      if (route !== routeKey()) { route = routeKey(); reading = false; unread = false; anchor = null; }
      if (reading && workspaceSettings.preserveReading && performance.now() > inputUntil
        && !document.querySelector('[aria-modal="true"]')) {
        // Keep a visible text anchor fixed only after the user deliberately
        // scrolls away. Never seize navigation, selection, or composer focus.
        if (anchor?.isConnected) {
          const delta = anchor.getBoundingClientRect().top - anchorY;
          if (Math.abs(delta) > 1) thread.scrollTop += delta;
        } else if (thread.scrollHeight !== previousHeight && reverse()) {
          thread.scrollTop = previousTop - (thread.scrollHeight - previousHeight);
        }
      }
      if (reading && thread.scrollHeight !== previousHeight) unread = true;
      remember(); update();
    };
    const schedule = () => { if (frame === null) frame = setTimeout(reconcile, 16); };
    const input = (event) => {
      if (event.type === 'keydown' && !['ArrowUp','ArrowDown','PageUp','PageDown','Home','End',' '].includes(event.key)) return;
      inputUntil = performance.now() + 350;
    };
    const scroll = () => {
      if (performance.now() <= inputUntil) { reading = distance() > 64; remember(); }
      if (reading && performance.now() > inputUntil && workspaceSettings.preserveReading) schedule();
      if (distance() <= 64 && !reading) unread = false;
      update();
    };
    const jump = () => {
      if (!thread) return;
      reading = false; unread = false; anchor = null;
      thread.scrollTo({ top: reverse() ? 0 : thread.scrollHeight, behavior: 'instant' });
      remember(); update();
    };
    const detach = () => {
      if (frame !== null) clearTimeout(frame);
      frame = null; resize?.disconnect(); mutation?.disconnect();
      for (const name of ['wheel','touchstart','pointerdown','keydown']) thread?.removeEventListener(name, input);
      thread?.removeEventListener('scroll', scroll);
      thread = null; reading = false; unread = false; anchor = null;
    };
    const focusInput = (event) => {
      if (event.target.closest?.('[contenteditable="true"],textarea,input')) { reading = false; anchor = null; }
    };
    document.addEventListener('focusin', focusInput);
    controls.latest.addEventListener('click', jump);
    window.addEventListener('resize', schedule);
    return {
      refresh() {
        const next = document.querySelector('.thread-scroll-container');
        if (next !== thread) {
          detach(); thread = next;
          if (thread) {
            route = routeKey();
            for (const name of ['wheel','touchstart','pointerdown','keydown']) thread.addEventListener(name, input, { passive: true });
            thread.addEventListener('scroll', scroll, { passive: true });
            mutation = new MutationObserver(schedule);
            mutation.observe(thread, { childList: true, subtree: true, characterData: true });
            resize = new ResizeObserver(schedule);
            resize.observe(thread); for (const child of thread.children) resize.observe(child);
            remember();
          }
        }
        update();
      },
      dispose() {
        detach(); window.removeEventListener('resize', schedule);
        controls.latest.removeEventListener('click', jump);
        document.removeEventListener('focusin', focusInput);
        document.documentElement.removeAttribute('data-dream-latest-owned');
      },
    };
  };
