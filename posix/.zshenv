# ~/.zshenv

# ...basically we fuck `zsh(1)` completely, and run `bash(1)` instead.
if command -v bash >/dev/null 2>&1; then
    echo "$0: executing bash instead..." 1>&2
    case "$0" in
        -zsh|-*/zsh) exec bash -l ;;
        *) exec bash ;;
    esac

# ...fall back to good ol' bourne `sh(1)` if there's no `bash(1)`.
elif command -v sh >/dev/null 2>&1; then
    echo "$0: executing sh instead..." 1>&2
    case "$0" in
        -zsh|-*/zsh) exec sh -l ;;
        *) exec sh ;;
    esac

# otherwise we're completely stuck with a retarded shell...
else
    echo "$0: unable to find alternative shell...godspeed." 1>&2

fi
