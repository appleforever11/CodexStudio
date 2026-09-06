// Pure reconciliation shared by initial renderer setup and completion delivery.
export function terminalOperation(operation, token) {
  if (!operation || operation.token !== token) return null;
  const state = { success: "success", paused: "success", failed: "error", cancelled: "cancelled" }[operation.status];
  if (!state) return null;
  return { state, message: operation.message || (state === "error" ? "Operation failed; try again" : "Operation complete") };
}
