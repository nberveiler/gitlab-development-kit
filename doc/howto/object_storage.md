# Object Storage (LFS, Artifacts, etc)

GitLab has Object Storage integration.
In this document we explain how to set this up in your development
environment.

In order to take advantage of the GDK integration you must first install
[MinIO](https://docs.minio.io/docs/minio-quickstart-guide) binary (no Docker image).

You can enable the object store by adding the following to your `gdk.yml`:

```yaml
object_store:
  enabled: true
  port: 9000
```

The object store has the following default settings:

| Setting                | Default            | Description                                                                             |
|----------------------- |--------------------|-----------------------------------------------------------------------------------------|
| `object_store.enabled` | `false`            | Can be changed by adding/updating the `object_store.enabled` setting in your `gdk.yml`. |
| `object_store.port`    | `9000`             | Can be changed by adding/updating the `object_store.port` setting in your `gdk.yml`.    |
| `access key`           | `minio`            | Access key needed by MinIO to log in via its web UI. Cannot be changed.                 |
| `secret key`           | `gdk-minio`        | Secret key needed by MinIO to log in via its web UI. Cannot be changed.                 |

Changing settings requires `gdk reconfigure` to be run.

## MinIO errors

If you cannot start MinIO, you may have an old version not supporting the `--compat` parameter.

`gdk tail minio` shows a crash loop with the following error:

```plaintext
Incorrect Usage: flag provided but not defined: -compat
```

Upgrading MinIO to the latest version fixes it.

## Creating a new bucket

In order to start using MinIO from your GitLab instance you have to create buckets first.
You can create a new bucket by accessing <http://127.0.0.1:9000/> (default configuration).
