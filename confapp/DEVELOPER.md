# ROHD-HCL Configuration App Development

## Workspace

The root `rohd_hcl` package and `confapp` form one Pub workspace. Resolve
dependencies from the repository root:

```bash
flutter pub get
```

Confapp source assets are not needed for workspace resolution or root tests.
For Confapp builds and tests, `bash tool/generate_confapp_assets.sh` creates an
ignored project in `build/confapp`, including a generated `pubspec.yaml` and a
mirror of `lib/src/`. Asset entries are written to that generated manifest, not
to either `pubspec_overrides.yaml`. The generated project resolves dependencies
using the workspace lockfile and existing dependency overrides without modifying
them. It links to the Confapp source and
tests; rerun the generator after changing ROHD-HCL source files, dependencies,
overrides, or static assets. It requires `rsync`. In VS Code, the **Generate
Confapp Assets** task runs the generator.

The workspace has one root `pubspec.lock` and
`.dart_tool/package_config.json`. The checked-in root `pubspec_overrides.yaml`
declares the workspace; it and Confapp are excluded from the published package.

Each workspace member still owns a `pubspec.yaml` and declares only its direct
dependencies. The root `rohd_hcl` package depends directly on `rohd`, while
the Flutter, schematic-viewer, hierarchy, widget, and source-navigator
dependencies belong to `confapp/pubspec.yaml`. Pub resolves both manifests
together. The helper writes all temporary dependency overrides, including
`rohd`, to `confapp/pubspec_overrides.yaml`. Pub applies them to the entire
workspace.

## Dependency sources

The checked-in manifests use hosted release constraints. After resolving the
workspace with `flutter pub get`, the helper updates the ignored Confapp
override file when a dependency source differs from its manifest entry:

```bash
# Set the ROHD-family packages and viewer independently.
bash tool/confapp_dev_mode.sh configure-group all hosted
bash tool/confapp_dev_mode.sh configure-group schematic hosted
```

The **Configure ROHD Dependency**, **Configure Package Dependencies**,
**Configure Widget Dependencies**, and **Configure Schematic Dependency** tasks
accept `hosted`, `git`, or `local` and preserve the other source selections.

The group commands write an ignored `.confapp_dependency_sources` state file.
Selecting Hosted removes that package's override so Pub uses its
`pubspec.yaml` constraint. Only the selected dependencies are changed;
unrelated existing entries and other override settings are preserved. Prefer
one source for the ROHD companion packages unless deliberately validating a
mixed graph.

Before a Configure task changes an existing override, it copies the file to a
sibling `pubspec_overrides.yaml.disabled`. If that backup already exists, the
task uses `.disabled.1`, `.disabled.2`, and so on. If a selected dependency was
overridden at the root, the helper removes that entry there before writing the
new selection in Confapp; the root workspace declaration and unrelated entries
are preserved. This can leave the tracked root override modified in Git.

Older checkouts may have an ignored root `pubspec_overrides.yaml` containing
dependency overrides. Back it up before updating to a revision that tracks the
file. Move any overrides you still need to `confapp/pubspec_overrides.yaml`,
adjusting relative paths for its new location, or reselect them using the
Configure tasks.

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
bash tool/generate_confapp_assets.sh
cd build/confapp
flutter run --no-pub --profile -d web-server --web-hostname=0.0.0.0 --web-port=3000
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
cd build/confapp
flutter test --no-pub test/hcl/view/hcl_page_test.dart
flutter build web --debug --no-pub
```

Confapp's browser implementation uses `dart:js_interop` and `package:web`.
JavaScript remains the supported target; the separately documented Wasm
launcher is experimental.

## Validation

```bash
bash -n tool/confapp_dev_mode.sh tool/confapp_web_debug.sh \
  tool/confapp_web_release.sh tool/confapp_web_wasm.sh
python3 -m json.tool .vscode/tasks.json >/dev/null
flutter pub get
dart analyze --fatal-infos
```
