#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Set variables from their all-caps versions, taking defaults from config file
set_vars() {
    local config_file=$1
    local vars=$(yq r "$1" --printMode p '*')
    readarray -t varsArr <<< "$vars"
    for var in "${varsArr[@]}"; do
        varCaps="${var^^}"
        if [ -z ${!varCaps+x} ]; then
            eval "$var"=$(yq r "$config_file" "$var.default")
        else
            eval "$var"="${!varCaps}"
        fi
    done
}

main() {
    local pass=true
    for url in $(echo "${env_data}" | jq '.services | to_entries[] | [.value.url]' | jq -r '.[]'); do
        edumpvar url
        local status=$(curl -ks -o status_out -w "%{http_code}" "$url/status")
        if [[ "$status" != '200' ]]; then 
            pass=false
            eerror "Non-200 status endpoint return code: $(cat status_out)"
        else
            eok "200 Response: $(cat status_out | jq -c .)"
        fi
    done

    if $pass; then
        eok "Tests passed"
    else
        eerror "Tests failed"
    fi

    local test_data_fmt='{"logs":"%s"}'
    local test_data=$(printf "$test_data_fmt" "$action_run_url")
    edumpvar test_data
    echo status=$pass >> $GITHUB_OUTPUT
    echo testData=$(echo "$test_data" | base64 | tr -d \\n) >> $GITHUB_OUTPUT
}

colblk='\033[0;30m' # Black - Regular
colred='\033[0;31m' # Red
colgrn='\033[0;32m' # Green
colylw='\033[0;33m' # Yellow
colpur='\033[0;35m' # Purple
colrst='\033[0m'    # Text Reset

### verbosity levels
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
ntf_lvl=4
inf_lvl=5
dbg_lvl=6

## esilent prints output even in silent mode
function esilent () { verb_lvl=$silent_lvl elog "$@" ;}
function enotify () { verb_lvl=$ntf_lvl elog "$@" ;}
function eok ()    { verb_lvl=$ntf_lvl elog "SUCCESS - $@" ;}
function ewarn ()  { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@" ;}
function einfo ()  { verb_lvl=$inf_lvl elog "${colwht}INFO${colrst} ---- $@" ;}
function edebug () { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@" ;}
function eerror () { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@" ;}
function ecrit ()  { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@" ;}
function edumpvar () { for var in $@ ; do edebug "$var=${!var}" ; done }
function elog() {
        if [ $verbosity -ge $verb_lvl ]; then
                datestring=`date +"%Y-%m-%d %H:%M:%S"`
                echo -e "$datestring - $@"
        fi
}

pushd /test > /dev/null

set_vars "inputs.yaml"
env_data=$(echo $env_data_b64 | base64 -d)
edumpvar env_data verbosity
main

popd > /dev/null
