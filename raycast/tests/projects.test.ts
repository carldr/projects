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
