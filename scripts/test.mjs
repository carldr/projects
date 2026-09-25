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

// The two streams are buffered separately and joined once the child has closed.
// Appending both to one string as the chunks arrive splices a line of one stream
// into a line of the other, because a chunk boundary is not a line boundary: a
// `✔ Test x() passed` line cut in half by a write to stderr matches neither regex
// and that test vanishes from the report. When the spliced line is a failure, the run
// ends with nothing in the Failures block, and only the suite's own non-zero exit code
// reports the failure.
function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("close", (code) => {
      const separator = out === "" || out.endsWith("\n") ? "" : "\n";
      resolve({ code, output: out + separator + err });
    });
  });
}

/**
 * swift-testing prints an issue line before the failure line for the same test.
 *
 * It also closes with a total, `Test run with N tests in M suites passed`, which is
 * the count to trust: swift-testing runs its suites concurrently and writes each
 * result line from the thread that produced it, so under load a line is sometimes
 * never written at all. `reportApp` returns both counts so that the caller can report
 * the difference between them.
 */
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
  const total = output.match(/^[✔✘] Test run with (\d+) tests? in \d+ suites?/m);
  return { seen, expected: total ? Number(total[1]) : undefined };
}

/**
 * `node --test` emits TAP when piped: `ok N - name`, with a YAML block on failure,
 * and closes with a `# tests N` total to check the parsed count against.
 */
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
  const total = output.match(/^# tests (\d+)$/m);
  return { seen, expected: total ? Number(total[1]) : undefined };
}

const unparsed = [];
const short = [];

/** Records a suite whose own total exceeds the number of lines parsed out of it. */
function checkCount(part, { seen, expected }) {
  if (expected !== undefined && seen < expected) {
    short.push({ part, seen, expected });
  }
}

const app = await run("xcodebuild", [
  "test",
  "-project",
  "app/Projects.xcodeproj",
  "-scheme",
  "Projects",
  "-destination",
  "platform=macOS",
]);
const appCounts = reportApp(app.output);
checkCount("app", appCounts);
if (appCounts.seen === 0 || (app.code !== 0 && failures.length === 0)) {
  unparsed.push({ part: "app", output: app.output });
}

const raycast = await run("pnpm", ["--dir", "raycast", "test"]);
const raycastFailures = failures.length;
const raycastCounts = reportRaycast(raycast.output);
checkCount("raycast", raycastCounts);
if (raycastCounts.seen === 0 || (raycast.code !== 0 && failures.length === raycastFailures)) {
  unparsed.push({ part: "raycast", output: raycast.output });
}

// A suite that ran more tests than it printed lines for. The missing lines never
// reached this process, so `scripts/test.mjs` cannot recover them. It prints the size
// of the shortfall instead.
for (const { part, seen, expected } of short) {
  console.log(
    `\n${part} ran ${expected} tests but printed ${seen} lines. ` +
      `${expected - seen} result line(s) were lost in its output, not skipped.`,
  );
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

// Last, so it survives a long list or a dumped log. The per-suite counts are here
// because a green app suite says nothing about the extension, and a green extension
// suite says nothing about the app: a zero beside either name is a suite that did not
// run. The counts come from each suite's own total where it printed one, so a lost
// result line leaves the summary correct.
const counted = ({ seen, expected }) => expected ?? seen;
const appTests = counted(appCounts);
const raycastTests = counted(raycastCounts);
const summary =
  `${appTests + raycastTests} tests, ${failures.length} ${failures.length === 1 ? "failure" : "failures"} ` +
  `(${appTests} app, ${raycastTests} raycast)`;
console.log("\n" + (failures.length === 0 ? green(summary) : red(summary)));

process.exit(app.code === 0 && raycast.code === 0 && failures.length === 0 ? 0 : 1);
