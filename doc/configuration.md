# GDK configuration

This document describes how you can configure your GDK environment.

- [Git configuration](#git-configuration).
- [GDK configuration](#gdk-configuration).
- [Webpack settings](#webpack-settings).
- [Grafana settings](#grafana-settings).
- [`asdf` settings](#asdf-settings).

## Git configuration

Git has features which are disabled by default, and would be great to enable to
be more effective with Git. Run `rake git:configure` to set the recommendations
for some repositories within the GDK.

To set the configuration globally, run `rake git:configure[true]`. When using
`zsh`, don't forget to escape the square brackets: `rake git:configure\[true\]`.

## GDK configuration

There are many configuration options for GDK. GDK can be configured using either:

- [`gdk.yml`](#gdkyml) configuration file.
- [Loose files](#loose-files-deprecated) (deprecated).

### `gdk.yml`

You can override the GDK's default settings with a `gdk.yml` in the GDK root,
which is the only supported configuration method.

To see available configuration settings, see [`gdk.example.yml`](../gdk.example.yml).

This file contains all possible settings with example values. Note
that these values may not be the default that GDK uses.

If you want to check which settings are in place, you can run `rake dump_config`, which prints
all applied settings in a YAML structure.

- [Notable settings](#notable-settings)
- [GDK settings](#gdk-settings)
- [GitLab settings](#gitlab-settings)
- [GitLab Docs settings](#gitlab-docs-settings)
- [NGINX settings](#nginx-settings)

#### Run GitLab and GitLab FOSS concurrently

To have multiple GDK instances running concurrently, for example to test GitLab and GitLab FOSS,
initialize each into a separate GDK folder. To run them simultaneously, make sure they don't use
conflicting port numbers.

For example, you can create the following `gdk.yml` in the GitLab FOSS GDK to customise to avoid conflicting port numbers:

```yaml
port: 3001
webpack:
  port: 3809
gitlab_pages:
  port: 3011
```

#### Overwriting configuration files

Any configuration file managed by GDK is overwritten
whenever there are changes in its source (a `.example` or `.erb`
file). When GDK overwrites a configuration file it moves the original file
into the `.backups` subdirectory of your GDK installation.

If you have local changes that you don't want GDK to touch you can
protect individual configuration files. For example:

```yaml
# in gdk.yml
gdk:
  protected_config_files:
  - 'gitaly/*.toml'
```

> Note that `gdk.yml` is not managed by GDK and GDK never overwrites it.

#### Notable settings

Here are a few settings worth mentioning:

| Setting                          | Default               | Description                                                                                |
|--------------------------------- |-----------------------|--------------------------------------------------------------------------------------------|
| `listen_address`                 | `127.0.0.1`           | Select the IP for GDK to listen on. Note, this will occasionally be used as a hostname/URL (when running feature specs for example), so using 0.0.0.0 can be problematic. |
| `port`                           | `3000`                | Select the port to run GDK on, useful when running multiple GDKs in parallel.              |
| `webpack.port`                   | `3808`                | Also useful to configure when running GDKs in parallel. [See below for more webpack options](#webpack-settings). |
| `gitlab.cache_classes`           | `false`               | Set this to `true` to disable the automatic reloading of Ruby classes when Ruby code is changed. |
| `gitlab_pages.host`              | `127.0.0.1.nip.io`    | Specify GitLab Pages hostname. See also the [Pages guide](howto/pages.md#hostname). |
| `gitlab_pages.port`              | `3010`                | Specify on which port GitLab Pages should run. See also the [Pages guide](howto/pages.md#port). |
| `relative_url_root`              | `/`                   | When you want to test GitLab being available on a different path than `/`. For example, `/gitlab`. |
| `object_store.enabled`           | `false`               | Set this to `true` to enable Object Storage with MinIO.                                    |
| `object_store.consolidated_form` | `false`               | Set this to `true` to use the [consolidated object storage configuration](https://docs.gitlab.com/ee/administration/object_storage.html#consolidated-object-storage-configuration). Required for Microsoft Azure. |
| `object_store.connection`        | See `gdk.example.yml` | Specify the [object storage connection settings](https://docs.gitlab.com/ee/administration/object_storage.html#connection-settings).
| `registry.enabled`               | `false`               | Set this to `true` to enable container registry.                                           |
| `geo.enabled`                    | `false`               | Set this to `true` to enable Geo (for now it just enables `postgresql-geo` and `geo-cursor` services). |
| `gitlab.rails.puma.workers`      | `2`                   | Set this to `0` to prevent Puma (webserver) running in a [Clustered mode](https://github.com/puma/puma/blob/master/docs/architecture.md). Running in Single mode provides significant memory savings if you work within a [memory-constrained environment](https://gitlab.com/groups/gitlab-org/-/epics/5303). |

For example, to change the port GDK is accessible on, you can set this in your `gdk.yml`:

```yaml
port: 3001
```

And run the following command to apply the change:

```shell
gdk reconfigure
```

##### Object storage configuration

The following examples are a quick guide for configuring object storage
for external S3 providers, Google Cloud Storage, or Microsoft Azure.
See the [object storage settings](https://docs.gitlab.com/ee/administration/object_storage.html).
Note that we recommend enabling `consolidated_form` to `true`.

In development, you may also use a single bucket for testing.

###### External S3 providers

```yaml
object_store:
  enabled: true
  consolidated_form: true
  connection:
    provider: 'AWS'
    aws_access_key_id: '<YOUR AWS ACCESS KEY ID>'
    aws_secret_access_key: '<YOUR AWS SECRET ACCESS KEY>'
  objects:
    artifacts:
      bucket: artifacts
    external_diffs:
      bucket: external-diffs
    lfs:
      bucket: lfs-objects
    uploads:
      bucket: uploads
    packages:
      bucket: packages
    dependency_proxy:
      bucket: dependency_proxy
    terraform_state:
      bucket: terraform
    pages:
      bucket: pages
```

###### Google Cloud Storage

```yaml
object_store:
  enabled: true
  consolidated_form: true
  connection:
    provider: 'Google'
    google_project: '<YOUR GOOGLE PROJECT ID>'
    google_json_key_location: '<YOUR PATH TO GCS CREDENTIALS>'
  objects:
    artifacts:
      bucket: artifacts
    external_diffs:
      bucket: external-diffs
    lfs:
      bucket: lfs-objects
    uploads:
      bucket: uploads
    packages:
      bucket: packages
    dependency_proxy:
      bucket: dependency_proxy
    terraform_state:
      bucket: terraform
    pages:
      bucket: pages
```

###### Microsoft Azure Blob storage

To make Microsoft Azure Blob storage work, `consolidated_form` must be
set to `true`:

```yaml
object_store:
  enabled: true
  consolidated_form: true
  connection:
    provider: 'AzureRM'
    azure_storage_account_name: '<YOUR AZURE STORAGE ACCOUNT>'
    azure_storage_access_key: '<YOUR AZURE STORAGE ACCESS KEY>'
  objects:
    artifacts:
      bucket: artifacts
    external_diffs:
      bucket: external-diffs
    lfs:
      bucket: lfs-objects
    uploads:
      bucket: uploads
    packages:
      bucket: packages
    dependency_proxy:
      bucket: dependency_proxy
    terraform_state:
      bucket: terraform
    pages:
      bucket: pages
```

#### GDK settings

There are also a few settings that configure the behavior of GDK itself:

| Setting                           | Default | Description                                                                                      |
|-----------------------------------|---------|--------------------------------------------------------------------------------------------------|
| `gdk.ask_to_restart_after_update` | `true`  | Set this to `false` if you do not wish to be prompted to restart your GDK after an update. |
| `gdk.debug`                       | `false` | Set this to `true` to enable increased output. |
| `gdk.overwrite_changes`           | `false` | When set to `true`, `gdk reconfigure` overwrites files and move the old version to `.backups`.|
| `gdk.protected_config_files`      | `[]`    | Contains file names / globs of configuration files GDK should not overwrite. |
| `gdk.runit_wait_secs`             | `10`    | The number of seconds `runit` waits. `runit` is used behind the scenes for `gdk stop/start/restart` and waits for 7 secs by default. |
| `gdk.quiet`                       | `true`  | Set this to `false` to increase the level of output when updating the GDK. |
| `gdk.auto_reconfigure`            | `true`  | Set this to `false` to not run a `gdk reconfigure` after a successful `gdk update`. |

##### Hooks

Before and after hooks are supported for `gdk start`, `gdk stop`, and `gdk update`.

NOTE:
Hooks are executed with the GDK root directory as the working directory. Execution halts if a command completes with a non-zero exit code.

| Setting                    | Default | Description                                                         |
|----------------------------|---------|---------------------------------------------------------------------|
| `gdk.start_hooks.before`   | `[]`    | Array of commands to be executed sequentially before `gdk start`.   |
| `gdk.start_hooks.after`    | `[]`    | Array of commands to be executed sequentially after `gdk start`.    |
| `gdk.stop_hooks.before`    | `[]`    | Array of commands to be executed sequentially before `gdk stop`.    |
| `gdk.stop_hooks.after`     | `[]`    | Array of commands to be executed sequentially after `gdk stop`.     |
| `gdk.update_hooks.before`  | `[]`    | Array of commands to be executed sequentially before `gdk update`.  |
| `gdk.update_hooks.after`   | `[]`    | Array of commands to be executed sequentially after `gdk update`.   |

NOTE:
When running `gdk restart`, `gdk.stop_hooks` (both before & after) are executed before restarting and `gdk.start_hooks` (both before & after) are executed after restarting.

For example, if you're left with changes in `gitlab/db/structure.sql` after a
`gdk update` (see [GitLab#300251](https://gitlab.com/gitlab-org/gitlab/-/issues/300251)),
you can use `gdk.update_hooks.after` in your `gdk.yml`:

```yaml
gdk:
  update_hooks:
    after:
      - cd gitlab; git checkout db/structure.sql
```

### GitLab settings

| Setting | Default | Description |
|---------|---------|-------------|
| `gitlab.cache_classes` | `false`  | Set this to `true` to disable the automatic reloading of Ruby classes when Ruby code is changed. |
| `gitlab.rails.address` | `''`     | Specify whether Rails should listen to a UNIX socket or a TCP port. Useful for debugging with Wireshark. Use `host:port` to listen on a TCP port. Do **not** include `http://`. |
| `gitlab.rails.sherlock` | `false` | Set this to `true` to enable [Sherlock profiling](https://docs.gitlab.com/ee/development/profiling.html#sherlock). |
| `gitlab.rails.puma.workers` | `2` | Set this to `0` to prevent Puma (webserver) running in a [Clustered mode](https://github.com/puma/puma/blob/master/docs/architecture.md). Running in Single mode provides significant memory savings if you work within a [memory-constrained environment](https://gitlab.com/groups/gitlab-org/-/epics/5303). |

### GitLab Docs settings

Under the `gitlab_docs` key, you can define the following settings:

| Setting                   | Default | Description                                                                                              |
|:--------------------------|:--------|:---------------------------------------------------------------------------------------------------------|
| `gitlab_docs.enabled`     | `false` | Set to `true` to enable [`gitlab-docs`](https://gitlab.com/gitlab-org/gitlab-docs) to be managed by GDK. |
| `gitlab_docs.auto_update` | `true`  | Set to `false` to disable updating the `gitlab-docs` checkout.                                           |
| `gitlab_docs.port`        | `3005`  | The port for `nanoc` to listen on.                                                                       |

For more information on using GitLab Docs with GDK, see the [GitLab Docs how to](howto/gitlab_docs.md).

### Additional projects

You can have GDK manage checkouts for `gitlab-runner`, `omnibus-gitlab`, and `charts/gitlab` projects.

Under the `gitlab_runner` key, you can define the following settings:

| Setting                      | Default | Description                                                                                                  |
|:-----------------------------|:--------|:-------------------------------------------------------------------------------------------------------------|
| `gitlab_runner.enabled`      | `false` | Set to `true` to enable [`gitlab-runner`](https://gitlab.com/gitlab-org/gitlab-runner) to be managed by GDK. |
| `gitlab_runner.auto_update`  | `true`  | Set to `false` to disable updating the `gitlab-runner` checkout.                                             |

Under the `omnibus_gitlab` key, you can define the following settings:

| Setting                       | Default | Description                                                                                                    |
|:------------------------------|:--------|:---------------------------------------------------------------------------------------------------------------|
| `omnibus_gitlab.enabled`      | `false` | Set to `true` to enable [`omnibus-gitlab`](https://gitlab.com/gitlab-org/omnibus-gitlab) to be managed by GDK. |
| `omnibus_gitlab.auto_update`  | `true`  | Set to `false` to disable updating the `omnibus-gitlab` checkout.                                              |

Under the `charts_gitlab` key, you can define the following settings:

| Setting                      | Default | Description                                                                                                  |
|:-----------------------------|:--------|:-------------------------------------------------------------------------------------------------------------|
| `charts_gitlab.enabled`      | `false` | Set to `true` to enable [`charts/gitlab`](https://gitlab.com/gitlab-org/charts/gitlab) to be managed by GDK. |
| `charts_gitlab.auto_update`  | `true`  | Set to `false` to disable updating the `charts/gitlab` checkout.                                             |

NOTE:
If you set `enabled` to `true` for all of these projects, you can
[live preview documentation changes](howto/gitlab_docs.md#make-documentation-changes).

### NGINX settings

| Setting | Default | Description |
|---------|---------|-------------|
| `nginx.enabled` | `false` | Set this to `true` to enable the `nginx` service. |
| `nginx.listen` | `127.0.0.1` | Set this to the IP for NGINX to listen on. |
| `nginx.bin` | `/usr/sbin/nginx` | Set this to the path to your `nginx` binary. |
| `nginx.ssl.certificate` | `localhost.crt` | This maps to [NGINX's `ssl_certificate`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate). |
| `nginx.ssl.key` | `localhost.key` | This maps to [NGINX's `ssl_certificate_key`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate_key). |
| `nginx.http2.enabled` | `false` | Set this to `true` to enable HTTP/2 support. |

See [configuring NGINX](howto/nginx.md) for a comprehensive guide.

### Loose files (deprecated)

Before `gdk.yml` was introduced, GDK could be configured through a
bunch of loose files, where each file sets one setting.

It is still possible to use these loose files, but it's deprecated and
is scheduled to be removed in the future. A migration path is planned.

Below is a table of all the settings that can be set this way:

| Filename                     | Type         | Default                                                                              |
|------------------------------|--------------|--------------------------------------------------------------------------------------|
| `host` / `hostname`          | string or IP | `127.0.0.1`                                                                          |
| `port`                       | number       | `3000`                                                                               |
| `https_enabled`              | boolean      | `false`                                                                              |
| `relative_url_root`          | string       | `/`                                                                                  |
| `webpack_host`               | string or IP | `127.0.0.1`                                                                          |
| `webpack_port`               | number       | `3808`                                                                               |
| `registry_enabled`           | boolean      | `false`                                                                              |
| `registry_port`              | number       | `5000`                                                                               |
| `registry_image`             | string       | `registry.gitlab.com/gitlab-org/build/cng/gitlab-container-registry:v2.9.1-gitlab`   |
| `object_store_enabled`       | boolean      | `false`                                                                              |
| `object_store_port`          | number       | `9000`                                                                               |
| `postgresql_port`            | number       | `5432`                                                                               |
| `postgresql_geo_port`        | number       | `5432`                                                                               |
| `gitlab_pages_port`          | number       | `3010`                                                                               |
| `google_oauth_client_secret` | ?            | ?                                                                                    |
| `google_oauth_client_id`     | ?            | ?                                                                                    |

### Configuration precedence

GDK uses the following order of precedence when selecting the
configuration method to use:

- `gdk.yml`
- Loose file
- Default value

### Reading the configuration

To print settings from the configuration you can use `gdk config get <setting>`.

More information on the available `gdk` commands is found in [GDK commands](gdk_commands.md).

### Implementation detail

Here are some details on how the configuration management is built.

#### GDK::ConfigSettings

This is the base class and the engine behind the configuration
management. It defines a DSL to configure GDK.

Most of the magic happens through the class method
`.method_missing`. The implementation of this method dynamically
defines instance methods for configuration settings.

Below is an example subclass of `GDK::ConfigSettings` to demonstrate
each kind.

```ruby
class ExampleConfig < GDK::ConfigSettings
  foo 'hello'
  bar { rand(1..10) }
  fuz do |f|
    f.buz 1234
  end
end
```

- `foo`: (literal value) This is just a literal value, it can be any
  type (for example, Number, Boolean, String).
- `bar`: (block without argument) This is using a block to set a
  value. It evaluates the Ruby code to dynamically calculate a value.
- `fuz`: (block with argument) When the block takes a single argument,
  it expects you are setting child settings.

If you'd dump this configuration with `rake dump_config`, you get something
like:

```yaml
foo: hello
bar: 5
fuz:
  buz: 1234
```

When you use a block without argument you can also calculate a value
based on another setting. So for example, we'd could replace the `bar`
block with `{ config.fuz.buz + 1000 }` and then the value would be
`2234`.

#### `GDK::Config`

`GDK::Config` is the single source of truth when it comes down to
defaults. In this file, every existing setting is specified and for
each setting a default is provided.

#### Dynamic settings

Some settings in `GDK::Config` are prepended with `__` (double
underscore). These are not supposed to be set in `gdk.yml` and only
act as a intermediate value. They also are not shown by `#dump!`.

### Adding a setting

When you add a new setting:

1. Add it to `lib/gdk/config.rb`.
1. Run `rake gdk.example.yml` to regenerate this file.
1. Commit both files.

## Runner settings

Under the runner key you can define the following settings for the [GitLab Runner](https://docs.gitlab.com/runner/):

| Setting | Default | Description |
| --- | ------ | ----- |
| `enabled` | `false` | Set this to `true` to enable the `runner` service. |
| `network_mode_host` | `false` | Set this to `true` to set `network_mode = "host"` for the `[runners.docker]` section (only on Linux). |

## Webpack settings

### Webpack `gdk.yml` settings

Under the webpack key you can define the following settings with their defaults:

```yaml
webpack:
  host: 127.0.0.1
  port: 3808
  static: false
  vendor_dll: false
  incremental: false
```

| Setting | Default | Description |
| --- | ------ | ----- |
| `host` | `127.0.0.1` | The host your webpack development server is running on. Usually no need to change. |
| `port` | `3808` | The port your webpack development server is running on. You should change this if you are running multiple GDKs |
| `static` | `false` | Setting this to `true` replaces the webpack development server with a lightweight Ruby server with. See below for more information |
| `vendor_dll` | `false` | Setting this to `true` moves certain dependencies to a webpack DLL. See below for more information |
| `incremental` | `false` | Setting this to `true` enables incremental webpack rendering. See below for more information |
| `sourcemaps` | `true` | Setting this to `false` disables source maps. This reduces memory consumption for those who do not need to debug frontend code. |
| `live_reload` | `true` | Setting this to `false` disables hot module replacement when changes are detected. This feature uses sockets and is currently incompatible with SSL, so it is disabled by default when SSL is enabled. |

#### Saving memory on the webpack development server

GDK defaults to memory-intensive settings. GDK uses the webpack development server, which watches
file changes and keeps all the frontend assets in memory. This allows for very fast recompilation.

An alternative is to lower the memory requirements of GDK. This is useful for back-end development
or where GDK is running in lower-memory environments. To lower the memory requirements of GDK:

- Set `webpack.static: true` in your `gdk.yml`. All frontend assets are compiled once when GDK starts
  and again from scratch if any front-end source or dependency file changes. For example, when
  switching branches.
- Set `webpack.vendor_dll: true` in your `gdk.yml`. This mode is an alternate memory saving mode,
  which takes infrequently updated dependencies and combines them into one long-lived bundle that is
  written to disk and does not reside in memory. You may see 200 to 300 MB in memory savings.
- Set `webpack.incremental: true` in your `gdk.yml`. This enables incremental compilation of webpack
  assets and only the JavaScript for pages you visit during development are compiled.
  If you visit a previously unvisited page, you see an overlay informing you that the recompilation
  happens. A page reload then serves the correct assets (either manually or via `live_reload`).

This means you pay a high upfront cost of a single memory- and CPU-intenstive compile. However, if
you do not change any frontend files, you just have a lightweight Ruby server running.

If you experience any problems with one of the modes, you can quickly change the settings in your
`gdk.yml` and regenerate the `Procfile`:

```shell
gdk reconfigure
```

### Webpack environment variables

The GitLab application exposes various configuration options for webpack via
environment variables. These can be modified to improve performance or enable debugging.

These settings can be configured using [`env.runit`](runit.md#modifying-environment-configuration-for-services).

| Variable | Default | Description |
| ------------- | ------- | ----------- |
| DEV_SERVER_LIVERELOAD | true | Disables live reloading of frontend assets |
| NO_COMPRESSION        | false | Disables compression of assets |
| NO_SOURCEMAPS         | false | Disables generation of source maps (reduces size of `main.chunk.js` by ~50%) |
| WEBPACK_MEMORY_TEST   | false | Output the in-memory heap size upon compilation and exit |
| WEBPACK_CACHE_PATH    | `./tmp/cache` | Path string to temporary dir     |
| WEBPACK_REPORT        | false       | Generates bundle analysis report |
| WEBPACK_VENDOR_DLL    | false       | Reduce webpack-dev-server memory requirements when vendor bundle has been precompiled with `yarn webpack-vendor` |
| GITLAB_UI_WATCH       | false | Use GDK's copy of `gitlab-ui` instead of the npm-installed version. |

## ActionCable settings

Under the `action_cable` key you can define the following settings with their defaults:

```yaml
action_cable:
  in_app: true
  worker_pool_size: 4
```

| Setting            | Default | Description |
|--------------------|---------|-------------|
| `in_app`           | `true`  | Set this to `false` to run ActionCable as a separate service. |
| `worker_pool_size` | `4`     | Adjust this to control the number of ActionCable threads. This usually doesn't need to be changed. |

By default, ActionCable runs in-app using the same Puma workers used to serve web requests. This results in memory
savings since we don't need to start another process that boots the whole GitLab Rails app.

When this is set to `false`, a separate Puma process starts to handle ActionCable requests and workhorse is
configured to proxy to this process.

## Grafana settings

Under the `grafana` key you can define the following settings with their defaults:

```yaml
grafana:
  enabled: false
  port: 4000
```

| Setting   | Default | Description |
|-----------|---------|-------------|
| `enabled` | `false` | Set this to `true` to enable the `grafana` service. |
| `port`    | `4000`  | Set your preferred TCP port for the `grafana` service. |

## `asdf` settings

Under the `asdf` key you can define the following settings with their defaults:

```yaml
asdf:
  opt_out: false
```

| Setting   | Default | Description |
|-----------|---------|-------------|
| `opt_out` | `false` | Set this to `true` to tell GDK to _not_ use `asdf`, even if it's installed. |
