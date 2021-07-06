package main

test_deny_replicas {
  not deny_replicas with input as {
     "kind": "Deployment", "spec": {
        "replicas": "1",
        "revisionHistoryLimit": 0
  }
}
}
