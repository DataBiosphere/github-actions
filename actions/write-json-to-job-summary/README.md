# write-json-to-job-summary

A composite action that renders a JSON object as a markdown table in the GitHub Actions job summary. It is most useful for recording the inputs a workflow was run with, e.g. from `workflow_dispatch`.

Because it is a composite action, it runs directly on the runner. There is no Docker image to build. It requires `jq`, which is preinstalled on GitHub-hosted runners.

## Usage

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
      version:
        description: 'Version to deploy'
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Display inputs
        uses: databiosphere/github-actions/actions/write-json-to-job-summary@write-json-to-job-summary-<version>
        with:
          inputs-json: ${{ toJSON(inputs) }}
          title: Workflow Inputs
```

This produces a job summary like:

```
### Workflow Inputs

| Parameter | Value |
| :--- | :--- |
| **environment** | dev |
| **version** | Not provided |
```

## Inputs

| Name | Description                                                                             | Required | Default             |
| :--- |:----------------------------------------------------------------------------------------|:---------|:--------------------|
| `inputs-json` | JSON object of parameter names and values, typically passed via `${{ toJSON(inputs) }}` | true     | None                |             |
| `title` | Heading for the summary table                                                           | false    | GHA Workflow Inputs |

## Behaviour

- Each key/value pair in the JSON object becomes one table row.
- Null values are shown as `Not provided`.
- Non-string values (booleans, numbers, nested objects) are rendered as their JSON text, so `false` is shown as `false`.
- `|` characters are escaped and newlines are converted to `<br>` so values cannot break the table.
- If `inputs-json` is empty, `null` or `{}`, the summary shows `*No inputs provided.*` instead of a table.

## Outputs

None. The action only writes to `$GITHUB_STEP_SUMMARY`.
