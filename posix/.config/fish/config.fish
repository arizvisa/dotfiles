# ~/.config/fish/config.fish

# fuck `fish(1)` completely, and execute `bash(1)` instead.
if command -v bash >/dev/null
    if status is-login
        exec bash -l
    else
        exec bash
    end
end

# otherwise, fall back to executing `sh(1)` instead.
if command -v sh >/dev/null
    if status is-login
        exec sh -l
    else
        exec sh
    end
end
