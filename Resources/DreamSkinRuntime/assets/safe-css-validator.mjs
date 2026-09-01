// Stable Safe CSS validation facade. Grammar and compilation live in focused modules.

import {
  MAX_SAFE_CSS_BYTES,
  MAX_RULES,
  MAX_DECLARATIONS,
  MAX_VALUE_CHARACTERS,
  SAFE_CSS_PARTS,
  SAFE_CSS_STATES,
  SAFE_CSS_VARIABLES,
  SAFE_PROPERTIES,
  SafeCssValidationError,
} from "./safe-css-contract.mjs";
import { parseSafeCss } from "./safe-css-parse.mjs";
import { compileRuntimeCss } from "./safe-css-compiler.mjs";

export {
  SafeCssValidationError,
  SAFE_CSS_PARTS,
  SAFE_CSS_VARIABLES,
  SAFE_CSS_STATES,
} from "./safe-css-contract.mjs";

function validationResult(parsed) {
  return Object.freeze({
    contract: "dreamskin-safe-css/1",
    status: "validated",
    bytes: parsed.bytes,
    ruleCount: parsed.ruleCount,
    declarationCount: parsed.declarationCount,
  });
}

export function validateSafeCss(source, options = {}) {
  return validationResult(parseSafeCss(source, options));
}

export function compileSafeCss(source, options = {}) {
  return compileRuntimeCss(parseSafeCss(source, options));
}

export function decodeAndValidateSafeCss(bytes, options = {}) {
  if (!(bytes instanceof Uint8Array)) throw new TypeError("Safe CSS bytes must be a Uint8Array");
  let source;
  try {
    source = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new SafeCssValidationError("syntax/utf8", "Safe CSS is not valid UTF-8", 1, 1);
  }
  const parsed = parseSafeCss(source, options);
  return {
    source,
    runtimeSource: compileRuntimeCss(parsed),
    validation: validationResult(parsed),
  };
}

export const SAFE_CSS_CONTRACT = Object.freeze({
  contract: "dreamskin-safe-css/1",
  maxBytes: MAX_SAFE_CSS_BYTES,
  maxRules: MAX_RULES,
  maxDeclarations: MAX_DECLARATIONS,
  maxValueCharacters: MAX_VALUE_CHARACTERS,
  parts: SAFE_CSS_PARTS,
  states: SAFE_CSS_STATES,
  variables: SAFE_CSS_VARIABLES,
  properties: Object.freeze([...SAFE_PROPERTIES].sort()),
});
