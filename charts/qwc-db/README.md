# Versions

The [qwc-base-db repo](https://github.com/qwc-services/qwc-base-db) has no latest tag per year like `2026-lts`. This chart `appVersion` follows the latest tag available from this repo.
Also, in this chart, the PostgreSQL docker image tag is by default the latest available (`18` for now).

:warning: Using this chart and its latest `appVersion`, you can retrieve a new PostgreSQL major version! You MUST pin the PostgreSQL docker image tag to avoid failures during deployment or data losses. Upgrading major version of PostgreSQL database may require manual operations (dump previous DB and restore in new DB).

Using a pin version of the docker image and a `pullPolicy` to `Always` will retrieve the latest version of the `qwc-base-db` docker image for the PostgreSQL version you pinned.

For example, in the `values.yaml` of your umbrella chart, you must fix the DB version and could set the policy. Here we fix it to the ealier version `16`:

```yaml
# PostgreSQL Database
qwcDb:
  enabled: true
  image:
    pullPolicy: Always
    tag: "16"
```
