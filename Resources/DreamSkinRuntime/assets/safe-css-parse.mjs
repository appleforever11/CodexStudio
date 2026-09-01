// Safe CSS source preflight and parser entrypoint.

import {
  MAX_SAFE_CSS_BYTES,
  FORBIDDEN_CONTROL,
  SafeCssValidationError,
} from "./safe-css-contract.mjs";
import { Parser } from "./safe-css-parser.mjs";

export function parseSafeCss(source, options = {}) {
  if (typeof source !== "string") {
    throw new TypeError("Safe CSS source must be a string");
  }
  const maxBytes = options.maxBytes ?? MAX_SAFE_CSS_BYTES;
  const bytes = new TextEncoder().encode(source).length;
  if (bytes < 1 || bytes > maxBytes) {
    throw new SafeCssValidationError(
      "limit/bytes",
      `Safe CSS must be between 1 and ${maxBytes} UTF-8 bytes`,
      1,
      1,
    );
  }
  const forbidden = source.search(FORBIDDEN_CONTROL);
  if (forbidden !== -1) {
    const parser = new Parser(source);
    parser.fail("syntax/control", "Safe CSS contains a forbidden control character", forbidden);
  }
  const comment = source.indexOf("/*");
  if (comment !== -1 || source.includes("*/")) {
    const parser = new Parser(source);
    parser.fail("syntax/comment", "Safe CSS comments are not allowed", comment === -1 ? source.indexOf("*/") : comment);
  }
  const escape = source.indexOf("\\");
  if (escape !== -1) {
    const parser = new Parser(source);
    parser.fail("syntax/escape", "Safe CSS escapes are not allowed", escape);
  }
  const parser = new Parser(source);
  return { bytes, ...parser.parse() };
}
