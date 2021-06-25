# Configure and use SSH in GDK

GitLab can provide access to its repositories over SSH instead of HTTPS. There
are two ways to enable this in GDK. Either:

- Run the `gitlab-sshd` binary provided by [GitLab Shell](https://gitlab.com/gitlab-org/gitlab-shell).
  Using `gitlab-sshd` is better for multi-host deployments like GitLab.com and
  development environments.
- Integrate GitLab Shell with [OpenSSH](https://openssh.org). Because integrating
  with OpenSSH allows GitLab to provide its services on the same port as the system's
  SSH daemon, this is preferred option for most single-host deployments of GitLab.

GDK enables the first option by default. Only engineers working on the GitLab
OpenSSH integration need to use the second option.

## Change the listen port or other configuration

Copy lines into your `<gdk-root>/gdk.yml` file from `<gdk-root>/gdk.example.yml`,
and adjust as needed. For example, to change the listen port to `2223`:

1. Add the following to your `<gdk-root>/gdk.yml` file:

   ```yaml
   ---
   sshd:
     listen_port: 2223
   ```

1. Run `gdk reconfigure` to configure the `sshd` service.

1. Run `gdk restart` to restart the modified services.

Note that some settings apply:

- Only to `gitlab-sshd` mode:
  - `additional_config`
  - `authorized_keys_file`
  - `bin`
- Only to `gitlab-sshd` mode:
  - `proxy_protocol`
  - `web_listen`

To switch from `gitlab-sshd` to OpenSSH, follow the
instructions under [OpenSSH integration](#openssh-integration).

### Optional: Use privileged port

On UNIX-like systems, only root users can bind to ports up to `1024`. If want GDK to run SSH
on, for example, port `22`, you can provide it the necessary privileges with the following
command:

```shell
sudo setcap 'cap_net_bind_service=+ep' gitlab-shell/bin/gitlab-sshd
```

## Try it out

You can check that SSH works by cloning any project (for example, `Project.first.ssh_url_to_repo`).
This also updates your `known_hosts` file.

## OpenSSH integration

In general, we recommend that you use `gitlab-sshd`. If you want to work on the
GitLab OpenSSH integration specifically, you can switch to it:

1. Add the following to your `<gdk-root>/gdk.yml` file:

   ```yaml
   ---
   sshd:
     use_gitlab_sshd: false
   ```

1. Run `gdk reconfigure` to switch from `gitlab-sshd` to OpenSSH.

1. Run `gdk restart` to restart the modified services.

You should now have an unprivileged OpenSSH daemon process running on
`127.0.0.1:2222`, integrated with `gitlab-shell`.

In unprivileged mode, OpenSSH can't change users, so you'll have to connect to
it using your system username, rather than `git`. The Rails web interface will
list the correct username whenever it gives you an example command, but you may
have to use `git remote set-url` in any repositories you have already cloned
from the instance to update them.

### SSH key lookup from database

For more information, see the
[official documentation](https://docs.gitlab.com/ee/administration/operations/speed_up_ssh.html#the-solution).
The `gitlab-sshd` approach uses SSH key lookup from database automatically, but
when using OpenSSH instead, a few more steps are required.

We'll create a wrapper script to invoke
`<gdk-root>/gitlab-shell/bin/gitlab-shell-authorized-keys-check`. This wrapper is useful
because the file invoked by `AuthorizedKeysCommand`, and all of its parent directories,
*must* be owned by `root`. We'll place the wrapper script in `/opt/gitlab-shell` as an
example, but it can be placed in any directory which is owned by `root` and whose parent
directories are also owned by `root`.

1. Create a file at `/opt/gitlab-shell/wrap-authorized-keys-check` with the following
   contents, making sure to replace `<gdk-root>` with the actual path:

   ```shell
   #!/bin/bash

   <gdk-root>/gitlab-shell/bin/gitlab-shell-authorized-keys-check "$@"
   ```

1. Make the script owned by root:

   ```shell
   sudo chown root /opt/gitlab-shell/wrap-authorized-keys-check
   ```

1. Make the script executable:

   ```shell
   sudo chmod 755 /opt/gitlab-shell/wrap-authorized-keys-check
   ```

1. Make OpenSSH check for authorized keys using `wrap-authorized-keys-check`. Add the
   following configuration in your `<gdk-root>/gdk.yml` file:

   ```yaml
   ---
   sshd:
     enabled: true
     additional_config: |
       Match User <GDK user> # Apply the AuthorizedKeysCommands to the git user only
         AuthorizedKeysCommand /opt/gitlab-shell/wrap-authorized-keys-check <GDK user> %u %k
         AuthorizedKeysCommandUser <GDK user>
       Match all # End match, settings apply to all users again
   ```

   `GDK user` should be the user that is running your GDK. This is probably your local
   username. You can double check this by looking in
   `<gdk-root>/gitlab/config/gitlab.yml` for the value of `development.gitlab.user`
   (or `production.gitlab.user`), or check which username is returned by
   `Project.first.ssh_url_to_repo`.
