#!/usr/bin/env bash
# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

mode="${1:-}"
root_overrides="pubspec_overrides.yaml"
confapp_overrides="confapp/pubspec_overrides.yaml"
source_state=".confapp_dependency_sources"
default_rohd_path="$HOME/max/rohd"
default_viewer_path="$HOME/true-release/rohd-schematic-viewer"

rohd_git_url="${ROHD_GIT_URL:-https://github.com/intel/rohd.git}"
rohd_git_ref="${ROHD_GIT_REF:-main}"
viewer_git_url="${SCHEMATIC_VIEWER_GIT_URL:-https://github.com/intel/rohd-schematic-viewer.git}"
viewer_git_ref="${SCHEMATIC_VIEWER_GIT_REF:-main}"
rohd_local_path="${ROHD_LOCAL_PATH:-$default_rohd_path}"
viewer_local_path="${SCHEMATIC_VIEWER_LOCAL_PATH:-${ROHD_SCHEMATIC_VIEWER_PATH:-$default_viewer_path}}"

usage() {
  cat <<'USAGE'
Usage: tool/confapp_dev_mode.sh <mode>

Configure individual package sources:
  tool/confapp_dev_mode.sh configure <package> <source> ...
  where each source is hosted, git, or local.

For example:
  tool/confapp_dev_mode.sh configure \
    rohd_schematic_viewer local \
    rohd_source_navigator local

Modes:
  manifest      Disable overrides and use pubspec.yaml sources.
  local-rohd    Use the local ROHD checkout and its split packages.
  local-viewer  Use the local schematic-viewer checkout.
  local-all     Use local ROHD packages and the local schematic viewer.
  show          Print the current generated override file, if present.
  configure-group  Configure a dependency group while preserving other sources.

Supported packages:
  rohd
  rohd_hierarchy
  rohd_devtools_widgets
  rohd_source_navigator
  rohd_schematic_viewer

The default local checkouts are ~/max/rohd and
~/true-release/rohd-schematic-viewer. Override them with ROHD_LOCAL_PATH and
SCHEMATIC_VIEWER_LOCAL_PATH.

Git sources use ROHD_GIT_URL, ROHD_GIT_REF, SCHEMATIC_VIEWER_GIT_URL, and
SCHEMATIC_VIEWER_GIT_REF. The VS Code tasks accept repository:ref in
ROHD_SOURCE_VALUE and SCHEMATIC_VIEWER_SOURCE_VALUE. Hosted sources use the
constraints in pubspec.yaml.

With no overrides, pubspec.yaml supplies the hosted release dependencies.
USAGE
}

check_workspace_overrides() {
  if [[ ! -f "$root_overrides" ]]; then
    echo "Missing $root_overrides; restore the checked-in workspace file." >&2
    exit 1
  fi
  if [[ ! -f .dart_tool/package_config.json ]]; then
    echo "Resolve the workspace first: flutter pub get" >&2
    exit 1
  fi
}

expand_home_path() {
  local path="$1"

  case "$path" in
    '~') printf '%s\n' "$HOME" ;;
    \~/*) printf '%s/%s\n' "$HOME" "${path:2}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

configure_git_source() {
  local spec="$1"
  local target="$2"
  local url
  local ref

  if [[ "$spec" != *:* ]]; then
    echo "Git source '$spec' must use the format repository:ref." >&2
    exit 2
  fi

  url="${spec%:*}"
  ref="${spec##*:}"
  if [[ -z "$url" || -z "$ref" || "$ref" == //* ]]; then
    echo "Git source '$spec' must use the format repository:ref." >&2
    exit 2
  fi

  case "$url" in
    github.com/*) url="https://$url" ;;
  esac

  case "$target" in
    rohd)
      rohd_git_url="$url"
      rohd_git_ref="$ref"
      ;;
    viewer)
      viewer_git_url="$url"
      viewer_git_ref="$ref"
      ;;
  esac
}

display_git_source() {
  local target="$1"
  local url
  local ref

  case "$target" in
    rohd)
      url="$rohd_git_url"
      ref="$rohd_git_ref"
      ;;
    viewer)
      url="$viewer_git_url"
      ref="$viewer_git_ref"
      ;;
  esac

  case "$url" in
    https://github.com/*)
      url="${url#https://}"
      url="${url%.git}"
      ;;
  esac
  printf '%s:%s\n' "$url" "$ref"
}

display_local_path() {
  local path="$1"

  case "$path" in
    "$HOME") printf '~\n' ;;
    "$HOME"/*) printf '~/%s\n' "${path#"$HOME"/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

prompt_source_value() {
  local target="$1"
  local source="$2"
  local default_value
  local prompt
  local value

  if [[ "${CONFAPP_PROMPT_SOURCE_VALUE:-0}" != 1 ||
    "$source" == "hosted" ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    echo "Interactive source prompting requires a terminal." >&2
    exit 2
  fi

  case "$target:$source" in
    rohd:git)
      default_value="$(display_git_source rohd)"
      prompt="ROHD Git repository:ref: "
      ;;
    rohd:local)
      default_value="$(display_local_path "$rohd_local_path")"
      prompt="Local ROHD checkout path: "
      ;;
    viewer:git)
      default_value="$(display_git_source viewer)"
      prompt="Schematic viewer Git repository:ref: "
      ;;
    viewer:local)
      default_value="$(display_local_path "$viewer_local_path")"
      prompt="Local schematic-viewer checkout path: "
      ;;
  esac

  IFS= read -e -r -i "$default_value" -p "$prompt" value
  value="${value:-$default_value}"
  if [[ "$target" == "rohd" ]]; then
    ROHD_SOURCE_VALUE="$value"
  else
    SCHEMATIC_VIEWER_SOURCE_VALUE="$value"
  fi
}

resolve_rohd_path() {
  local rohd_path="$rohd_local_path"

  rohd_path="$(expand_home_path "$rohd_path")"
  [[ "$rohd_path" = /* ]] || rohd_path="$repo_root/$rohd_path"
  if [[ ! -f "$rohd_path/pubspec.yaml" ]] ||
    ! grep -Eq '^name:[[:space:]]*rohd[[:space:]]*$' "$rohd_path/pubspec.yaml"; then
    echo "Could not find a ROHD checkout at $rohd_path." >&2
    echo "Set ROHD_LOCAL_PATH to a checkout rooted at the rohd package." >&2
    exit 1
  fi

  realpath "$rohd_path"
}

resolve_rohd_package_path() {
  local package="$1"
  local rohd_path
  local package_path

  rohd_path="$(resolve_rohd_path)"
  if [[ "$package" == "rohd" ]]; then
    package_path="$rohd_path"
  else
    package_path="$rohd_path/packages/$package"
  fi

  if [[ ! -f "$package_path/pubspec.yaml" ]] ||
    ! grep -Eq "^name:[[:space:]]*$package[[:space:]]*$" "$package_path/pubspec.yaml"; then
    echo "Missing local ROHD package: $package_path" >&2
    exit 1
  fi

  realpath "$package_path"
}

resolve_viewer_path() {
  local viewer_path="$viewer_local_path"

  viewer_path="$(expand_home_path "$viewer_path")"
  [[ "$viewer_path" = /* ]] || viewer_path="$repo_root/$viewer_path"
  if [[ ! -f "$viewer_path/pubspec.yaml" ]] ||
    ! grep -Eq '^name:[[:space:]]*rohd_schematic_viewer[[:space:]]*$' "$viewer_path/pubspec.yaml"; then
    echo "Could not find a schematic-viewer checkout at $viewer_path." >&2
    echo "Set SCHEMATIC_VIEWER_LOCAL_PATH to the package checkout." >&2
    exit 1
  fi

  realpath "$viewer_path"
}

validate_package() {
  case "$1" in
    rohd|rohd_hierarchy|rohd_devtools_widgets|rohd_source_navigator|rohd_schematic_viewer) ;;
    *)
      echo "Unsupported package '$1'." >&2
      echo "Run '$0 help' to see the supported packages." >&2
      exit 2
      ;;
  esac
}

validate_source() {
  local package="$1"
  local source="$2"

  case "$source" in
    hosted|git|local) ;;
    *)
      echo "Invalid dependency source '$source'; expected hosted, git, or local." >&2
      exit 2
      ;;
  esac

}

write_configured_overrides() {
  local args=("$@")
  local package
  local source
  local url
  local ref
  local path
  local index
  local -a edits=()
  local -A seen_packages=()

  check_workspace_overrides

  if [[ "${#args[@]}" -eq 0 || "$(( ${#args[@]} % 2 ))" -ne 0 ]]; then
    echo "Usage: $0 configure <package> <hosted|git|local> ..." >&2
    exit 2
  fi

  for ((index = 0; index < ${#args[@]}; index += 2)); do
    package="${args[index]}"
    source="${args[index + 1]}"
    validate_package "$package"
    validate_source "$package" "$source"
    if [[ -n "${seen_packages[$package]:-}" ]]; then
      echo "Package '$package' was configured more than once." >&2
      exit 2
    fi
    seen_packages["$package"]=1

    if [[ "$source" == "local" ]]; then
      if [[ "$package" == "rohd_schematic_viewer" ]]; then
        resolve_viewer_path >/dev/null
      else
        resolve_rohd_package_path "$package" >/dev/null
      fi
    fi
  done

  for ((index = 0; index < ${#args[@]}; index += 2)); do
    package="${args[index]}"
    source="${args[index + 1]}"
    url=""
    ref=""
    path=""
    case "$source" in
      hosted) ;;
      git)
        url="$rohd_git_url"
        ref="$rohd_git_ref"
        case "$package" in
          rohd) ;;
          rohd_schematic_viewer) url="$viewer_git_url"; ref="$viewer_git_ref" ;;
          *) path="packages/$package" ;;
        esac
        ;;
      local)
        if [[ "$package" == "rohd_schematic_viewer" ]]; then
          path="$(resolve_viewer_path)"
        else
          path="$(resolve_rohd_package_path "$package")"
        fi
        ;;
    esac
    edits+=("$package" "$source" "$url" "$ref" "$path")
  done

  dart "$repo_root/tool/update_confapp_overrides.dart" "$repo_root" "${edits[@]}"
}

write_source_state() {
  cat >"$source_state" <<STATE
rohd=$1
rohd_hierarchy=$2
rohd_devtools_widgets=$3
rohd_source_navigator=$4
rohd_schematic_viewer=$5
rohd_git_url=$rohd_git_url
rohd_git_ref=$rohd_git_ref
rohd_local_path=$rohd_local_path
viewer_git_url=$viewer_git_url
viewer_git_ref=$viewer_git_ref
viewer_local_path=$viewer_local_path
STATE
}

write_group_configuration() {
  local group="${1:-}"
  local source="${2:-}"
  local rohd_source="hosted"
  local hierarchy_source="hosted"
  local widgets_source="hosted"
  local navigator_source="hosted"
  local viewer_source="hosted"
  local package
  local saved_source

  if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 configure-group <rohd|package|widget|schematic|all> <source>" >&2
    exit 2
  fi

  if [[ -f "$source_state" ]]; then
    while IFS='=' read -r package saved_source; do
      case "$package" in
        rohd) rohd_source="$saved_source" ;;
        rohd_hierarchy) hierarchy_source="$saved_source" ;;
        rohd_devtools_widgets) widgets_source="$saved_source" ;;
        rohd_source_navigator) navigator_source="$saved_source" ;;
        rohd_schematic_viewer) viewer_source="$saved_source" ;;
        rohd_git_url)
          [[ -v ROHD_GIT_URL ]] || rohd_git_url="$saved_source"
          ;;
        rohd_git_ref)
          [[ -v ROHD_GIT_REF ]] || rohd_git_ref="$saved_source"
          ;;
        rohd_local_path)
          [[ -v ROHD_LOCAL_PATH ]] || rohd_local_path="$saved_source"
          ;;
        viewer_git_url)
          [[ -v SCHEMATIC_VIEWER_GIT_URL ]] ||
            viewer_git_url="$saved_source"
          ;;
        viewer_git_ref)
          [[ -v SCHEMATIC_VIEWER_GIT_REF ]] ||
            viewer_git_ref="$saved_source"
          ;;
        viewer_local_path)
          if [[ ! -v SCHEMATIC_VIEWER_LOCAL_PATH &&
            ! -v ROHD_SCHEMATIC_VIEWER_PATH ]]; then
            viewer_local_path="$saved_source"
          fi
          ;;
      esac
    done <"$source_state"
  fi

  if [[ "$group" == "schematic" ]]; then
    prompt_source_value viewer "$source"
  else
    prompt_source_value rohd "$source"
  fi

  case "$group" in
    rohd)
      validate_source rohd "$source"
      if [[ "$source" == "git" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        configure_git_source "$ROHD_SOURCE_VALUE" rohd
      elif [[ "$source" == "local" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        rohd_local_path="$(expand_home_path "$ROHD_SOURCE_VALUE")"
      fi
      rohd_source="$source"
      ;;
    package)
      validate_source rohd_hierarchy "$source"
      if [[ "$source" == "git" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        configure_git_source "$ROHD_SOURCE_VALUE" rohd
      elif [[ "$source" == "local" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        rohd_local_path="$(expand_home_path "$ROHD_SOURCE_VALUE")"
      fi
      hierarchy_source="$source"
      navigator_source="$source"
      ;;
    widget)
      validate_source rohd_devtools_widgets "$source"
      if [[ "$source" == "git" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        configure_git_source "$ROHD_SOURCE_VALUE" rohd
      elif [[ "$source" == "local" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        rohd_local_path="$(expand_home_path "$ROHD_SOURCE_VALUE")"
      fi
      hierarchy_source="$source"
      widgets_source="$source"
      navigator_source="$source"
      ;;
    schematic)
      validate_source rohd_schematic_viewer "$source"
      if [[ "$source" == "git" && -n "${SCHEMATIC_VIEWER_SOURCE_VALUE:-}" ]]; then
        configure_git_source "$SCHEMATIC_VIEWER_SOURCE_VALUE" viewer
      elif [[ "$source" == "local" && -n "${SCHEMATIC_VIEWER_SOURCE_VALUE:-}" ]]; then
        viewer_local_path="$(expand_home_path "$SCHEMATIC_VIEWER_SOURCE_VALUE")"
      fi
      viewer_source="$source"
      ;;
    all)
      validate_source rohd "$source"
      if [[ "$source" == "git" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        configure_git_source "$ROHD_SOURCE_VALUE" rohd
      elif [[ "$source" == "local" && -n "${ROHD_SOURCE_VALUE:-}" ]]; then
        rohd_local_path="$(expand_home_path "$ROHD_SOURCE_VALUE")"
      fi
      rohd_source="$source"
      hierarchy_source="$source"
      widgets_source="$source"
      navigator_source="$source"
      ;;
    *)
      echo "Invalid dependency group '$group'; expected rohd, package, widget, schematic, or all." >&2
      exit 2
      ;;
  esac

  case "$group" in
    rohd) write_configured_overrides rohd "$rohd_source" ;;
    package) write_configured_overrides rohd_hierarchy "$hierarchy_source" rohd_source_navigator "$navigator_source" ;;
    widget) write_configured_overrides rohd_hierarchy "$hierarchy_source" rohd_devtools_widgets "$widgets_source" rohd_source_navigator "$navigator_source" ;;
    schematic) write_configured_overrides rohd_schematic_viewer "$viewer_source" ;;
    all) write_configured_overrides rohd "$rohd_source" rohd_hierarchy "$hierarchy_source" rohd_devtools_widgets "$widgets_source" rohd_source_navigator "$navigator_source" ;;
  esac
  write_source_state \
    "$rohd_source" \
    "$hierarchy_source" \
    "$widgets_source" \
    "$navigator_source" \
    "$viewer_source"
}

use_manifest_dependencies() {
  write_configured_overrides \
    rohd hosted rohd_hierarchy hosted rohd_devtools_widgets hosted \
    rohd_source_navigator hosted rohd_schematic_viewer hosted
  rm -f -- "$source_state"
  echo "Removed ROHD-family overrides; unrelated overrides were preserved."
}

use_local_rohd_dependencies() {
  write_group_configuration all local
}

use_local_viewer_dependency() {
  write_group_configuration schematic local
}

use_all_local_dependencies() {
  write_group_configuration all local
  write_group_configuration schematic local
}

case "$mode" in
  configure)
    shift
    write_configured_overrides "$@"
    ;;
  configure-group) write_group_configuration "${2:-}" "${3:-}" ;;
  manifest) use_manifest_dependencies ;;
  local-rohd) use_local_rohd_dependencies ;;
  local-viewer) use_local_viewer_dependency ;;
  local-all) use_all_local_dependencies ;;
  show)
    for overrides in "$root_overrides" "$confapp_overrides"; do
      if [[ -f "$overrides" ]]; then
        echo "==> $overrides <=="
        cat "$overrides"
      else
        echo "No $overrides present."
      fi
    done
    ;;
  hp-hv)
    echo "Mode hp-hv is deprecated; use manifest." >&2
    use_manifest_dependencies
    ;;
  lp-hv)
    echo "Mode lp-hv is deprecated; use local-rohd." >&2
    use_local_rohd_dependencies
    ;;
  hp-lv)
    echo "Mode hp-lv is deprecated; use local-viewer." >&2
    use_local_viewer_dependency
    ;;
  lp-lv)
    echo "Mode lp-lv is deprecated; use local-all." >&2
    use_all_local_dependencies
    ;;
  -h|--help|help|"") usage ;;
  *) usage >&2; exit 2 ;;
esac
