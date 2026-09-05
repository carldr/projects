import { showHUD } from "@raycast/api";
import { showFailureToast } from "@raycast/utils";
import { describeError, switchToPreviousSpace } from "./projects.ts";

/**
 * A `no-view` command: there is nothing to choose, so ⌘Space, the alias, Enter
 * switches straight away with no list in between.
 *
 * Success shows nothing but the HUD — the Space change is its own confirmation,
 * and the app's own overlay names the project you land on.
 */
export default async function Command() {
  try {
    await switchToPreviousSpace();
    await showHUD("Switched to the previous project");
  } catch (error) {
    await showFailureToast(error, { title: "Could not go back", message: describeError(error) });
  }
}
