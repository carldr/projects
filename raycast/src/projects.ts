import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { parseSpaces, type Space } from "./spaces.ts";

const run = promisify(execFile);

/**
 * JXA rather than AppleScript: `JSON.stringify` gives us the records as JSON, so
 * there is no AppleScript record syntax to parse out of stdout.
 */
async function jxa(source: string): Promise<string> {
  const { stdout } = await run("/usr/bin/osascript", ["-l", "JavaScript", "-e", source]);
  return stdout.trim();
}

export async function fetchSpaces(): Promise<Space[]> {
  return parseSpaces(await jxa('JSON.stringify(Application("Projects").listSpaces())'));
}

export async function switchToSpace(id: string): Promise<void> {
  await jxa(`Application("Projects").switchToSpace(${JSON.stringify(id)})`);
}

export async function openSpaceSetup(id: string): Promise<void> {
  await jxa(`Application("Projects").openSpaceSetupFor(${JSON.stringify(id)})`);
}

/** Turns osascript's failures into something a Raycast toast can usefully say. */
export function describeError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  // osascript appends the AppleEvent/OSStatus error code as a parenthesised integer
  // at the end of the message. Match only that trailing position, not the code
  // anywhere in the string — the app echoes ids verbatim into its own error text
  // (e.g. "No space with id bogus-600-id."), and an id is not an error code.
  const code = message.match(/\((-?\d+)\)\s*$/)?.[1];
  if (code === "-1743") {
    return "Raycast is not allowed to control Projects. Grant it under System Settings > Privacy & Security > Automation.";
  }
  if (code === "-600") {
    return "Projects is not running. Launch it and try again.";
  }
  return explain(message);
}

/**
 * Pulls the app's own message out of an `execFile` failure. `execFile` rejects with
 * `Command failed: <the whole osascript command line>\n<stderr>`, so the useful text —
 * the `execution error:` line the app prints to stderr — is never at the start of the
 * string; the old `^execution error:` match never fired. Find that line instead, then
 * strip its `execution error:` prefix, any duplicated `Error: Error:` noise, and the
 * trailing `(-NNNN)` code (already used for classification above, and meaningless to a
 * reader). If no such line exists, fall back to something short — never the raw blob,
 * which would put the command line itself, `osascript` and all, in a Raycast toast.
 */
function explain(message: string): string {
  const line = message.split("\n").find((l) => l.includes("execution error:"));
  if (line) {
    const text = line
      .replace(/^.*execution error:\s*/, "")
      .replace(/^(?:Error:\s*)+/, "")
      .replace(/\s*\(-?\d+\)\s*$/, "")
      .trim();
    return text || "Projects reported an unexpected error.";
  }
  // No `execution error:` line to pull out. If this is still the raw `execFile`
  // blob, its first line is the command itself — never surface that. Otherwise the
  // message is already short (e.g. a plain Error we constructed ourselves), so pass
  // it through as-is.
  return message.includes("Command failed:") ? "Projects reported an unexpected error." : message.trim();
}
