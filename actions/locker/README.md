# locker

A GitHub Action that enables serialization/locking of one or more workflows.
This action uses the [gcslock Go library](https://github.com/marcacohen/gcslock/blob/master/LICENSE) to obtain and release locks using a Google Cloud Storage bucket.

### Usage

```
steps:
- name: Set up GCS Google Service Account with access to bucket
  run: echo '${{ secrets.GCS_SA }}' > service_account.json

- name: Lock
  uses: databiosphere/github-actions/actions/locker@locker-0.7.0
  with:
    operation: lock
    lock_name: lock-name
    bucket: bucket-name
    lock_timeout_ms: '120000'

- name: Do stuff we want serialized
  uses: some-action

# OPTIONAL, only need to do this step again if the above stuff wipes out the workspace
- name: Set up GCS Google Service Account with access to bucket
  if: ${{ always() }}
  run: echo '${{ secrets.GCS_SA }}' > service_account.json

- name: Unlock
  uses: databiosphere/github-actions/actions/locker@locker-0.7.0
  if: ${{ always() }}
  with:
    operation: unlock
    lock_name: lock-name
    bucket: bucket-name
```

#### Inputs
| Name | Default | Description|
| ---- | ------- | ---------- |
| `bucket` | N/A | GCS Bucket to use for locking |
| `lock_name` | N/A | Unique name for the lock. All workflows using the same lock name will share that lock. |
| `operation` | 'lock' | Locking operation to perform. Only 'lock' and 'unlock' are supported. |
| `lock_timeout_ms` | '0' | Milliseconds to wait before giving up trying to get a lock. Never gives up if set to 0. |
| `continue_on_lock_timeout` | 'false' | Whether to continue (without failing) when the lock timeout is exceeded |
| `unlock_timeout_ms` | '2000' | Milliseconds to wait before giving up trying to get a lock. Never gives up if set to 0. |

#### Expected Files

This action expects a file named `service_account.json` to exist in the workspace when it runs. It should be a JSON-format Google Service Account key file for a service account that has `roles/storage.objectAdmin` on the bucket in question.
