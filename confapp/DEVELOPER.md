# ROHD-HCL Configuration App Development

## Workspace

The root `rohd_hcl` package and `confapp` form one Pub workspace. Resolve
dependencies from the repository root:

```bash
flutter pub get
```

The workspace has one root `pubspec.lock` and
`.dart_tool/package_config.json`. Overrides are stored beside the manifest
that owns the direct dependency.

Each workspace member still owns a `pubspec.yaml` and declares only its direct
dependencies. The root `rohd_hcl` package depends directly on `rohd`, while
the Flutter, schematic-viewer, hierarchy, widget, and source-navigator
dependencies belong to `confapp/pubspec.yaml`. Pub resolves both manifests
together. The helper writes the shared `rohd` override at the workspace root
and confapp-only overrides in `confapp/pubspec_overrides.yaml`.

## Dependency sources

The checked-in manifests use hosted release constraints. The helper generates
ignored override files beside the owning manifests when a dependency source
differs from its manifest entry:

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

Before a Configure task replaces or disables an existing override, it moves
the file to a sibling `pubspec_overrides.yaml.disabled`. If that backup already
exists, the task uses `.disabled.1`, `.disabled.2`, and so on. This applies to
both generated and manually maintained override files.

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

Each **Configure** task first collects the source in VS Code Quick Input. Git
and Local selections then open an editable terminal prompt. The prompt is
prefilled from that repository area's current saved configuration. Without
saved state, Git defaults to `github.com/intel/rohd:main` or
`github.com/intel/rohd-schematic-viewer:main`, and Local defaults to
`~/max/rohd` or `~/true-release/rohd-schematic-viewer`. For Git, enter the
repository and ref together, separated by the final colon. GitHub shorthand is
normalized to an HTTPS URL. Hosted does not open a second prompt. The helper
persists the separate ROHD and schematic-viewer Git repositories, refs, and
local paths so configuring one dependency group does not reset another.

## Running Confapp

```bash
flutter pub get
cd confapp
flutter run --profile -d web-server --web-hostname=0.0.0.0 --web-port=3000
```

Use **ROHD-HCL Confapp: Web Debug** for the current source configuration. If
port `8080` is in use, set `CONFAPP_WEB_PORT`; do not stop another developer's
server merely to reuse its port.

Use **ROHD-HCL Confapp: Web Release** to build and serve the supported
JavaScript release target. It uses the same port setting.

Use **ROHD-HCL Confapp: Web Release WASM** to build and serve the experimental
WASM target on port `8081`. Set `CONFAPP_WASM_WEB_PORT` to override that port.

## Browser validation

Open the forwarded web-server URL in VS Code's integrated browser and enable
Flutter accessibility semantics before inspecting controls. Prefer
accessible-name and role locators over canvas coordinates. Use accessibility
snapshots for state and screenshots for visual layout.

Keep browser-independent behavior in normal VM tests. The JavaScript web build
is the integration gate:

```bash
cd confapp
flutter test test/hcl/view/hcl_page_test.dart
flutter build web --debug --no-pub
```

The app imports `dart:html`, so JavaScript is the supported web target even if
Flutter reports a Wasm dry-run incompatibility.

## Validation

```bash
bash -n tool/confapp_dev_mode.sh tool/confapp_web_debug.sh \
  tool/confapp_web_release.sh tool/confapp_web_wasm.sh
python3 -m json.tool .vscode/tasks.json >/dev/null
flutter pub get
dart analyze --fatal-infos
```
