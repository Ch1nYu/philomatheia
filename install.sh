#!/bin/sh
set -eu

skill_name="philomatheia"
source_path=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
update=0
dry_run=0
all=0
list_only=0
dest_roots=""
interactive_selection=0
newline='
'

# Harnesses this installer can recognise, as "name|marker directory|skills
# directory". Recognition never implies selection: a destination is used only
# when it is chosen explicitly.
known_harnesses="Codex|${HOME}/.agents|${HOME}/.agents/skills
Claude Code|${HOME}/.claude|${HOME}/.claude/skills"

usage() {
    printf '%s\n' "Usage: ./install.sh [--dest-root PATH]... [--all] [--list] [--update] [--dry-run]"
    printf '%s\n' ""
    printf '%s\n' "Installs the runtime skill files into the agent skills directories you choose."
    printf '%s\n' "No destination is used by default. With no --dest-root and no --all, the"
    printf '%s\n' "installer lists the known harnesses with their status and asks which to use."
    printf '%s\n' ""
    printf '%s\n' "  --dest-root PATH  install into PATH; repeat for several directories"
    printf '%s\n' "  --all             install into every known harness directory that exists"
    printf '%s\n' "  --list            print the harness status table and exit"
    printf '%s\n' "  --update          replace an existing installation"
    printf '%s\n' "  --dry-run         print what would be installed and exit"
    printf '%s\n' ""
    printf '%s\n' "Known harnesses:"
    printf '%s\n' "  \$HOME/.agents/skills   Codex"
    printf '%s\n' "  \$HOME/.claude/skills   Claude Code"
    printf '%s\n' "PHILOMATHEIA_DEST_ROOT sets one destination when no flag is given."
}

add_root() {
    case "$newline$dest_roots" in
        *"$newline$1$newline"*) return 0 ;;
    esac
    dest_roots="$dest_roots$1$newline"
}

harness_status() {
    # harness_status MARKER SKILLS_ROOT
    if [ -e "$2/$skill_name" ]; then
        printf 'installed'
    elif [ -d "$1" ]; then
        printf 'detected, not installed'
    else
        printf 'harness not found'
    fi
}

pad_right() {
    # pad_right STRING WIDTH
    padded=$1
    while [ ${#padded} -lt "$2" ]; do
        padded="$padded "
    done
    printf '%s' "$padded"
}

print_target_table() {
    # print_target_table [numbered]
    numbered=${1:-0}
    name_width=0
    root_width=0
    old_ifs=$IFS
    IFS=$newline
    for line in $known_harnesses; do
        name=${line%%|*}
        rest=${line#*|}
        root=${rest#*|}
        [ ${#name} -le "$name_width" ] || name_width=${#name}
        [ ${#root} -le "$root_width" ] || root_width=${#root}
    done
    index=0
    for line in $known_harnesses; do
        index=$((index + 1))
        name=${line%%|*}
        rest=${line#*|}
        marker=${rest%%|*}
        root=${rest#*|}
        if [ "$numbered" -eq 1 ]; then
            printf '%3d) ' "$index"
        else
            printf '  '
        fi
        printf '%s  %s  %s\n' "$(pad_right "$name" "$name_width")" \
            "$(pad_right "$root" "$root_width")" "$(harness_status "$marker" "$root")"
    done
    IFS=$old_ifs
}

harness_count() {
    old_ifs=$IFS
    IFS=$newline
    count=0
    for line in $known_harnesses; do
        if [ -n "$line" ]; then
            count=$((count + 1))
        fi
    done
    IFS=$old_ifs
    printf '%s' "$count"
}

harness_root_at() {
    # harness_root_at INDEX
    old_ifs=$IFS
    IFS=$newline
    index=0
    for line in $known_harnesses; do
        index=$((index + 1))
        if [ "$index" -eq "$1" ]; then
            rest=${line#*|}
            printf '%s' "${rest#*|}"
            break
        fi
    done
    IFS=$old_ifs
}

can_prompt() {
    [ -z "${PHILOMATHEIA_NON_INTERACTIVE:-}" ] || return 1
    : < /dev/tty 2>/dev/null || return 1
    return 0
}

ask() {
    # ask PROMPT -> answer in $reply
    printf '%s' "$1" >&2
    IFS= read -r reply < /dev/tty || return 1
    return 0
}

select_destinations() {
    count=$(harness_count)
    custom_index=$((count + 1))

    {
        printf 'Select where to install %s. Nothing is selected by default.\n\n' "$skill_name"
        print_target_table 1
        printf '%3d) %s\n\n' "$custom_index" "Another directory (enter the path yourself)"
    } >&2

    while :; do
        ask 'Numbers separated by commas (for example 1,2), or Enter to cancel: ' || return 0
        [ -n "$reply" ] || return 0

        selection=$(printf '%s' "$reply" | tr ',' ' ')
        valid=1
        chosen=""
        set -f
        for token in $selection; do
            case "$token" in
                ''|*[!0-9]*)
                    printf 'Not a listed choice: %s\n' "$token" >&2
                    valid=0
                    break
                    ;;
            esac
            if [ "$token" -lt 1 ] || [ "$token" -gt "$custom_index" ]; then
                printf 'Not a listed choice: %s\n' "$token" >&2
                valid=0
                break
            fi
            if [ "$token" -eq "$custom_index" ]; then
                ask 'Skills directory path: ' || { valid=0; break; }
                if [ -z "$reply" ]; then
                    printf 'No path given.\n' >&2
                    valid=0
                    break
                fi
                chosen="$chosen$reply$newline"
            else
                chosen="$chosen$(harness_root_at "$token")$newline"
            fi
        done
        set +f
        [ "$valid" -eq 1 ] || continue
        if [ -z "$chosen" ]; then
            printf 'Nothing selected.\n' >&2
            continue
        fi

        old_ifs=$IFS
        IFS=$newline
        for root in $chosen; do
            [ -n "$root" ] && add_root "$root"
        done
        IFS=$old_ifs
        return 0
    done
}

confirm_replacement() {
    # confirm_replacement PATH
    while :; do
        ask "$1 already holds an installation. Replace it? [y/N] " || return 1
        case "$reply" in
            ''|n|N|no|NO|No) return 1 ;;
            y|Y|yes|YES|Yes) return 0 ;;
        esac
    done
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dest-root)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            add_root "$2"
            shift 2
            ;;
        --all)
            all=1
            shift
            ;;
        --list)
            list_only=1
            shift
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

if [ "$list_only" -eq 1 ]; then
    print_target_table 0
    exit 0
fi

if [ -z "$dest_roots" ]; then
    if [ "$all" -eq 1 ]; then
        old_ifs=$IFS
        IFS=$newline
        for line in $known_harnesses; do
            rest=${line#*|}
            marker=${rest%%|*}
            root=${rest#*|}
            if [ -d "$marker" ] || [ -e "$root/$skill_name" ]; then
                add_root "$root"
            fi
        done
        IFS=$old_ifs
        [ -n "$dest_roots" ] || {
            printf 'No known harness directory exists, so --all selected nothing.\n' >&2
            printf 'Pass --dest-root with the skills directory to use.\n' >&2
            exit 1
        }
    elif [ -n "${PHILOMATHEIA_DEST_ROOT:-}" ]; then
        add_root "$PHILOMATHEIA_DEST_ROOT"
    elif can_prompt; then
        interactive_selection=1
        select_destinations
        if [ -z "$dest_roots" ]; then
            printf 'Nothing selected. No changes were made.\n'
            exit 0
        fi
    else
        printf 'No destination was selected, and this session cannot prompt for one.\n' >&2
        printf 'Known harness directories:\n' >&2
        print_target_table 0 >&2
        printf 'Choose a destination with --dest-root, install into every detected harness\n' >&2
        printf 'with --all, or run the installer interactively.\n' >&2
        exit 2
    fi
fi

if [ "$update" -ne 1 ] && [ "$dry_run" -ne 1 ]; then
    old_ifs=$IFS
    IFS=$newline
    for destination_root in $dest_roots; do
        [ -n "$destination_root" ] || continue
        [ -e "$destination_root/$skill_name" ] || continue
        if [ "$interactive_selection" -eq 1 ]; then
            if confirm_replacement "$destination_root/$skill_name"; then
                continue
            fi
            printf 'Cancelled. No changes were made.\n'
            exit 0
        fi
        printf 'Destination already exists: %s. Re-run with --update to replace the installed skill.\n' \
            "$destination_root/$skill_name" >&2
        exit 1
    done
    IFS=$old_ifs
fi

if [ "$dry_run" -eq 1 ]; then
    old_ifs=$IFS
    IFS=$newline
    for destination_root in $dest_roots; do
        [ -n "$destination_root" ] || continue
        if [ -e "$destination_root/$skill_name" ]; then
            printf 'Update %s at %s\n' "$skill_name" "$destination_root/$skill_name"
        else
            printf 'Install %s at %s\n' "$skill_name" "$destination_root/$skill_name"
        fi
    done
    IFS=$old_ifs
    exit 0
fi

install_one() {
    destination_root=$1
    destination_path="$destination_root/$skill_name"
    past_action="Installed"
    [ ! -e "$destination_path" ] || past_action="Updated"

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
}

old_ifs=$IFS
IFS=$newline
for destination_root in $dest_roots; do
    [ -n "$destination_root" ] || continue
    IFS=$old_ifs
    install_one "$destination_root"
    IFS=$newline
done
IFS=$old_ifs

printf '%s\n' 'Most harnesses detect a new skill automatically. Restart the agent if it does not appear.'
printf '%s\n' 'Then ask it to teach or map a subject, or invoke the skill by name: philomatheia'
