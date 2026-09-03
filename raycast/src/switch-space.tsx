import { Action, ActionPanel, Color, Icon, List, Toast, closeMainWindow, open, showToast } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { describeError, fetchSpaces, openSpaceSetup, switchToSpace } from "./projects.ts";
import { namedSpaces, sections, type Space } from "./spaces.ts";

const MISSION_CONTROL_SETTINGS =
  "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts";

export default function Command() {
  const { data, isLoading, error } = usePromise(fetchSpaces);

  if (error) {
    showToast({ style: Toast.Style.Failure, title: "Could not reach Projects", message: describeError(error) });
  }

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
            icon={space.current ? Icon.CheckCircle : Icon.Circle}
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
            icon={{ source: Icon.ExclamationMark, tintColor: Color.Orange }}
            title={space.name}
            accessories={[{ text: `${space.number}` }]}
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

function accessories(space: Space) {
  return space.current
    ? [{ text: `${space.number}` }, { tag: "current" }]
    : [{ text: `${space.number}` }];
}

async function act(action: (id: string) => Promise<void>, space: Space) {
  try {
    await action(space.id);
    await closeMainWindow();
  } catch (error) {
    await showToast({ style: Toast.Style.Failure, title: `Could not open ${space.name}`, message: describeError(error) });
  }
}
