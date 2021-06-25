# GDK commands

The `gdk` command has many sub-commands to perform common tasks.

## Start GDK and basic commands

To start up the GDK with all default enabled services, run:

```shell
gdk start
```

To access GitLab, go to <http://localhost:3000> in your browser. It may take a few minutes for the
Rails app to be ready. During this period you can see `If you just started GDK it can take 60-300 seconds before GitLab has finished booting. This page will automatically reload every 5 seconds.`
in the browser.

The development login credentials are `root` and `5iveL!fe`.

To see logs, run:

```shell
gdk tail
```

When you are not using GDK you may want to shut it down to free up memory on your computer:

```shell
gdk stop
```

If you'd like to run a specific group of services, you can do so by providing
the service names as arguments. Multiple arguments are supported.

## Run specific services

GDK can start specific services only. For example, to start just PostgreSQL and Redis, run:

```shell
gdk start postgresql redis
```

## Stop specific services

GDK can stop specific services. For example, to stop the Rails app to save memory (useful when
running tests), run:

```shell
gdk stop rails
```

## Update GDK

To update `gitlab` and all of its dependencies, run the following commands:

```shell
gdk update
```

This also performs any possible database migrations.

If there are changes in the local repositories, or a different branch than `main` is checked out,
the `gdk update` command:

- Stashes any uncommitted changes.
- Changes to `main` branch.

It then updates the remote repositories.

## Update your `gdk.yml`

When updating your `gdk.yml`, you must regenerate the necessary config files by
running:

```shell
gdk reconfigure
```

## View configuration settings

With `gdk config` you can view GDK configuration settings:

```shell
gdk config get <configuration value>
```

More information can be found in the [configuration documentation](configuration.md).

## Check GDK health

You can run `gdk doctor` to ensure the update left GDK in a good state. If it reports any issues,
you should address them as soon as possible.

```shell
gdk doctor
```

## Reset data

There may come a time where you wish to reset the data within your GDK. Backups
of any reset data will be taken prior and you will be prompted to confirm you
wish to proceed:

```shell
gdk reset-data
```

## GDK pristine

If you want to return your GDK instance to a pristine state which will install
Ruby gems and Node modules from scratch for GitLab, Gitaly, cleaning tmp
directories and cleaning the global golang cache.

```shell
gdk pristine
```

## Measure performance

You can easily create a Sitespeed report for local `gdk` URLs or online URLs with our standardized
Sitespeed settings. We support local relative and absolute URLs as arguments. As soon as the report
is generated, it is automatically opened in your browser.

```shell
gdk measure /explore http://127.0.0.1/explore https://gitlab.com/explore
```

## Measure Workflows performance

```shell
gdk measure-workflow repo_browser
```

All workflow scripts are located in `support/measure_scripts/`, for example `repo_browser` to measure the
basic workflow in the repository.

The reports are stored in `<gdk-root>/sitespeed-result` as `<branch>_YYYY-MM-DD-HH-MM-SS`. This
requires Docker installed and running.
