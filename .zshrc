eval $(keychain --eval $(/bin/ls ~/.ssh/ | grep 'id_' | grep -v '.pub'))

if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ${ZSH_EXECUTION_STRING} && ${SHLVL} == 1 ]]; then
    if [[ -o login ]]; then LOGIN_OPTIONS='--login'; else LOGIN_OPTIONS=''; fi
    exec fish $LOGIN_OPTIONS
fi