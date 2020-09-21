# Terra Preview Environment Action
This action contains the logic for managing the life-cycle of Terra preview environments. These environments are meant to be ephemeral, with a fully automated spin-up and spin-down process. The main use cases for them are integration tests as well as manual testing and iteration in PRs.

## Common inputs for all commands
|Environment Variable|Required|Description|Default|
|---|---|---|---|
|PREVIEW_CMD|yes|The command to run. Will be moved to arg instead of env var soon.|N/A|
|GITHUB_TOKEN|yes|GitHub PAT for cloning terra-helmfile repo and posting comments on PRs|N/A|
|VAULT_TOKEN|yes|Vault token for retrieving Google credentials|N/A|
|VAULT_SA_PATH|yes|Path to Google credentials in Vault|N/A|
|ENV_ID|yes|Unique identifier for this environment. Recommended syntax is [short prefix identifying service][pr number]|N/A|
|VAULT_ADDRESS|no|Path to Google credentials in Vault|https://clotho.broadinstitute.org:8200|
|GKE_CLUSTER|no|GKE cluster where the environment will be deployed|terra-integration|
|GKE_PROJECT|no|GCP project where the cluster lives|terra-kernel-k8s|
|GKE_ZONE|no|GCP zone where the cluster lives|us-central1-a|
|VERBOSITY|no|Verbosity level, with 1 being silent and 6 being debug|4|
|TERRA_HELMFILE_BRANCH|no|Branch of the terra-helmfile repo to use|master|

## Common output for all commands
All of these commands output a Base64-encoded JSON with information about the environment and all services deployed using the GH actions `echo ::set-output name=output::[output string]` syntax

Example output (decoded from its original base64 output form):
```
{
  "pullRequests": [
    "https://github.com/databiosphere/terra-workspace-manager/pull/83",
    "https://github.com/broadinstitute/terra-helm/pull/103"
  ],
  "services": {
    "workspacemanager": {
      "appVersion": "pr83-6f12bdf",
      "chartVersion": "0.3.3-103.1597082559.f8625c",
      "ip": "35.224.79.176",
      "url": "https://workspace.wsm83.preview.envs.broadinstitute.org"
    }
  }
}
```

## Commands

The intended way of triggering these actions is via a PR comment. However, they are packaged into a Docker image, so can be directly invoked with the proper inputs.

### create (preview-create in a PR)

Creates a preview environment with the optionally specified version overrides. Posts comments to any PRs involved.

#### inputs (in addition to the common ones above)

|Environment Variable|Required|Description|
|---|---|---|
|VERSIONS_B64|no|Version overrides in [terra-helmfile versions.yaml](https://github.com/broadinstitute/terra-helmfile/blob/master/versions.yaml) file format (base64-encoded JSON)|

### report (invoked from preview-test workflow in PR)

Gathers information about the status and output of tests in a preview environment and passes them on to the PRs corresponding to any overwritten versions.

#### inputs (in addition to the common ones above)

|Environment Variable|Required|Description|
|---|---|---|
|TEST_STATUS|yes|Boolean test status (true/false) as output by the test action per the [preview environment interface](https://docs.google.com/document/d/1TGYubm3OGeQaSmZCecd8nCP1CZ1oQVzrUFISjtGG7rw/edit?usp=sharing)|
|TEST_DATA_B64|yes|Test data as output by the test action (base64-encoded JSON) per the [preview environment interface](https://docs.google.com/document/d/1TGYubm3OGeQaSmZCecd8nCP1CZ1oQVzrUFISjtGG7rw/edit?usp=sharing)|


### delete (invoked from preview-delete workflow in PR)

Tears down the preview environment specified in `ENV_ID`. Updates PRs corresponding to any overwritten versions.

#### No inputs in addition to the common ones above