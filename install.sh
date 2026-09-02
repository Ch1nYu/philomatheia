#!/bin/sh
set -eu

skill_name="philomatheia"
source_path=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
destination_root=${PHILOMATHEIA_DEST_ROOT:-"${HOME}/.agents/skills"}
update=0
dry_run=0

usage() {
    printf '%s\n' "Usage: ./install.sh [--dest-root PATH] [--update] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dest-root)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            destination_root=$2
            shift 2
            ;;
        --update)
            update=1
            shift
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -f "$source_path/SKILL.md" ] || {
    printf 'SKILL.md was not found beside this installer: %s\n' "$source_path/SKILL.md" >&2
    exit 1
}
for item in agents assets references scripts/init_project.py scripts/validate_state.py; do
    [ -e "$source_path/$item" ] || {
        printf 'Required runtime path is missing: %s\n' "$source_path/$item" >&2
        exit 1
    }
done

destination_path="$destination_root/$skill_name"
if [ -e "$destination_path" ] && [ "$update" -ne 1 ]; then
    printf 'Destination already exists: %s. Re-run with --update to replace the installed skill.\n' "$destination_path" >&2
    exit 1
fi

action="Install"
past_action="Installed"
if [ "$update" -eq 1 ]; then
    action="Update"
    past_action="Updated"
fi
if [ "$dry_run" -eq 1 ]; then
    printf '%s %s at %s\n' "$action" "$skill_name" "$destination_path"
    exit 0
fi

mkdir -p "$destination_root"
staging_path=$(mktemp -d "$destination_root/.philomatheia-stage.XXXXXX")
backup_path="$destination_root/.philomatheia-old.$$"

cleanup() {
    [ ! -d "$staging_path" ] || rm -rf -- "$staging_path"
}
trap cleanup EXIT HUP INT TERM

for item in SKILL.md agents assets references; do
    if [ -e "$source_path/$item" ]; then
        cp -R "$source_path/$item" "$staging_path/$item"
    fi
done
mkdir "$staging_path/scripts"
for item in init_project.py validate_state.py; do
    if [ -f "$source_path/scripts/$item" ]; then
        cp "$source_path/scripts/$item" "$staging_path/scripts/$item"
    fi
done

[ -f "$staging_path/SKILL.md" ] || {
    printf 'Installation verification failed: staged SKILL.md is missing.\n' >&2
    exit 1
}
for item in scripts/init_project.py scripts/validate_state.py; do
    [ -f "$staging_path/$item" ] || {
        printf 'Installation verification failed: staged %s is missing.\n' "$item" >&2
        exit 1
    }
done

if [ -e "$destination_path" ]; then
    mv "$destination_path" "$backup_path"
fi

if mv "$staging_path" "$destination_path"; then
    if [ -e "$backup_path" ]; then
        rm -rf -- "$backup_path"
    fi
else
    if [ ! -e "$destination_path" ] && [ -e "$backup_path" ]; then
        mv "$backup_path" "$destination_path"
    fi
    exit 1
fi

trap - EXIT HUP INT TERM
printf '%s %s at %s\n' "$past_action" "$skill_name" "$destination_path"
printf '%s\n' 'Codex usually detects the skill automatically. Restart Codex if it does not appear.'
printf '%s\n' 'Invoke it with: $philomatheia'
