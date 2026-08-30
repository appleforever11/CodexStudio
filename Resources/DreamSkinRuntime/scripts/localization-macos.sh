#!/bin/bash

# Shared English user-facing text for macOS runtime scripts. Machine-readable
# output must never depend on these strings.

dreamskin_language() {
  if [ -n "${DREAMSKIN_RESOLVED_LANG:-}" ]; then
    /usr/bin/printf '%s' "$DREAMSKIN_RESOLVED_LANG"
    return 0
  fi

  DREAMSKIN_RESOLVED_LANG="en"
  /usr/bin/printf '%s' "$DREAMSKIN_RESOLVED_LANG"
}

dreamskin_text() {
  local key="${1:-}"
  local language=""
  language="$(dreamskin_language)"
  case "$language:$key" in
    en:operation_timeout) /usr/bin/printf '%s' 'Operation timed out. Try again.' ;;
    en:skin_applying_label) /usr/bin/printf '%s' 'Skin applying' ;;
    en:skin_pausing_label) /usr/bin/printf '%s' 'Skin pausing' ;;
    en:skin_unavailable) /usr/bin/printf '%s' 'Skin unavailable' ;;
    en:operation_failed_short) /usr/bin/printf '%s' 'operation failed' ;;
    en:cancelled_short) /usr/bin/printf '%s' 'cancelled' ;;
    en:applying_selected_theme) /usr/bin/printf '%s' 'Applying selected theme' ;;
    en:skin_applied) /usr/bin/printf '%s' 'Skin applied' ;;
    en:theme_switch_unconfirmed) /usr/bin/printf '%s' 'Theme switch did not finish; the result is unconfirmed' ;;
    en:switching_theme) /usr/bin/printf '%s' 'Switching theme' ;;
    en:apply_unconfirmed) /usr/bin/printf '%s' 'Apply failed; the result is unconfirmed' ;;
    en:applying_skin) /usr/bin/printf '%s' 'Applying skin' ;;
    en:cancelled_unchanged) /usr/bin/printf '%s' 'Operation cancelled; the previous skin is unchanged' ;;
    en:pause_failed) /usr/bin/printf '%s' 'Pause failed; the previous state may be unchanged' ;;
    en:pause_failed_alert) /usr/bin/printf '%s' 'Pause failed. Reopen the menu to check the current state.' ;;
    en:pausing_skin) /usr/bin/printf '%s' 'Pausing skin' ;;
    en:skin_paused) /usr/bin/printf '%s' 'Skin paused' ;;
    en:selected_theme) /usr/bin/printf '%s' 'Selected theme' ;;
    en:continue) /usr/bin/printf '%s' 'Continue' ;;
    en:cancel) /usr/bin/printf '%s' 'Cancel' ;;
    en:restart_prompt) /usr/bin/printf '%s' 'ChatGPT must restart once to enable the skin. This usually takes 10–30 seconds.' ;;
    en:restart_and_apply) /usr/bin/printf '%s' 'Restart and apply' ;;
    en:open_and_apply) /usr/bin/printf '%s' 'Open and apply' ;;
    en:reapply) /usr/bin/printf '%s' 'Reapply' ;;
    en:repair_and_apply) /usr/bin/printf '%s' 'Repair and apply' ;;
    en:apply) /usr/bin/printf '%s' 'Apply' ;;
    en:click_received) /usr/bin/printf '%s' 'Request received…' ;;
    en:engine_script_missing) /usr/bin/printf '%s' 'Could not load the engine script' ;;
    en:cancelled_progress) /usr/bin/printf '%s' 'Cancelled; the previous skin is unchanged' ;;
    en:opening_and_applying) /usr/bin/printf '%s' 'Opening ChatGPT and applying the skin…' ;;
    en:checking_chatgpt) /usr/bin/printf '%s' 'Checking ChatGPT…' ;;
    en:hot_reload) /usr/bin/printf '%s' 'Trying a live skin reload…' ;;
    en:apply_complete) /usr/bin/printf '%s' 'Complete: skin applied' ;;
    en:connecting_debug) /usr/bin/printf '%s' 'Starting or connecting to the debug port…' ;;
    en:apply_failed) /usr/bin/printf '%s' 'Apply failed' ;;
    en:default_theme_name) /usr/bin/printf '%s' 'My Theme' ;;
    en:loading_image) /usr/bin/printf '%s' 'Loading image…' ;;
    en:theme_ready_not_applied) /usr/bin/printf '%s' 'Theme ready (not applied)' ;;
    en:starting_chatgpt_for_apply) /usr/bin/printf '%s' 'The current session is unavailable; starting ChatGPT and applying the theme…' ;;
    en:image_saved_apply_failed) /usr/bin/printf '%s' 'The image was saved, but applying the skin failed. Click Apply Skin to retry.' ;;
    en:validating_theme_content) /usr/bin/printf '%s' 'Validating theme content…' ;;
    en:publishing_validated_theme) /usr/bin/printf '%s' 'Publishing the validated theme…' ;;
    en:applying_theme_to_chatgpt) /usr/bin/printf '%s' 'Applying the theme to ChatGPT…' ;;
    en:verifying_rendered_theme) /usr/bin/printf '%s' 'Verifying the rendered theme…' ;;
    en:restarting_chatgpt_for_apply) /usr/bin/printf '%s' 'Restarting ChatGPT to apply and verify the theme…' ;;
    en:theme_switch_apply_failed) /usr/bin/printf '%s' 'The theme was switched, but applying the skin failed. Click Apply Skin to retry.' ;;
    en:ok) /usr/bin/printf '%s' 'OK' ;;
    *) return 1 ;;
  esac
}
