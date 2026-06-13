# ~/.config/fish/config.fish
set ARG0 (status current-command)

# fuck `fish(1)` completely, and execute `bash(1)` instead.
if command -v bash >/dev/null
    echo "$ARG0: executing bash instead..." 1>&2
    if status is-login
        exec bash -l
    else
        exec bash
    end

# otherwise, fall back to executing `sh(1)` instead.
else if command -v sh >/dev/null
    echo "$ARG0: executing sh instead..." 1>&2
    if status is-login
        exec sh -l
    else
        exec sh
    end

# we're stuck with this stupid shell...
else
    echo "$0: unable to find alternative shell...godspeed." 1>&2

end
