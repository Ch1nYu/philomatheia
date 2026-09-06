#!/bin/sh
set -eu

skill_name="philomatheia"
source_path=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
update=0
dry_run=0
all=0
list_only=0
dest_roots=""
selected_slugs=""
interactive_selection=0
newline='
'

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
# Three directories cover the ecosystem. `.agents/skills` is the cross-agent
# convention most tools read; Claude Code and the XDG-style agents share the
# other two. Each agent below is mapped to the directory its own documentation
# names, so selecting several agents usually resolves to a single install.
cross_agent_dir="$HOME/.agents/skills"
claude_dir="$HOME/.claude/skills"
config_agent_dir="$config_home/agents/skills"

# slug|display name|directory whose presence means the agent is installed|skills directory
known_agents="claude-code|Claude Code|$HOME/.claude|$claude_dir
codex|Codex CLI|$HOME/.codex|$cross_agent_dir
cursor|Cursor|$HOME/.cursor|$cross_agent_dir
gemini|Gemini CLI|$HOME/.gemini|$cross_agent_dir
copilot|GitHub Copilot / VS Code|$HOME/.copilot|$cross_agent_dir
opencode|OpenCode|$config_home/opencode|$cross_agent_dir
amp|Amp|$config_home/amp|$config_agent_dir
goose|Goose|$config_home/goose|$config_agent_dir
roo|Roo Code|$HOME/.roo|$cross_agent_dir
factory|Factory droid|$HOME/.factory|$cross_agent_dir
pi|pi|$HOME/.pi|$cross_agent_dir
openclaw|OpenClaw|$HOME/.openclaw|$cross_agent_dir"

usage() {
    printf '%s\n' "Usage: ./install.sh [--agent NAME]... [--dest-root PATH]... [--all] [--list] [--update] [--dry-run]"
    printf '%s\n' ""
    printf '%s\n' "Installs the runtime skill files for the agents you choose. No agent is"
    printf '%s\n' "chosen by default: with no --agent, --dest-root, or --all, the installer"
    printf '%s\n' "lists the agents it knows about with their status and asks which to use."
    printf '%s\n' ""
    printf '%s\n' "  --agent NAME      install for this agent; repeat for several"
    printf '%s\n' "  --dest-root PATH  install into PATH; repeat for several directories"
    printf '%s\n' "  --all             install for every agent found on this machine"
    printf '%s\n' "  --list            print the agent status table and exit"
    printf '%s\n' "  --update          replace an existing installation"
    printf '%s\n' "  --dry-run         print what would be installed and exit"
    printf '%s\n' ""
    printf '%s\n' "Agent names:"
    old_ifs=$IFS
    IFS=$newline
    for line in $known_agents; do
        slug=${line%%|*}
        rest=${line#*|}
        name=${rest%%|*}
        printf '  %s %s\n' "$(pad_right "$slug" 12)" "$name"
    done
    IFS=$old_ifs
    printf '%s\n' ""
    printf '%s\n' "Several agents usually share one directory, which is written once."
    printf '%s\n' "PHILOMATHEIA_DEST_ROOT sets one destination and skips the prompt."
}

pad_right() {
    # pad_right STRING WIDTH
    padded=$1
    while [ ${#padded} -lt "$2" ]; do
        padded="$padded "
    done
    printf '%s' "$padded"
}

field() {
    # field LINE INDEX  (1-based, "|" separated)
    value=$1
    index=$2
    while [ "$index" -gt 1 ]; do
        value=${value#*|}
        index=$((index - 1))
    done
    printf '%s' "${value%%|*}"
}

agent_line() {
    # agent_line SLUG -> the registry line, empty when unknown
    old_ifs=$IFS
    IFS=$newline
    for line in $known_agents; do
        if [ "${line%%|*}" = "$1" ]; then
            printf '%s' "$line"
            break
        fi
    done
    IFS=$old_ifs
}

agent_status() {
    # agent_status MARKER SKILLS_DIR
    if [ -e "$2/$skill_name" ]; then
        printf 'installed'
    elif [ -d "$1" ]; then
        printf 'found, not installed'
    else
        printf 'not found'
    fi
}

print_agent_table() {
    # print_agent_table [numbered]
    numbered=${1:-0}
    name_width=0
    old_ifs=$IFS
    IFS=$newline
    for line in $known_agents; do
        name=$(field "$line" 2)
        [ ${#name} -le "$name_width" ] || name_width=${#name}
    done
    index=0
    for line in $known_agents; do
        index=$((index + 1))
        name=$(field "$line" 2)
        marker=$(field "$line" 3)
        target=$(field "$line" 4)
        if [ "$numbered" -eq 1 ]; then
            printf '%3d) ' "$index"
        else
            printf '  '
        fi
        printf '%s  %s\n' "$(pad_right "$name" "$name_width")" "$(agent_status "$marker" "$target")"
    done
    IFS=$old_ifs
}

agent_count() {
    old_ifs=$IFS
    IFS=$newline
    count=0
    for line in $known_agents; do
        if [ -n "$line" ]; then
            count=$((count + 1))
        fi
    done
    IFS=$old_ifs
    printf '%s' "$count"
}

agent_at() {
    # agent_at INDEX -> the registry line
    old_ifs=$IFS
    IFS=$newline
    index=0
    for line in $known_agents; do
        index=$((index + 1))
        if [ "$index" -eq "$1" ]; then
            printf '%s' "$line"
            break
        fi
    done
    IFS=$old_ifs
}

add_root() {
    case "$newline$dest_roots" in
        *"$newline$1$newline"*) return 0 ;;
    esac
    dest_roots="$dest_roots$1$newline"
}

select_agent() {
    # select_agent SLUG
    case "$newline$selected_slugs" in
        *"$newline$1$newline"*) ;;
        *) selected_slugs="$selected_slugs$1$newline" ;;
    esac
    line=$(agent_line "$1")
    add_root "$(field "$line" 4)"
}

agents_for_dest() {
    # agents_for_dest DIRECTORY -> "Name, Name" for the selected agents it serves
    names=""
    old_ifs=$IFS
    IFS=$newline
    for slug in $selected_slugs; do
        [ -n "$slug" ] || continue
        line=$(agent_line "$slug")
        [ "$(field "$line" 4)" = "$1" ] || continue
        if [ -z "$names" ]; then
            names=$(field "$line" 2)
        else
            names="$names, $(field "$line" 2)"
        fi
    done
    IFS=$old_ifs
    printf '%s' "$names"
}

report_destination() {
    # report_destination VERB DIRECTORY
    printf '%s %s at %s\n' "$1" "$skill_name" "$2/$skill_name"
    served=$(agents_for_dest "$2")
    if [ -n "$served" ]; then
        printf '  serves %s\n' "$served"
    fi
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
    count=$(agent_count)
    project_index=$((count + 1))
    custom_index=$((count + 2))

    {
        printf 'Select where to install %s. Nothing is selected by default.\n\n' "$skill_name"
        printf '     AGENT%sSTATUS\n' '                      '
        print_agent_table 1
        printf '\n%3d) %s\n' "$project_index" "This project only (./.agents/skills)"
        printf '%3d) %s\n\n' "$custom_index" "Another directory (enter the path yourself)"
    } >&2

    while :; do
        ask 'Numbers separated by commas (for example 1,2), or Enter to cancel: ' || return 0
        [ -n "$reply" ] || return 0

        selection=$(printf '%s' "$reply" | tr ',' ' ')
        valid=1
        pending=""
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
                pending="$pending=$reply$newline"
            elif [ "$token" -eq "$project_index" ]; then
                pending="$pending=$PWD/.agents/skills$newline"
            else
                pending="$pending$(field "$(agent_at "$token")" 1)$newline"
            fi
        done
        set +f
        [ "$valid" -eq 1 ] || continue
        if [ -z "$pending" ]; then
            printf 'Nothing selected.\n' >&2
            continue
        fi

        old_ifs=$IFS
        IFS=$newline
        for entry in $pending; do
            [ -n "$entry" ] || continue
            case "$entry" in
                "="*) add_root "${entry#=}" ;;
                *) select_agent "$entry" ;;
            esac
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
        --agent)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            if [ -z "$(agent_line "$2")" ]; then
                printf 'Unknown agent: %s\n' "$2" >&2
                usage >&2
                exit 2
            fi
            select_agent "$2"
            shift 2
            ;;
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
    print_agent_table 0
    exit 0
fi

if [ "$all" -eq 1 ]; then
    old_ifs=$IFS
    IFS=$newline
    for line in $known_agents; do
        # Presence of the agent, not of an earlier install: a directory that
        # several agents read must not imply that all of them are here.
        if [ -d "$(field "$line" 3)" ]; then
            select_agent "$(field "$line" 1)"
        fi
    done
    IFS=$old_ifs
    [ -n "$dest_roots" ] || {
        printf 'No known agent was found on this machine, so --all selected nothing.\n' >&2
        printf 'Pass --agent NAME or --dest-root PATH instead.\n' >&2
        exit 1
    }
fi

if [ -z "$dest_roots" ]; then
    if [ -n "${PHILOMATHEIA_DEST_ROOT:-}" ]; then
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
        printf 'Agents on this machine:\n' >&2
        print_agent_table 0 >&2
        printf 'Choose with --agent NAME, --dest-root PATH, or --all, or run the\n' >&2
        printf 'installer interactively.\n' >&2
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
            report_destination "Update" "$destination_root"
        else
            report_destination "Install" "$destination_root"
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
    report_destination "$past_action" "$destination_root"
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

printf '%s\n' 'Most agents detect a new skill automatically. Restart the agent if it does not appear.'
printf '%s\n' 'Then ask it to teach or map a subject, or invoke the skill by name: philomatheia'
