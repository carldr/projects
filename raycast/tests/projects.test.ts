import test from "node:test";
import assert from "node:assert/strict";
import { describeError } from "../src/projects.ts";

test("explains a denied Automation grant", () => {
  const message = describeError(new Error("execution error: Not authorized to send Apple events (-1743)"));
  assert.match(message, /Automation/);
});

test("explains the app not running", () => {
  const message = describeError(new Error("Application isn't running (-600)"));
  assert.match(message, /Projects/);
});

test("passes other messages through", () => {
  assert.match(describeError(new Error("No space with id nope.")), /No space with id nope/);
});

test("does not misclassify a Space id containing -600 as 'not running'", () => {
  const message = describeError(
    new Error("execution error: Error: Error: No space with id bogus-600-id. (-10000)"),
  );
  assert.doesNotMatch(message, /not running/i);
  assert.match(message, /bogus-600-id/);
});

test("does not misclassify a Space id containing -1743 as an Automation grant", () => {
  const message = describeError(
    new Error("execution error: Error: Error: No space with id bogus-1743-id. (-10000)"),
  );
  assert.doesNotMatch(message, /Automation/);
  assert.match(message, /bogus-1743-id/);
});

test("strips the command echo and error boilerplate from the fallback message", () => {
  const message = describeError(
    new Error(
      'Command failed: /usr/bin/osascript -l JavaScript -e Application("Projects").switchToSpace("x")\nexecution error: Error: Error: No space with id x. (-10000)\n',
    ),
  );
  assert.equal(message, "No space with id x.");
  assert.doesNotMatch(message, /osascript/);
  assert.doesNotMatch(message, /Command failed/);
  assert.doesNotMatch(message, /\(-10000\)/);
});
