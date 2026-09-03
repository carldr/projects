import test from "node:test";
import assert from "node:assert/strict";
import { commandSource } from "../src/projects.ts";

/**
 * Runs `source` as real JS against a stub `Application`, so a broken escape either
 * throws a syntax error or calls through with the wrong arguments — both fail the
 * assertion — while a correct escape calls through with exactly the original id.
 */
function callArgs(source: string): unknown[] {
  let args: unknown[] | undefined;
  function Application(_name: string) {
    return {
      switchToSpace: (...a: unknown[]) => {
        args = a;
      },
      openSpaceSetupFor: (...a: unknown[]) => {
        args = a;
      },
    };
  }
  new Function("Application", source)(Application);
  assert.ok(args, "the generated source did not call the stubbed command");
  return args;
}

test("passes a plain UUID through as a single argument", () => {
  const id = "ABCDEF12-3456-7890-ABCD-EF1234567890";
  const args = callArgs(commandSource("switchToSpace", id));
  assert.equal(args.length, 1);
  assert.equal(args[0], id);
});

test("an id containing a double quote cannot terminate the string literal early", () => {
  const id = 'nope") ; Application("Projects").switchToSpace("pwned';
  const args = callArgs(commandSource("switchToSpace", id));
  assert.equal(args.length, 1);
  assert.equal(args[0], id);
});

test("an id containing a backslash round-trips intact", () => {
  const id = "weird\\id";
  const args = callArgs(commandSource("openSpaceSetupFor", id));
  assert.equal(args.length, 1);
  assert.equal(args[0], id);
});

test("an id containing a newline round-trips intact", () => {
  const id = "weird\nid";
  const args = callArgs(commandSource("switchToSpace", id));
  assert.equal(args.length, 1);
  assert.equal(args[0], id);
});
