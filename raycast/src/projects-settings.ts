import { closeMainWindow } from "@raycast/api";
import { showFailureToast } from "@raycast/utils";
import { describeError, openSettings } from "./projects.ts";

/**
 * A `no-view` command: the Settings window opening is its own confirmation, so
 * success shows nothing.
 */
export default async function Command() {
  try {
    await closeMainWindow();
    await openSettings();
  } catch (error) {
    await showFailureToast(error, { title: "Could not open Settings", message: describeError(error) });
  }
}
