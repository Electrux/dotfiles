# If not running interactively, don't do anything
[[ $- == *i* ]] || return

eval $(keychain --eval $(/bin/ls ~/.ssh/ | grep 'id_' | grep -v '.pub'))

if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ${BASH_EXECUTION_STRING} && ${SHLVL} == 1 ]]; then
    if shopt -q login_shell; then LOGIN_OPTIONS='--login'; else LOGIN_OPTIONS=''; fi
    exec fish $LOGIN_OPTIONS
fi