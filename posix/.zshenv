# ~/.zshenv
# ...basically we fuck `zsh(1)` completely, and run `bash(1)` instead.
if command -v bash >/dev/null 2>&1; then
    case "$0" in
        -zsh|-*/zsh) exec bash -l ;;
        *) exec bash ;;
    esac
fi
# ...fall back to good ol' bourne `sh(1)` if there's no `bash(1)`.
if command -v sh >/dev/null 2>&1; then
    case "$0" in
        -zsh|-*/zsh) exec sh -l ;;
        *) exec sh ;;
    esac
fi
