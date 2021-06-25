# Gitaly and Praefect

GitLab uses [Gitaly](https://docs.gitlab.com/ee/administration/gitaly/index.html) to abstract all
Git calls. To work on local changes to `gitaly`, please refer to the
[Beginner's guide to Gitaly contributions](https://gitlab.com/gitlab-org/gitaly/blob/master/doc/beginners_guide.md).

For more information on Praefect, refer to
[Gitaly Cluster](https://docs.gitlab.com/ee/administration/gitaly/praefect.html).

In GDK, you can change Gitaly and Praefect configuration in the following ways:

- Modify [Gitaly and Praefect options](#gitaly-and-praefect-options).
- [Add Gitaly nodes](#add-gitaly-nodes) to the `default` virtual storage.
- [Add virtual storages](#add-virtual-storages) served by additional Gitaly nodes.

See also [Automate different Praefect configurations](https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues/827)
for information about automating more of these processes.

## Gitaly and Praefect options

By default, GDK is set up use Praefect as a proxy to Gitaly. To disable Praefect, set the following
in `gdk.yml`:

```yaml
praefect:
  enabled: false
```

For other GDK Gitaly and Praefect options, refer to the `gitaly:` and `praefect:` sections of the
[`gdk.example.yml`](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/gdk.example.yml).

## Add Gitaly nodes

By default, GDK generates Praefect configuration containing only one Gitaly node (`node_count: 1`).
To add additional backend Gitaly nodes to use on the `default` virtual storage:

1. Increase the number of nodes by increasing the `node_count` in `gdk.yml`. For example:

   ```yaml
   praefect:
     node_count: 2
   ```

1. Run `gdk reconfigure`.
1. Run `gdk restart`.

Two Gitaly nodes now start when GDK starts. GDK handles the required Praefect configuration for you.

## Add virtual storages

If you need to work with multiple [repository storages](https://docs.gitlab.com/ee/administration/repository_storage_types.html) in GitLab, you can create new virtual storages in
Praefect. You need at least [one more Gitaly node](#add-gitaly-nodes) or storage to create another
virtual storage.

1. Assuming one extra Gitaly node has been created, add a `virtual_storage` definition to
   `gitaly/praefect.config.toml`. For example if one extra Gitaly node was added, your
   configuration might look like:

   ```toml
   [[virtual_storage]]
   name = 'default'

   [[virtual_storage.node]]
   storage = "praefect-internal-0"
   address = "unix:/Users/paulokstad/gitlab-development-kit/gitaly-praefect-0.socket"

   [[virtual_storage]]
   name = 'default2'

   [[virtual_storage.node]]
   storage = "praefect-internal-1"
   address = "unix:/Users/paulokstad/gitlab-development-kit/gitaly-praefect-1.socket"
   ```

   This creates two virtual storages, each served by their own Gitaly node.

1. Edit `gitlab/config/gitlab.yml` to add the new virtual storage to GitLab. For example:

   - Before:

     ```yaml
     repositories:
       storages: # You must have at least a `default` storage path.
         default:
           path: /
           gitaly_address: unix:/Users/paulokstad/gitlab-development-kit/praefect.socket
     ```

   - After:

     ```yaml
     repositories:
       storages: # You must have at least a `default` storage path.
         default:
           path: /
           gitaly_address: unix:/Users/paulokstad/gitlab-development-kit/praefect.socket
         default2:
           path: /
           gitaly_address: unix:/Users/paulokstad/gitlab-development-kit/praefect.socket
     ```

1. Run `gdk restart`.

## Praefect on a Geo secondary

Praefect needs a read-write capable database to track it's state. On a Geo
secondary the main database is read-only. So when GDK is [configured to be
a Geo secondary](geo.md#secondary), Praefect uses the Geo tracking database
instead.

If you have modified this setting, you need to recreate the Praefect database
using:

```shell
gdk reconfigure
```
