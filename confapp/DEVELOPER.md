# ROHD-HCL Configuration App Development

## Workspace

The root `rohd_hcl` package and `confapp` form one Pub workspace. Resolve
dependencies from the repository root:

```bash
flutter pub get
```

The workspace has one root `pubspec.lock`, `.dart_tool/package_config.json`,
and optional `pubspec_overrides.yaml`. Do not create
`confapp/pubspec_overrides.yaml`.

## Dependency sources

The checked-in manifests use hosted release constraints. The helper generates
the ignored root `pubspec_overrides.yaml` when a dependency source differs
from its manifest entry:

```bash
# Set the ROHD-family packages and viewer independently.
bash tool/confapp_dev_mode.sh configure-group all hosted
bash tool/confapp_dev_mode.sh configure-group schematic hosted
```

The **Configure ROHD Dependency**, **Configure Package Dependencies**,
**Configure Widget Dependencies**, and **Configure Schematic Dependency** tasks
accept `hosted`, `git`, or `local` and preserve the other source selections.

The group commands write an ignored `.confapp_dependency_sources` state file.
The generated override contains only Git and Local entries; selecting Hosted
removes that package from the override so Pub uses its `pubspec.yaml`
constraint. Prefer one source for the ROHD companion packages unless
deliberately validating a mixed graph.

The common local shortcuts are:

```bash
bash tool/confapp_dev_mode.sh local-rohd
bash tool/confapp_dev_mode.sh local-viewer
bash tool/confapp_dev_mode.sh local-all
```

The defaults are `~/max/rohd` and
`~/true-release/rohd-schematic-viewer`; override them with `ROHD_LOCAL_PATH`
and `SCHEMATIC_VIEWER_LOCAL_PATH`.

Use **Configure All ROHD Dependency Sources** to set the four published
ROHD-family packages at once. The web build and run tasks use the selected
source configuration without changing it.

Each **Configure** task collects the source and one empty source-value field in
VS Code Quick Input. For Git, enter the ref (or leave it empty for `main`).
For Local, enter the checkout path (or leave it empty for `~/max/rohd` or
`~/true-release/rohd-schematic-viewer`). The value is ignored for Hosted.

## Running Confapp

```bash
flutter pub get
cd confapp
flutter run --profile -d web-server --web-hostname=0.0.0.0 --web-port=3000
```

Use **ROHD-HCL Confapp: Web Debug** for the current source configuration. If
port `8080` is in use, set `CONFAPP_WEB_PORT`; do not stop another developer's
server merely to reuse its port.

## Browser validation

Open the forwarded web-server URL in VS Code's integrated browser and enable
Flutter accessibility semantics before inspecting controls. Prefer
accessible-name and role locators over canvas coordinates. Use accessibility
snapshots for state and screenshots for visual layout.

Keep browser-independent behavior in normal VM tests. The JavaScript web build
is the integration gate:

```bash
cd confapp
flutter test test/hcl/view/output_pane_tabs_test.dart
flutter build web --debug --no-pub
```

The app imports `dart:html`, so JavaScript is the supported web target even if
Flutter reports a Wasm dry-run incompatibility.

## Validation

```bash
bash -n tool/confapp_dev_mode.sh tool/confapp_web_debug.sh
python3 -m json.tool .vscode/tasks.json >/dev/null
flutter pub get
dart analyze --fatal-infos
```
