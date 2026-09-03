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
  if (message.includes("-1743")) {
    return "Raycast is not allowed to control Projects. Grant it under System Settings > Privacy & Security > Automation.";
  }
  if (message.includes("-600") || message.includes("isn't running")) {
    return "Projects is not running. Launch it and try again.";
  }
  return message.replace(/^execution error:\s*/, "").trim();
}
