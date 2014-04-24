#!/bin/bash

### Exit handler stack helpers
### Used to maintain a stack of "finally" clause actions, which will be
###   executed in LIFO order upon exit of the script.
declare -a on_exit_items
function unwind_exit_stack()
{
    local n=${#on_exit_items[*]}
    n=$((n - 1))
    for i in $(eval echo {$n..0}); do
        local cmd="${on_exit_items[$i]}"
        eval "$cmd"
        pop_on_exit
    done
}
function push_on_exit()
{
    #printf 'Pushing: %s\n' "$*"
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        trap unwind_exit_stack EXIT
    fi
}
function pop_on_exit()
{
    local n=${#on_exit_items[*]}
    n=$((n - 1))
    #printf 'Popping: %s\n' "${on_exit_items[$n]}"
    unset on_exit_items[$n]
}
function inspect_exit_stack()
{
    local n=${#on_exit_items[*]}
    n=$((n - 1))
    if [ $n -lt 0 ]; then return 0; fi

    for i in $(eval echo {0..$n}); do
        printf 'on_exit_items[%d]: %s\n' "$i" "${on_exit_items[$i]}"
    done
}

### Timeout helper
### Used to attempt execution of a command, killing it after some timeout.
###   Exits early if the command being watched exits early.
###   Returns status code of command being watched, including the
###   signal-related code if the command is killed.
### Unlike the 'timeout' program provided by coreutils, this function can be
###   used to run an internal bash function.
function sh_timeout()
{
    local timeout="$1"
    local grace="$2"
    shift 2

    eval "$@" &
    local childpid=$!
    local childliving=true

    while ((timeout > 0)); do
        sleep 1
        # 'kill -0' returns 0 if the PID is alive, but doesn't actually touch
        # the process; we use this to check if the process is alive
        kill -0 "$childpid" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            childliving=false
            break
        fi
        ((timeout -= 1))
    done

    if [ $childliving == true ]; then
        printf 'Timeout executing command, terminating: %s\n' "$*"
        # Be nice, post SIGTERM first.
        kill -s SIGTERM "$childpid"
        sleep 1
        kill -0 "$childpid" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep $grace
            kill -s SIGKILL "$childpid" >/dev/null 2>&1
        fi
    fi

    wait "$childpid"
    return $?
}

### Error-check helper
### Used to run a command and, if the command exits non-zero, complain and
###   terminate the sript as a whole.
###   Mostly useful where you might use 'set -e', but prefer not to.
###   Can be combined with "sh_timeout" from above.
function attempt()
{
    eval "$*"

    status=$?
    if [ $status -ne 0 ]; then
        printf 'Error executing: "%s"\n' "$*"
        printf 'Exit status was: %d\n' "$status"
        exit $status
    fi
}

### Log-tail + grep helper
### Used when you want to tail a log file, waiting for a particular pattern to
###   appear, in a non-interactive shell.
### Can be combined with "sh_timeout" from above.
function wait_for_pattern_in_file()
{
    local pattern="$1"
    local file="$2"
    local success=false

    # Launch 'tail -f' in a coprocess so we can kill it later
    coproc tail -f "$file" 2>/dev/null
    
    # Read from coprocess; if we hit EOF (tail was killed), 'success' will
    #   still be 'false', so we'll return failure
    while read -ru ${COPROC[0]} line; do
        printf '%s' "$line" | grep "$pattern" >/dev/null
        if [ $? -eq 0 ]; then
            success=true
            break
        fi
    done

    if [ "$success" == true ]; then
        # Suppress "Terminated" messages for child processes
        # We didn't do this above because at the time the death of the coproc
        #   would have been unexpected.
        # Also, note that after calling 'disown', the 'wait' command will 
        #   always return 0, regardless of the exit status of the process.
        disown 
        # Kill the coprocess
        kill "$COPROC_PID"
        wait "$COPROC_PID"
        return 0
    else
        # We only end up here if the coproc was killed, so there's no need for
        #   for us to kill it again.
        return 1
    fi
}

