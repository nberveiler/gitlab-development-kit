# Lefthook

[Lefthook](https://github.com/Arkweid/lefthook) is a Git hooks manager that allows
custom logic to be executed prior to Git committing or pushing. GDK comes with
Lefthook configuration (`lefthook.yml`), but it must be installed.

We have a `lefthook.yml` checked in but is ignored until Lefthook is installed.

## Install Lefthook

1. Install the `lefthook` Ruby gem:

   ```shell
   bundle install
   ```

1. Install Lefthook managed Git hooks:

   ```shell
   bundle exec lefthook install
   ```

1. Test Lefthook is working by running the Lefthook `prepare-commit-msg` Git hook:

   ```shell
   bundle exec lefthook run prepare-commit-msg
   ```

This should return a fully qualified path command with no other output.

## Run Lefthook hooks manually

To run the `pre-push` Git hook, run:

   ```shell
   bundle exec lefthook run pre-push
   ```
