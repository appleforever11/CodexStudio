import test from "node:test";
import assert from "node:assert/strict";
import { terminalOperation } from "../../Resources/DreamSkinRuntime/scripts/injector/operation-state.mjs";

test("completion is replayable after renderer setup", () => {
  const operation = { token: "1:123:1", status: "success", message: "Skin applied" };
  assert.deepEqual(terminalOperation(operation, operation.token), { state: "success", message: "Skin applied" });
  assert.deepEqual(terminalOperation(operation, operation.token), { state: "success", message: "Skin applied" });
});
test("older completion cannot finish a newer operation", () => {
  assert.equal(terminalOperation({ token: "old", status: "success" }, "new"), null);
});
test("busy state is not success and failures stay failures", () => {
  assert.equal(terminalOperation({ token: "a", status: "applying" }, "a"), null);
  assert.equal(terminalOperation({ token: "a", status: "failed" }, "a").state, "error");
});
