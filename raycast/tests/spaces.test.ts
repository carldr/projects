import test from "node:test";
import assert from "node:assert/strict";
import { parseSpaces, namedSpaces, sections } from "../src/spaces.ts";

const json = JSON.stringify([
  { id: "a", name: "Website", number: 7, current: true, previous: false, switchable: true },
  { id: "b", name: "", number: 3, current: false, previous: false, switchable: true },
  { id: "c", name: "Dotfiles", number: 11, current: false, previous: false, switchable: false },
  { id: "d", name: "Client portal", number: 2, current: false, previous: false, switchable: true },
]);

test("parses the JXA payload", () => {
  assert.equal(parseSpaces(json).length, 4);
});

test("drops spaces with an empty name", () => {
  // "sorts alphabetically by name, case-insensitively" covers the order.
  const ids = namedSpaces(parseSpaces(json)).map((s) => s.id);
  assert.deepEqual(new Set(ids), new Set(["a", "c", "d"]));
  assert.equal(ids.includes("b"), false);
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
    { id: "a", name: "Website", number: 7, current: false, previous: false, switchable: true },
    { id: "d", name: "Client portal", number: 2, current: true, previous: false, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Website", "Client portal"],
  );
});

test("sorts the previous Space to the top, ahead of names that sort earlier", () => {
  const json = JSON.stringify([
    { id: "a", name: "Client portal", number: 2, current: false, previous: false, switchable: true },
    { id: "b", name: "Website", number: 7, current: false, previous: true, switchable: true },
    { id: "c", name: "Dotfiles", number: 11, current: false, previous: false, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Website", "Client portal", "Dotfiles"],
  );
});

test("puts the previous Space first and the current Space last around the alphabetical rest", () => {
  const json = JSON.stringify([
    { id: "a", name: "Alpha", number: 1, current: true, previous: false, switchable: true },
    { id: "b", name: "Zulu", number: 2, current: false, previous: true, switchable: true },
    { id: "c", name: "Mike", number: 3, current: false, previous: false, switchable: true },
    { id: "d", name: "Bravo", number: 4, current: false, previous: false, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Zulu", "Bravo", "Mike", "Alpha"],
  );
});

test("keeps alphabetical order when no Space is current", () => {
  const json = JSON.stringify([
    { id: "a", name: "Website", number: 7, current: false, previous: false, switchable: true },
    { id: "d", name: "Client portal", number: 2, current: false, previous: false, switchable: true },
  ]);
  assert.deepEqual(
    namedSpaces(parseSpaces(json)).map((s) => s.name),
    ["Client portal", "Website"],
  );
});
