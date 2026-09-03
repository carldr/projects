export type Space = {
  id: string;
  name: string;
  number: number;
  current: boolean;
  switchable: boolean;
};

/** The JSON `list spaces` returns through JXA. */
export function parseSpaces(json: string): Space[] {
  return JSON.parse(json) as Space[];
}

/**
 * Only Spaces the user has named. A Project record exists as soon as any field is
 * touched, so an empty name — not the absence of a record — is what "unconfigured"
 * means here.
 *
 * Alphabetical by name, except the current Space always sorts last: you never want
 * to switch to the Space you are already on, so it belongs out of the way rather
 * than sitting in the middle of the alphabetical run.
 */
export function namedSpaces(spaces: Space[]): Space[] {
  return spaces
    .filter((s) => s.name.trim() !== "")
    .sort(
      (a, b) =>
        Number(a.current) - Number(b.current) ||
        a.name.localeCompare(b.name, undefined, { sensitivity: "base" }),
    );
}

/** Spaces with no Mission Control shortcut cannot be switched to, so they list apart. */
export function sections(spaces: Space[]): { switchable: Space[]; unswitchable: Space[] } {
  return {
    switchable: spaces.filter((s) => s.switchable),
    unswitchable: spaces.filter((s) => !s.switchable),
  };
}
