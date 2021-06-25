# Using GitLab Runner with GDK

Most features of [GitLab CI/CD](http://docs.gitlab.com/ee/ci/) need a
[Runner](http://docs.gitlab.com/ee/ci/runners/README.html) to be registered with
the GitLab installation. This how-to takes you through the necessary steps to
do so when GitLab is running under GDK.

Before setting up Runner, you need to have [set up the GDK](../../index.md) for your workstation.

You can set up a runner to run directly on your workstation or you can set up a runner in Docker.
We will outline the steps for setting up each of these separately.

- [Simple configuration](#simple-configuration)
- [Docker configuration](#docker-configuration) (recommended)

## Simple configuration

If you intend to just use the "shell" executor (fine for simple jobs), you can use the GDK with its default settings.
Builds will run directly on the host computer. If you choose this configuration, don't use random `.gitlab-ci.yml`
files from the internet unless you understand them fully as this could be a security risk. If you need a basic pipeline,
[here is example configuration from our documentation](https://docs.gitlab.com/ee/ci/environments/#configuring-manual-deployments) that
you can use.

### Download GitLab Runner

The runner can be installed using a pre-built binary or from source.

To install from the binary, follow [the runner installation instructions](https://docs.gitlab.com/runner/install/)
for your specific operation system.

To build from source, you'll need to follow
[the runner development instructions](https://docs.gitlab.com/runner/development/). The official
GitLab Runner repository is [here](https://gitlab.com/gitlab-org/gitlab-runner).

To specify a custom `gitlab-runner` binary, add the following to `gdk.yml`:

```yaml
runner:
  bin: <path_to_gitlab_runner_binary>/gitlab-runner-darwin-amd64
```

NOTE:
`runner` should not be confused with [`gitlab_runner`](gitlab_docs.md).

### Setting up a Runner

Run `gitlab-runner register --run-untagged --config <path-to-gdk>/gitlab-runner-config.toml` (as your normal user),
and follow the prompts. Use:

- **coordinator URL**

  Use either:

  - `http://localhost:3000/`
  - `http://<custom_IP_address>:3000/`, if you customized your IP address.

- **token**

  `Registration token` (copied from `<coordinator-url>/admin/runners`)

- **description** (optional)

  A description of the Runner. Defaults to the hostname of the machine.

- **tags** (optional)

  Comma-separated tags. Jobs can be set up to use only Runners with specific tags.

- **executor**

  Since we are running directly on the host computer in this simple configuration, choose `shell`.

The Runner writes its configuration file to `gitlab-runner-config.toml`,
which is in GDK's `.gitignore` file.

To ensure the Runner token persists between subsequent runs of `gdk reconfigure`, add
the token to your `gdk.yml` file:

```yaml
runner:
  enabled: true
  token: <runner-token>
```

Finally, rebuild your `Procfile` with `gdk update` or un-comment
the line that starts with `runner:`. This allows you to manage the runner along with
your other GDK processes.

You can run the `register` command multiple times to set up additional Runners -
fuller documentation on the different types of executor and their requirements
can be found [here](https://docs.gitlab.com/runner/executors/).
Each `register` invocation adds a section to the configuration file, so make
sure you're referencing the same one each time.

Alternately, run `gitlab-runner --log-level debug run --config <path-to-gdk>/gitlab-runner-config.toml`
to get a long-lived Runner process, using the configuration you created in the
last step. It stays in the foreground, outputting logs as it executes
builds, so run it in its own terminal session.

The Runners pane in the administration panel now lists the Runners. Create a
project in the GitLab web interface and add a
[`.gitlab-ci.yml`](https://docs.gitlab.com/ee/ci/examples/) file,
or clone an [example project](https://gitlab.com/groups/gitlab-examples), and
watch as the Runner processes the builds just as it would on a "real" install!

## Docker configuration

Using runners in Docker allows you to set up a clean environment for your builds
each time. It is also safer than running directly on your computer, as the
runner will not have direct access to your computer.

### Set up Docker and GDK

Ensure you have Docker installed, then we will need to set up GitLab to bind to an IP on your machine
instead of `127.0.0.1`. Without this step, builds fail with a `connection refused` error.

The easiest and most universal way to set this up is by using an internal, dummy interface that can
be used by both the host and the Docker container.

1. [Create a loopback interface](local_network.md#create-loopback-interface) for a new private network.
1. In the GitLab Runner configuration (for example, `~/.gitlab-runner/config.toml`), set the coordinator
   URL with an IP on this private network:

  ```toml
  url = "http://172.16.123.1:3000/"
  ```

This can also be combined with a custom hostname by following these
[instructions for setting up `gdk.test`](local_network.md) but using the `172.16.123.1`
instead of `127.0.0.1`. Then set up your runner to resolve the hostname by adding `runner.extra_hosts`
to your `gdk.yml`. For example, for `gdk.test`:

  ```yaml
  runner:
    extra_hosts: ["gdk.test:172.16.123.1"]
  ```

### Alternative method for Linux

An alternative to creating the dummy interface described above is to:

1. Add the following to your `gdk.yml`

    ```yaml
    runner:
      network_mode_host: true
    ```

1. Run `gdk reconfigure`

This will add `network_mode = host` to the `gitlab-runner-config.toml` file:

```toml
[[runners]]
  [runners.docker]
    ...
    network_mode = "host"
```

Note that this method:

- [Only works with Linux hosts](https://docs.docker.com/network/host/).
- Exposes your local network stack to the Docker container, which may be a security issue. Use
  it only to run jobs on projects that you trust.
- Won't work with Docker containers running in Kubernetes because Kubernetes uses its own
  internal network stack.

### Set up a runner

To set up a runner in Docker,
[follow the runner Docker image installation documentation](https://docs.gitlab.com/runner/install/docker.html#docker-image-installation).

When registering a new runner in Docker, the following prompts will appear:

- **coordinator URL**

  Use either:

  - `http://172.16.123.1:3000/`
  - `http://gdk.test:3000/`, if you set up a custom hostname such as `gdk.test`.

- **token**

  `Registration token` (copied from `<coordinator-url>/admin/runners`)

- **description** (optional)

  A description of the Runner. Defaults to the hostname of the machine.

- **tags** (optional)

  Comma-separated tags. Jobs can be set up to use only Runners with specific tags.

- **executor**

  Since we are running our runner in Docker, choose `docker`.

- **Docker image**

  Choose which Docker image you would like to use for this runner. Common ones are `ruby:2.6`
  and `node:latest` but you can find images using
  [Docker's image hub](https://hub.docker.com/search?type=image).
