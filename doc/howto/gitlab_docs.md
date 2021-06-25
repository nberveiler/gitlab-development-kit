# GitLab Docs in GDK

You can use the GDK to develop GitLab documentation. The GDK can:

- Maintain a clone of the [`gitlab-docs`](https://gitlab.com/gitlab-org/gitlab-docs) repository
  for work on changes to that project.
- Preview changes made in the GDK-managed `gitlab/doc` directory.
- Run linting tasks that require `gitlab-docs`, including internal link and anchor checks.

## Enable GitLab Docs

To enable GDK to manage `gitlab-docs`:

1. Add the following to your [`gdk.yml` file](../configuration.md#gitlab-docs-settings):

   ```yaml
   gitlab_docs:
     enabled: true
   ```

   The default port is `3005` but this can be customized. For example:

   ```yaml
   gitlab_docs:
     enabled: true
     port: 4005
   ```

   By default, `gitlab-docs` is updated from the default project branch every time `gdk update` is
   run. This can be disabled:

   ```yaml
   gitlab_docs:
     enabled: true
     auto_update: false
   ```

1. Run `gdk update` to:
   - Clone `gitlab-docs` for the first time, or update an existing local copy.
   - Compile a published version of the contents of the `gitlab/doc` directory.
1. Start the `gitlab-docs` service:

   ```shell
   gdk start gitlab-docs
   ```

1. Go to the URL shown in the terminal to ensure the site loads correctly. If the site doesn't
   load correctly, `tail` the `gitlab-docs` logs:

   ```shell
   gdk tail gitlab-docs
   ```

## Make documentation changes

You can preview documentation changes as they would appear when published on
[GitLab Docs](https://docs.gitlab.com).

To make changes to GitLab documentation and preview them:

1. Start the `gitlab-docs` service and ensure you can preview the documentation site:

   ```shell
   gdk start gitlab-docs
   ```

1. Make the necessary changes to the files in `<path_to_gdk>/gitlab/doc`.
1. View the preview. If you:
   - Enable [all documentation projects](#include-more-documentation), your preview automatically
     reloads with the changes.
   - Enable only some documentation projects, you must restart the `gitlab-docs` service to
     recompile the published version of the documentation with the new changes:

     ```shell
     gdk restart gitlab-docs
     ```

### Include more documentation

The full published documentation suite [includes additional documentation](https://docs.gitlab.com/ee/development/documentation/site_architecture/index.html)
from outside the [`gitlab` project](https://gitlab.com/gitlab-org/gitlab).

To be able to make and preview changes to the additional documentation:

1. Add the following to your [`gdk.yml`](../configuration.md#additional-projects) as required:

   ```yaml
   gitlab_docs:
     enabled: true
   gitlab_runner:
     enabled: true
   omnibus_gitlab:
     enabled: true
   charts_gitlab:
     enabled: true
   ```

1. Run `gdk update` to:
   - Clone the additional projects for the first time, or update existing local copies.
   - Compile a published version of the additional documentation.
1. Start the `gitlab-docs` service if not already running:

   ```shell
   gdk start gitlab-docs
   ```

NOTE:
`gitlab_runner` should not be confused with [`runner`](runner.md).

By default, the cloned repositories of the `gitlab_runner`, `omnibus_gitlab`, and `charts_gitlab`
components are:

- Updated automatically when you run `gdk update`. To disable this, set `auto_update: false` against
  whichever project to disable.
- Cloned using HTTPS. If you originally [cloned `gitlab` using SSH](../index.md#install-gdk), you
  might want to set these cloned repositories to SSH also. To set these repositories to SSH:

  1. Go into each cloned repository and run `git remote -v` to review the current settings.
  1. To switch to SSH, run `git remote set-url <remote name> git@gitlab.com:gitlab-org/<project path>.git`.
     For example, to update your HTTPS-cloned `gitlab-runner` repository (with a `remote` called
     `origin`), run:

     ```shell
     cd <GDK root path>/gitlab-runner
     git remote set-url origin git@gitlab.com:gitlab-org/gitlab-runner.git
     ```

  1. Run `git remote -v` in each cloned repository to verify that you have successfully made the change from
     HTTPS to SSH.

### Check links

If you move or rename any sections within the documentation, you can verify your changes
don't break any links by running:

```shell
make gitlab-docs-check
```

This check requires:

- `gitlab_docs.enabled` is true.
- `enabled` is true for [all other projects](#include-additional-documentation) that provide
  documentation.

### Troubleshooting

#### Stale published documentation

Sometimes the local published version of the documentation can fall out-of-date with the source
content. In these cases, you can remove the data structure `nanoc` uses to keep track of changes
with the following command:

```shell
make gitlab-docs-clean
```

This causes `nanoc` to rebuild all documentation on the next run.

#### Documentation from disabled projects appears in preview

Disabling [additional documentation projects](#include-more-documentation) doesn't remove them
from your file system and `nanoc` continues to use them as a source of documentation. When disabled,
the projects aren't updated so `nanoc` is using old commits to preview the data from those projects.

To ensure only enabled projects appear in the preview:

1. Disable any projects you don't want previewed.
1. Remove the cloned project directory from within GDK.

#### `No preset version installed` error for `markdownlint`

Sometimes the `./scripts/lint-doc.sh` script fails with an error similar to:

```shell
No preset version installed for command markdownlint
Please install a version by running one of the following:

asdf install nodejs 14.16.1
```

The cause is unknown but you can try reinstalling `markdownlint` and reshiming:

```shell
$ rm -f ~/.asdf/shims/markdownlint
$ make markdownlint-install

INFO: Installing markdownlint..
$ asdf reshim nodejs
```
