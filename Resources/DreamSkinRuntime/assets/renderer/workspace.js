  const workspaceUI = (() => {
    let controls = null, reading = null, navigation = null;
    const responseNodes = new Set();
    const variables = {
      sidebarOpacity: '--ds-ui-sidebar-opacity', sidebarDim: '--ds-ui-sidebar-dim', sidebarBlur: '--ds-ui-sidebar-blur',
      chatOpacity: '--ds-ui-chat-opacity', chatDim: '--ds-ui-chat-dim', chatBlur: '--ds-ui-chat-blur',
      rowSpacing: '--ds-ui-row-spacing', readingWidth: '--ds-ui-reading-width',
      summaryWidth: '--ds-ui-summary-width',
      dotBubbleColor: '--ds-dot-color', dotUserBubbleColor: '--ds-dot-user-color',
      dotSpacing: '--ds-dot-spacing', dotRadius: '--ds-dot-radius',
    };
    const focus = () => {
      const active = workspaceSession.focus ?? workspaceSettings.focusByDefault;
      document.documentElement.setAttribute('data-dream-reading', String(Boolean(active)));
      controls?.focus.setAttribute('aria-pressed', String(Boolean(active)));
      if (controls) controls.focus.textContent = active ? 'Exit reading' : 'Reading view';
    };
    const toggleFocus = () => { workspaceSession.focus = !(workspaceSession.focus ?? workspaceSettings.focusByDefault); focus(); };
    const groupResponses = () => {
      const desired = new Set();
      if (workspaceSettings.groupResponses) {
        // Decorate each message, never the turn containing tools or user replies.
        for (const message of document.querySelectorAll('.thread-scroll-container [data-markdown-text-style="assistant-message"], .thread-scroll-container [data-message-author-role="assistant"]')) {
          const bubble = message.closest('[data-local-conversation-final-assistant]')
            || message.closest('[data-response-annotation-target]') || message;
          if (!bubble.querySelector('[data-local-conversation-user-anchor], [data-message-author-role="user"]')) desired.add(bubble);
        }
      }
      for (const node of responseNodes) if (!desired.has(node)) node.removeAttribute('data-dream-response');
      responseNodes.clear();
      for (const node of desired) {
        if (!node.hasAttribute('data-dream-response')) node.setAttribute('data-dream-response', '');
        responseNodes.add(node);
      }
    };
    return {
      refresh() {
        if (!workspaceSettings.enabled) return;
        const root = document.documentElement;
        setAttribute(root, 'data-dream-workspace-ui', 'true');
        setAttribute(root, 'data-dream-dot-ui', String(workspaceSettings.dotEnabled));
        setAttribute(root, 'data-dream-wrap-titles', String(workspaceSettings.wrapTitles));
        setAttribute(root, 'data-dream-search-context', String(workspaceSettings.searchContext));
        setAttribute(root, 'data-dream-auto-hide-sidebar-scrollbar', String(workspaceSettings.autoHideSidebarScrollbar));
        for (const [name, variable] of Object.entries(variables)) {
          const unit = /Blur$|Spacing$|Width$|Radius$/.test(name) ? 'px' : '';
          setStyleProperty(root, variable, `${workspaceSettings[name]}${unit}`);
        }
        for (const [key, variable] of [['dotBubbleColor', '--ds-dot-text'], ['dotUserBubbleColor', '--ds-dot-user-text']]) {
          const value = parseInt(workspaceSettings[key].slice(1), 16);
          const luminance = ((value >> 16) & 255) * .299 + ((value >> 8) & 255) * .587 + (value & 255) * .114;
          setStyleProperty(root, variable, luminance > 155 ? '#111827' : '#FFFFFF');
        }
        if (!controls) {
          controls = createWorkspaceControls();
          controls.focus.addEventListener('click', toggleFocus);
          reading = createWorkspaceReading(controls);
          navigation = createWorkspaceNavigation(controls);
        }
        controls.mount(); focus(); groupResponses(); reading.refresh(); navigation.refresh();
      },
      dispose() {
        reading?.dispose(); navigation?.dispose();
        controls?.focus.removeEventListener('click', toggleFocus);
        controls?.dispose(); controls = null;
        for (const node of responseNodes) node.removeAttribute('data-dream-response');
        responseNodes.clear();
      },
    };
  })();
