import test from "node:test";
import assert from "node:assert/strict";
import { parseSpaces, namedSpaces, sections } from "../src/spaces.ts";

const json = JSON.stringify([
  { id: "a", name: "Website", number: 7, current: true, switchable: true },
  { id: "b", name: "", number: 3, current: false, switchable: true },
  { id: "c", name: "Dotfiles", number: 11, current: false, switchable: false },
  { id: "d", name: "Client portal", number: 2, current: false, switchable: true },
]);

test("parses the JXA payload", () => {
  assert.equal(parseSpaces(json).length, 4);
});

test("drops spaces with an empty name", () => {
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.id),
    ["d", "c", "a"],
  );
});

test("sorts alphabetically by name, case-insensitively", () => {
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Client portal", "Dotfiles", "Website"],
  );
});

test("splits switchable from unswitchable", () => {
  const s = sections(namedSpaces(parseSpaces(json)));
  assert.deepEqual(
    s.switchable.map((x) => x.name),
    ["Client portal", "Website"],
  );
  assert.deepEqual(
    s.unswitchable.map((x) => x.name),
    ["Dotfiles"],
  );
});

test("an empty payload yields empty sections", () => {
  const s = sections(namedSpaces(parseSpaces("[]")));
  assert.deepEqual(s, { switchable: [], unswitchable: [] });
});

test("sorts the current Space to the end, even when it would otherwise sort earlier", () => {
  const json = JSON.stringify([
    { id: "a", name: "Website", number: 7, current: false, switchable: true },
    { id: "d", name: "Client portal", number: 2, current: true, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Website", "Client portal"],
  );
});

test("keeps alphabetical order when no Space is current", () => {
  const json = JSON.stringify([
    { id: "a", name: "Website", number: 7, current: false, switchable: true },
    { id: "d", name: "Client portal", number: 2, current: false, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Client portal", "Website"],
  );
});
