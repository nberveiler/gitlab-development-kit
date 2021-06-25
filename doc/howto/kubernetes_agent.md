# GitLab Kubernetes Agent Server

If you wish to clone and keep an updated [GitLab Kubernetes Agent](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent) as part of your GDK, do the following:

1. Install [Bazel](https://www.bazel.build/)

    The recommended way to install Bazel is to use [Bazelisk](https://github.com/bazelbuild/bazelisk). Bazelisk is a version manager for Bazel, much like rbenv for Ruby. See the [installation instructions](https://docs.bazel.build/versions/master/install-bazelisk.html) for Bazelisk.

1. Add the following settings in your `gdk.yml`:

    ```yaml
    gitlab_k8s_agent:
      enabled: true
    ```

1. Create a new project. It is used for agent's configuration. Note the project's ID. Use it as `project_id` below.

1. In the project's repository create a directory named `.gitlab/agents/my-agent`. In this directory create a file `config.yaml` with the following contents:

    ```yaml
    gitops:
      manifest_projects:
    #  - id: "some_project/name"
    ```

   You can find information about supported configuration options in [the agent's documentation](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/configuration_repository.md).

1. There is no [user interface to import a Kubernetes cluster](https://gitlab.com/gitlab-org/gitlab/-/issues/220908) yet, so we need to seed the database manually:

    1. Start the Rails console

        ```shell
        bundle exec rails console
        ```

    1. Create the agent record and an authentication token for the agent:

        ```ruby
        project_id = 123 # use ID of the project you created earlier
        agent_name = 'my-agent' # the name for the agent. This will be the directory name for the agent's configuration
        p = Project.find(project_id)
        agent = Clusters::Agent.create!(project: p, name: agent_name)
        token = Clusters::AgentToken.create!(agent: agent)
        puts token.token # this will print the token for the agent
        ```

1. The token from the previous step can be used by the `agentk` to authenticate itself with GitLab (`kas`).

1. Run `gdk update` to get `kas` installed as part of GDK.

1. Run `gdk reconfigure` to update various configuration files.

1. You can start GDK with `gdk start`. It prints the URL for `agentk` to use:

    ```plaintext
    => GitLab will be available at http://127.0.0.1:3000 shortly.
    => GitLab Kubernetes Agent Server available at grpc://127.0.0.1:8150.
    ```

1. You now have two pieces of information to connect `agentk` to GDK - the URL and the token.

1. To verify that `kas` is running you can:
    - Run `gdk tail gitlab-k8s-agent` to check the logs. You should see no errors in the logs. Empty logs are normal too.
    - Run `curl 127.0.0.1:8150`. It should print

        ```plaintext
        Warning: Binary output can mess up your terminal. Use "--output -" to tell
        Warning: curl to output it to your terminal anyway, or consider "--output
        Warning: <FILE>" to save to a file.
        ```

        This is normal because gRPC is a binary protocol.

    - If running with NGINX enabled, run `curl gdk.test:3000/-/kubernetes-agent`. It should print

        ```plaintext
        WebSocket protocol violation: Connection header "close" does not contain Upgrade
        ```

        This is a normal response from `kas` for such a request because it's expecting a WebSocket connection upgrade.

## (Optional) Deploy the GitLab Kubernetes Agent (agentk) with k3d

1. [Install k3d](https://github.com/rancher/k3d#get).
1. Create a k3d cluster:

   ```shell
   k3d cluster create
   ```

1. Set up a [loopback alias IP](local_network.md#create-loopback-interface). We can use it as the
   listen address so that `agentk` can reach your local GitLab and KAS. Let's assume this is `172.16.123.1`.
   We recommend you also bind your hostname to this address in `/etc/hosts`, by adding the line
   `172.16.123.1 gdk.test` to `/etc/hosts`

   Then update your `gdk.yml` to include these global keys:

   ```yaml
   hostname: gdk.test
   listen_address: "172.16.123.1"
   ```

   This sets the default hostname and listen address for all GDK services, including GitLab.
   For example, with the default ports:

   - GitLab would now be available on `http://gdk.test:3000`.
   - The registry would now be available on `https://gdk.test:5000`.

1. Run `gdk reconfigure` to apply the above change.
1. Deploy `agentk`:

   1. [Create the secret](https://docs.gitlab.com/ee/user/clusters/agent/#create-the-kubernetes-secret)
      as you normally would to deploy it to any cluster.
   1. [Install the Agent to the cluster](https://docs.gitlab.com/ee/user/clusters/agent/#install-the-agent-into-the-cluster).
      At this step, be sure to set your `resources.yml` with the `kas-address` using the loopback alias.

      ```yaml
      args:
          - --token-file=/config/token
          - --kas-address
          - grpc://172.16.123.1:8150
          # - wss://172.16.123.1:8150/-/kubernetes-agent # when using nginx WITH https
          # - ws://172.16.123.1:8150/-/kubernetes-agent # when using nginx WITHOUT https
      ```

   Your above address scheme can be checked with `gdk config get gitlab_k8s_agent.__url_for_agentk`

## (Optional) Run using Bazel instead of GDK

If you want to run GitLab Kubernetes Agent Server and Agent locally with Bazel instead of GDK, see
the [GitLab Kubernetes Agent documentation](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/developing.md#running-the-agent-locally).
