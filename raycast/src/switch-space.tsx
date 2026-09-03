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
    <List isLoading={isLoading} searchBarPlaceholder="Filter spaces">
      <List.EmptyView
        icon={Icon.Window}
        title="No named spaces"
        description="Name a space in Projects' Settings, then try again."
      />
      <List.Section title="Spaces">
        {switchable.map((space) => (
          <List.Item
            key={space.id}
            icon={icon(space)}
            title={space.name}
            accessories={accessories(space)}
            actions={
              <ActionPanel>
                <Action title="Switch to Space" icon={Icon.ArrowRight} onAction={() => act(switchToSpace, space)} />
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
            icon={icon(space)}
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

/** The current Space, switchable or not, is marked the same way everywhere it appears. */
function icon(space: Space) {
  return space.current ? Icon.CheckCircle : Icon.Circle;
}

/**
 * The Space number and, when current, the "current" tag apply to every row alike.
 * Unswitchable rows get one more accessory on top: the warning that explains why
 * there is no switch action here.
 */
function accessories(space: Space): List.Item.Accessory[] {
  const marks: List.Item.Accessory[] = [{ text: `${space.number}` }];
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
