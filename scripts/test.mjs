#!/usr/bin/env node
// Runs both test suites and prints one line per test, then a Failures block when
// anything failed. Nothing else reaches stdout.
//
// Each suite reports in its own format, so each needs its own parser: the Swift
// suite streams swift-testing lines, and `node --test` emits TAP once its output is
// a pipe rather than a terminal. When a suite exits non-zero and no failing test was
// parsed out of it — a build error, or a crash partway through — its whole log is
// printed, so a failure is never reduced to silence.

import { spawn } from "node:child_process";

const colour = process.stdout.isTTY;
const green = (s) => (colour ? `[32m${s}[0m` : s);
const red = (s) => (colour ? `[31m${s}[0m` : s);

const PART_WIDTH = 7;
const failures = [];

function pass(part, name) {
  console.log(`${green("✔")}  ${part.padEnd(PART_WIDTH)}  ${name}`);
}

function fail(part, name, detail) {
  console.log(`${red("✘")}  ${part.padEnd(PART_WIDTH)}  ${name}`);
  failures.push({ part, name, detail });
}

function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.on("data", (d) => (output += d));
    child.stderr.on("data", (d) => (output += d));
    child.on("close", (code) => resolve({ code, output }));
  });
}

/** swift-testing prints an issue line before the failure line for the same test. */
function reportApp(output) {
  const issues = new Map();
  let seen = 0;
  for (const line of output.split("\n")) {
    const issue = line.match(/^✘ Test (.+?)\(\) recorded an issue at (\S+?): (.*)$/);
    if (issue) {
      const [, name, where, why] = issue;
      issues.set(name, `${why}\n    ${where.replace(/:$/, "")}`);
      continue;
    }
    const passed = line.match(/^✔ Test (.+?)\(\) passed/);
    if (passed) {
      pass("app", passed[1]);
      seen += 1;
      continue;
    }
    const failed = line.match(/^✘ Test (.+?)\(\) failed/);
    if (failed) {
      fail("app", failed[1], issues.get(failed[1]) ?? "No issue detail in the log.");
      seen += 1;
    }
  }
  return seen;
}

/** `node --test` emits TAP when piped: `ok N - name`, with a YAML block on failure. */
function reportRaycast(output) {
  const lines = output.split("\n");
  let seen = 0;
  for (let i = 0; i < lines.length; i += 1) {
    const passed = lines[i].match(/^ok \d+ - (.+?)(?: # .*)?$/);
    if (passed) {
      pass("raycast", passed[1]);
      seen += 1;
      continue;
    }
    const failed = lines[i].match(/^not ok \d+ - (.+?)(?: # .*)?$/);
    if (!failed) continue;
    // The indented YAML block that follows carries the reason and the location. The
    // reason arrives as `error: |-` with the message on the lines after it, so those
    // lines are collected until the next key.
    const block = [];
    for (let j = i + 1; j < lines.length && /^\s/.test(lines[j]); j += 1) {
      block.push(lines[j].trim());
    }
    const errorAt = block.findIndex((l) => l.startsWith("error:"));
    let error = "";
    if (errorAt !== -1) {
      const inline = block[errorAt].replace(/^error:\s*\|?-?\s*/, "");
      const following = [];
      for (let j = errorAt + 1; j < block.length && !/^[a-z_]+:/.test(block[j]); j += 1) {
        if (block[j] !== "" && block[j] !== "...") following.push(block[j]);
      }
      error = [inline, ...following].filter(Boolean).join(" ");
    }
    const location = block
      .find((l) => l.startsWith("location:"))
      ?.replace(/^location:\s*/, "")
      .replace(/^'|'$/g, "");
    fail("raycast", failed[1], [error, location].filter(Boolean).join("\n    ") || "No detail in the TAP output.");
    seen += 1;
  }
  return seen;
}

const unparsed = [];

const app = await run("xcodebuild", [
  "test",
  "-project",
  "app/Projects.xcodeproj",
  "-scheme",
  "Projects",
  "-destination",
  "platform=macOS",
]);
if (reportApp(app.output) === 0 || (app.code !== 0 && failures.length === 0)) {
  unparsed.push({ part: "app", output: app.output });
}

const raycast = await run("npm", ["test", "--prefix", "raycast"]);
const raycastFailures = failures.length;
if (reportRaycast(raycast.output) === 0 || (raycast.code !== 0 && failures.length === raycastFailures)) {
  unparsed.push({ part: "raycast", output: raycast.output });
}

if (failures.length > 0) {
  console.log("\nFailures:\n");
  for (const { part, name, detail } of failures) {
    console.log(`  ${part}  ${name}`);
    console.log(`    ${detail}\n`);
  }
}

for (const { part, output } of unparsed) {
  console.log(`\n${part} produced no test results. Its full output follows.\n`);
  console.log(output);
}

process.exit(app.code === 0 && raycast.code === 0 && failures.length === 0 ? 0 : 1);
