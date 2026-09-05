import test from "node:test";
import assert from "node:assert/strict";
import { commandSource } from "../src/projects.ts";

// A Space id reaches these tests from `spaceUUID` in a JSON file the user can edit,
// so an id is untrusted input interpolated into generated JavaScript source.
//
// Each expected value below is written out by hand from the rules of JavaScript
// string literals. Do not compute an expected value with `JSON.stringify`, which is
// the call the implementation makes.

test("passes a plain UUID through as a single argument", () => {
  assert.equal(
    commandSource("switchToSpace", "ABCDEF12-3456-7890-ABCD-EF1234567890"),
    'Application("Projects").switchToSpace("ABCDEF12-3456-7890-ABCD-EF1234567890")',
  );
});

test("omits the argument list entirely for a command that takes no parameter", () => {
  assert.equal(commandSource("switchToPreviousSpace"), 'Application("Projects").switchToPreviousSpace()');
});

test("escapes a double quote so an id cannot close the string literal early", () => {
  // Unescaped, the id's quote would close the argument and the rest would parse as
  // code: ...switchToSpace("nope") ; Application("Projects").switchToSpace("pwned")
  assert.equal(
    commandSource("switchToSpace", 'nope") ; Application("Projects").switchToSpace("pwned'),
    'Application("Projects").switchToSpace("nope\\") ; Application(\\"Projects\\").switchToSpace(\\"pwned")',
  );
});

test("escapes a backslash so it cannot escape the closing quote", () => {
  // Unescaped, a trailing backslash would escape the closing quote and run the
  // string on into the code after it.
  assert.equal(
    commandSource("openSpaceSetupFor", "weird\\id"),
    'Application("Projects").openSpaceSetupFor("weird\\\\id")',
  );
});

test("escapes a newline, which is not legal inside a JavaScript string literal", () => {
  assert.equal(commandSource("switchToSpace", "weird\nid"), 'Application("Projects").switchToSpace("weird\\nid")');
});

test("passes a line separator through unescaped, which ES2019 made legal", () => {
  // U+2028 survives as itself rather than as an escape sequence. U+2028 and U+2029
  // are legal inside a JavaScript string literal. `String.fromCharCode` keeps U+2028
  // itself out of this file, where it would occupy a column and show no glyph.
  const lineSeparator = String.fromCharCode(0x2028);
  assert.equal(
    commandSource("switchToSpace", `weird${lineSeparator}id`),
    `Application("Projects").switchToSpace("weird${lineSeparator}id")`,
  );
});
