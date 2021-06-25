# Puma

[Puma](https://github.com/puma/puma) is the default web server used by GitLab.com and
the GDK.

To reduce memory usage in GDK, the `nakayoshi_fork` is enabled by default in GDK.
According to the
[`nakayoshi_fork` pull request](https://github.com/puma/puma/pull/2256), the fork was
added to:

> Reduce memory usage in preloaded cluster-mode apps by GCing before
> fork and compacting, where available.

## Disable `nakayoshi_fork`

The `nakayoshi_fork` can be disabled if needed by setting the
`DISABLE_PUMA_NAKAYOSHI_FORK` environment variable to `true`:

```shell
export DISABLE_PUMA_NAKAYOSHI_FORK=true
gdk restart
```
