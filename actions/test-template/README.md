# Terra Preview Environment Test Action Template
This action is meant to serve as a template for testing actions that conform to the Terra preview environment interface. Such actions can then be plugged in to automated preview environment creation/testing/teardown workflows.

The "testing" involved in this action merely hits a status endpoint and makes sure that a 200 is returned. The intention is for the testing logic to be replaced by an invocation of the appropriate test script/framework.

## Inputs
|Environment Variable|Required|Description|Default|
|---|---|---|---|
|ENV_DATA_B64|yes|Base64-encoded JSON as output by the [environment creation action](https://github.com/DataBiosphere/github-actions/tree/master/actions/preview#common-output-for-all-commands)|N/A|
|ACTION_RUN_URL|yes|URL of this action run, as constructed from the GITHUB_RUN_ID action env variable|N/A|
|VERBOSITY|no|Verbosity level, with 1 being silent and 6 being debug|4|

## Output
Outputs are set using the GH actions `echo ::set-output name=[output name]::[output string]` syntax

|Name|Description|
|---|---|
|status|Boolean (true/false) status of the tests|
|testData|Base64-encoded JSON map of URLs to any test logs or dashboards. Will be output to PR comments|

