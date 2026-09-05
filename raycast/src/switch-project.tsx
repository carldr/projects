import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  PopToRootType,
  Toast,
  closeMainWindow,
  open,
  showToast,
} from "@raycast/api";
import { showFailureToast, usePromise } from "@raycast/utils";
import { describeError, fetchSpaces, openSpaceSetup, switchToSpace } from "./projects.ts";
import { namedSpaces, sections, type Space } from "./spaces.ts";

const MISSION_CONTROL_SETTINGS =
  "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts";

export default function Command() {
  const { data, isLoading, revalidate } = usePromise(fetchSpaces, [], {
    onError: (error) => {
      showFailureToast(error, {
        title: "Could not reach Projects",
        message: describeError(error),
        primaryAction: {
          title: "Retry",
          onAction: (toast) => {
            toast.hide();
            revalidate();
          },
        },
      });
    },
  });

  const { switchable, unswitchable } = sections(namedSpaces(data ?? []));

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Filter projects">
      <List.EmptyView
        icon={Icon.Window}
        title="No projects"
        description="Name a space in Projects' Settings, then try again."
      />
      <List.Section title="Projects">
        {switchable.map((space) => (
          <List.Item
            key={space.id}
            title={space.name}
            accessories={accessories(space)}
            actions={
              <ActionPanel>
                <Action title="Switch to Project" icon={Icon.ArrowRight} onAction={() => act(switchToSpace, space)} />
                <Action title="Open Project" icon={Icon.AppWindowGrid2x2} onAction={() => act(openSpaceSetup, space)} />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
      <List.Section title="No Mission Control shortcut">
        {unswitchable.map((space) => (
          <List.Item
            key={space.id}
            title={space.name}
            accessories={accessories(space)}
            actions={
              <ActionPanel>
                {/* A dead Enter reads as a broken extension, so offer the fix instead. */}
                <Action title="Open Mission Control Settings" icon={Icon.Gear} onAction={() => open(MISSION_CONTROL_SETTINGS)} />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}

/**
 * The Space number and, when they apply, the "previous" and "current" tags apply to
 * every row alike. A row for a Space with no Mission Control shortcut carries one
 * further accessory, a warning icon.
 */
function accessories(space: Space): List.Item.Accessory[] {
  // "Space 4" rather than a bare "4": Raycast renders plain accessory text in
  // the same grey pill it uses for key hints, leaving no way to tell a lone
  // digit from a key hint.
  const marks: List.Item.Accessory[] = [{ text: `Space ${space.number}` }];
  // The previous Space sorts above the alphabetical rows. The "previous" tag names
  // the top row as the previous Space; without the tag, the top row shows only a
  // project name and a Space number.
  if (space.previous) {
    marks.push({ tag: "previous" });
  }
  if (space.current) {
    marks.push({ tag: "current" });
  }
  if (!space.switchable) {
    marks.push({
      icon: { source: Icon.ExclamationMark, tintColor: Color.Orange },
      tooltip: "No Mission Control shortcut",
    });
  }
  return marks;
}

async function act(action: (id: string) => Promise<void>, space: Space) {
  try {
    await action(space.id);
    // Force an immediate pop to root, rather than relying on the user's "Pop to Root
    // Search" preference (closeMainWindow's default): the view must actually unmount
    // so that the next launch remounts it and usePromise refetches, instead of
    // reopening the same mounted view with its first fetch's now-stale `current` flag.
    await closeMainWindow({ popToRootType: PopToRootType.Immediate });
  } catch (error) {
    await showToast({ style: Toast.Style.Failure, title: `Could not open ${space.name}`, message: describeError(error) });
  }
}
