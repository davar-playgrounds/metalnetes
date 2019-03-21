# activate logging to a file by:
# export LOG_FILE=<PATH_TO_CUSTOM_LOG_FILE>

# disable logging to stdout with:
# export HIDE_LOGS="1"
export SHOW_LOGS="1"
if [[ "${HIDE_LOGS}" == "1" ]]; then
    export SHOW_LOGS="0"
fi
# include datetime stamp per log by setting as "1" otherwise no dates
export USE_SHOW_DATES=0
if [[ "${SHOW_DATES}" == "1" ]]; then
    export USE_SHOW_DATES=1
fi

# include colors with 1 otherwise no colors
export COLORS_SUPPORTED=1

# how to use this:
# source ./tools/bash_colors.sh
# 
# now print out the colors:
# ign testing ignore_message; inf testing info_message; good testing good_message; anmt testing annoucement_message; warn testing warn_message; err testing err_message; critical testing critical_message
#
# want to change colors up? use:
# show_colors
#
# additional color guide(s):
# https://misc.flogisoft.com/bash/tip_colors_and_formatting

# check if stdout is a terminal...
if test -t 1; then
    if [[ -e /usr/bin/tput ]]; then
        # see if it supports colors...
        ncolors=$(tput colors)
        if test -n "$ncolors" && test $ncolors -ge 8; then
            export COLORS_SUPPORTED=1
        fi
    fi
fi

get_date() {
    cdate=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${cdate}"
}

anmt() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;227m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;227m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;227m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;227m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}

warn() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;208m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;208m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;208m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;208m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
dbg() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}

ign() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;240m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
good() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;46m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;46m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;046m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;046m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
green() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;048m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;048m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;048m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;048m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
inf() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            echo "$(get_date) ${@}"
        else
            echo "${@}"
        fi
    else
        echo "$(get_date) $@"
    fi
}

err() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;196m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;196m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[38;5;196m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[38;5;196m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
critical() {
    if [[ "${COLORS_SUPPORTED}" == "1" ]]; then
        if [[ "${USE_SHOW_DATES}" == "1" ]]; then
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[48;5;196m%s\e[0m " "$(get_date) ${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[48;5;196m%s\e[0m " "$(get_date) ${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        else
            if [[ "${SHOW_LOGS}" == "1" ]]; then
                printf "\x1b[48;5;196m%s\e[0m " "${@}"
                printf "\n"
            fi
            if [[ "${LOG_FILE}" != "" ]] && [[ -e "${LOG_FILE}" ]]; then
                printf "\x1b[48;5;196m%s\e[0m " "${@}" >> ${LOG_FILE}
                printf "\n" >> ${LOG_FILE}
            fi
        fi
    else
        echo "$(get_date) $@"
    fi
}
 
crit() {
    critical $@
}
 
# log any non-empty message as an error
boom() {
    echo ""
    if [[ "${2}" != "" ]]; then
        err "StatusCode: ${1}" 
        err "Error: ${2}" 
        exit $1
    else
        err "Error: ${@}" 
        exit 1
    fi
}

# stop on last error and exit
xerr() {
    last_status=$?
    if [[ "${last_status}" != "" ]]; then
        if [[ "${last_status}" != "0" ]]; then
            echo ""
            err "Exiting(${last_status}) Error: ${@}"
            exit $last_status
        fi
    fi
}

# 256 bash color test
# https://gist.github.com/nikhan/2537eaa5144e44c87e7218b0ecf68521
show_debug_colors() {
	for i in {0..255} ; do
		printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"
		if (( i == 15 )) || (( i > 15 )) && (( (i-15) % 6 == 0 )); then
			printf "\n";
		fi
	done
}

show_colors() {
    # enable date prefix timestamp with:
    # export SHOW_DATES=1
    dbg "the debug message"
    dbg "  - run with command: dbg \"the debug message\""
    inf "the info message"
    inf "  - run with command: inf \"the info message\""
    good "the success message"
    good "  - run with command: good \"the success message\""
    err "the error message"
    err "  - run with command: err \"the error message\""
    anmt "the announcement message"
    anmt "  - run with command: anmt \"the announcement message\""
    warn "the warning message"
    warn "  - run with command: warn \"the warning message\""
    critical "the critical message"
    critical "  - run with command: critical \"the critical message\""
}
