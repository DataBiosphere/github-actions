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
    touch output.yaml
    pr_api_urls=()

    # Use Vault token to grab Google service account credentials and auth to GCP/GKE
    gcloud_auth
    gke_auth

    local svc_names=$(yq r services.yaml --printMode p '*')
    edebug "$svc_names"
    readarray -t svc_arr <<< "$svc_names"

    git clone -b "$terra_helmfile_branch" --single-branch https://${github_token}@github.com/broadinstitute/terra-helmfile

    if [[ "$preview_cmd" == 'create' ]]; then
        terraform_apply "$env_id"

        for service in "${svc_arr[@]}"; do
            local helm_chart=$(yq r services.yaml "$service.helm_chart")
            local service_repo=$(yq r services.yaml "$service.repo")
            local service_ip=$(cat terraform/output.json | jq -r ".ingress_ips.value.$service")
            local service_fqdn=$(cat terraform/output.json | jq -r ".fqdns.value.$service")
            edumpvar helm_chart service_repo service_ip service_fqdn

            # Update terra-helmfile values for this preview environment
            update_values "$env_id" "$helm_chart" "$service_ip"

            # Collect version/PR information for output
            update_version_output "$service" "$service_repo" "$helm_chart"

            # Collect ingress information for output
            update_ingress_output "$service" "$service_ip" "$service_fqdn"
        done

        edebug "output.yaml: $(cat output.yaml)"
        edebug "PR API URLs:"
        edebug "$(printf '%s\n' "${pr_api_urls[@]}")"

        kubectl create namespace "terra-$env_id" || true
        enotify "Working in the terra-$env_id namespace"

        pushd terra-helmfile > /dev/null
        update_versions
        manifest=$(helmfile -e "$env_id" --selector group=terra template)
        popd > /dev/null

        edebug "$manifest"
        echo "$manifest" | kubectl -n "terra-$env_id" apply -f -
        eok 'Applied k8s manifest'

        post_comments "$env_id"
        eok "Environment $env_id ready"
    elif [[ "$preview_cmd" == 'delete' ]]; then
        kubectl delete namespace "terra-$env_id" || true
        terraform_destroy "$env_id"
        versions=$(cat terraform/output.json | jq -r ".versions.value" | base64 -d)
        edumpvar versions

        for service in "${svc_arr[@]}"; do
            local helm_chart=$(yq r services.yaml "$service.helm_chart")
            local service_repo=$(yq r services.yaml "$service.repo")
            edumpvar helm_chart service_repo

            # Collect version/PR information for output
            update_version_output "$service" "$service_repo" "$helm_chart"
        done

        post_comments "$env_id"
        eok "Environment $env_id removed"
    elif [[ "$preview_cmd" == 'report' ]]; then
        terraform_get_output "$env_id"
        versions=$(cat terraform/output.json | jq -r ".versions.value" | base64 -d)
        edumpvar versions

        for service in "${svc_arr[@]}"; do
            local helm_chart=$(yq r services.yaml "$service.helm_chart")
            local service_repo=$(yq r services.yaml "$service.repo")
            edumpvar helm_chart service_repo

            # Collect version/PR information for output
            update_version_output "$service" "$service_repo" "$helm_chart"
        done

        post_comments "$env_id"
        eok "Test results for environment $env_id reported"
    fi

    echo ::set-output name=output::$(yq r -j output.yaml | base64 | tr -d \\n)
}

terraform_apply() {
    local env_id="$1"

    pushd terraform > /dev/null

    terraform init
    echo "owner = \"$env_id\"" >> preview.tfvars
    if terraform workspace list | grep "$env_id"; then
        terraform workspace select "$env_id"
    else
        terraform workspace new "$env_id"
    fi

    terraform apply -auto-approve -var-file=preview.tfvars -var "versions=$versions_b64"
    terraform output -json > output.json

    eok "Applied Terraform configuration in workspace $env_id"

    popd > /dev/null
}

terraform_destroy() {
    local env_id="$1"

    pushd terraform > /dev/null

    terraform init
    echo "owner = \"$env_id\"" >> preview.tfvars
    if terraform workspace list | grep "$env_id"; then
        terraform workspace select "$env_id"
        terraform output -json > output.json
        terraform destroy -auto-approve -var-file=preview.tfvars
        terraform workspace select default
        terraform workspace delete "$env_id"
        eok "Terraform workspace $env_id cleaned up"
    else
        ewarn "Terraform workspace $env_id doesn't exist"
    fi

    popd > /dev/null
}

terraform_get_output() {
    local env_id="$1"

    pushd terraform > /dev/null

    terraform init
    echo "owner = \"$env_id\"" >> preview.tfvars
    if terraform workspace list | grep "$env_id"; then
        terraform workspace select "$env_id"
        terraform output -json > output.json
        eok "Got outputs from workspace $env_id"
    else
        ecrit "Terraform workspace $env_id doesn't exist"
        exit 1
    fi

    popd > /dev/null
}

gcloud_auth() {
    curl -H "X-Vault-Token: $vault_token" -X GET "$vault_address/v1/$vault_sa_path" | jq '.data' > sa.json
    gcloud auth activate-service-account --key-file=sa.json
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa.json"
    eok 'Authenticated with Google service account'
}

gke_auth() {
    gcloud container clusters get-credentials "$gke_cluster" --zone "$gke_zone" --project "$gke_project"
    eok "Authenticated to the $gke_cluster cluster"
}

update_values() {
    pushd terra-helmfile > /dev/null

    local env_id="$1"
    local service="$2"
    local service_ip="$3"
    local values_file="terra/values/$service/preview.yaml"

    write_value "$values_file" global.terraEnv "$env_id"
    write_value "$values_file" serviceIP "$service_ip"
    awk "1;/environments:/{ print \"  $env_id: {values: [environments/preview.yaml]}\"}" helmfile.yaml | sponge helmfile.yaml

    eok 'Updated Helmfile values'

    popd > /dev/null
}

update_version_output() {
    local service="$1"
    local service_repo="$2"
    local helm_chart="$3"

    local override=true
    if [[ $(echo $versions | jq ".releases.$helm_chart") == 'null' ]]; then
        override=false
    fi
    edumpvar override

    if [[ override && $(echo $versions | jq ".releases.$helm_chart.appVersion") != 'null' ]]; then
        local service_version=$(echo $versions | jq -r ".releases.$helm_chart.appVersion")
        local service_pr_num=$(service_version_to_pr_num "$service_version")
        write_value output.yaml "services.$service.appVersion" "$service_version"
        write_value output.yaml "pullRequests[+]" "https://github.com/$service_repo/pull/$service_pr_num"
        pr_api_urls+=("https://api.github.com/repos/$service_repo/issues/$service_pr_num")
    else
        local service_version=$(yq r terra-helmfile/versions.yaml "releases.$helm_chart.appVersion")
        write_value output.yaml "services.$service.appVersion" "$service_version"
    fi

    if [[ override && $(echo $versions | jq ".releases.$helm_chart.chartVersion") != 'null' ]]; then
        local chart_version=$(echo $versions | jq -r ".releases.$helm_chart.chartVersion")
        local chart_pr_num=$(chart_version_to_pr_num "$chart_version")
        write_value output.yaml "services.$service.chartVersion" "$chart_version"
        write_value output.yaml "pullRequests[+]" "https://github.com/broadinstitute/terra-helm/pull/$chart_pr_num"
        pr_api_urls+=("https://api.github.com/repos/broadinstitute/terra-helm/issues/$chart_pr_num")
    else
        local chart_version=$(yq r terra-helmfile/versions.yaml "releases.$helm_chart.chartVersion")
        write_value output.yaml "services.$service.chartVersion" "$chart_version"
    fi
}

update_ingress_output() {
    local service="$1"
    local service_ip="$2"
    local service_fqdn="$3"

    write_value output.yaml "services.$service.ip" "$service_ip"
    write_value output.yaml "services.$service.url" "https://${service_fqdn::-1}"
}

update_versions() {
    echo "$versions" > input_versions.yaml
    edebug "input versions.yaml: $(cat input_versions.yaml)"
    edebug "original versions.yaml: $(cat versions.yaml)"
    yq m -ix versions.yaml input_versions.yaml
    edebug "merged versions.yaml: $(cat versions.yaml)"
}

service_version_to_pr_num() {
    local version="$1"
    local regex='pr([0-9]+)'
    if [[ $version =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
    else
        ecrit "Can't find PR # in $version!"
        exit 1
    fi
}

chart_version_to_pr_num() {
    local version="$1"
    local regex='^[0-9]+\.[0-9]+\.[0-9]+-([0-9]+)'
    if [[ $version =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
    else
        ecrit "Can't find PR # in $version!"
        exit 1
    fi
}

write_value() {
    local file="$1"
    local path="$2"
    local value="$3"
    yq w -i "$file" "$path" "$value" 
    edebug "Wrote $value to $path in $file"
}

post_comments() {
    local env_id="$1"

    enotify "Updating PRs"
    for pr in "${pr_api_urls[@]}"; do
        if [[ "$preview_cmd" == 'create' ]]; then 
            yq r -j output.yaml | jq '.' > output.json

            local comment="#### Terra preview environment \`$env_id\` created or updated\n"
            comment+="Environment info:\n"
            comment+="\`\`\`\n$(cat output.json | jq -RMs '.' | sed -e 's/^"//' -e 's/"$//')\`\`\`"
        elif [[ "$preview_cmd" == 'delete' ]]; then
            local comment="#### Terra preview environment \`$env_id\` deleted"
        elif [[ "$preview_cmd" == 'report' ]]; then
            if $test_status; then
                local test_string='PASSED'
            else
                local test_string='FAILED'
            fi
            local comment="#### Tests $test_string on Terra preview environment \`$env_id\`\n"
            comment+="##### Test info:\n"
            comment+="$(echo $test_data | jq -r '. | to_entries[] | .key + ": " + .value' | awk '{printf "%s\\n", $0}')"
        fi

        edumpvar pr comment
        post_comment "$pr" "$comment"
    done
}

post_comment() {
    local pr_url="$1"
    local comment="$2"
    local comment_json='{"body":"'
    comment_json+=$comment
    comment_json+='"}'
    edumpvar comment_json
    local status=$(curl -s \
      -o comment_out \
      -w "%{http_code}" \
      -X POST \
      -H "Accept: application/vnd.github.v3+json" \
      "$pr_url/comments" \
      -u "broadbot:$github_token" \
      -d "$comment_json")
    if [[ "$status" != '201' ]]; then
        edumpvar status
        eerror "Non-201 return code: $(cat comment_out)"
    else
        eok "$pr_url updated"
    fi
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

pushd /preview > /dev/null

set_vars "inputs.yaml"
versions=$(echo $versions_b64 | base64 -d)
test_data=$(echo $test_data_b64 | base64 -d)
edumpvar env_id preview_cmd gke_cluster gke_project gke_zone verbosity terra_helmfile_branch versions
main

popd > /dev/null