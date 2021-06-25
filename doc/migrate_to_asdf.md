# Migrate from self-managed dependencies to GDK-managed dependencies using `asdf`

If you've previously [managed your own dependencies](advanced.md), you might want to let GDK manage
dependencies for you using `asdf`. The following are instructions to help you remove previously
installed self-managed dependencies so that they don't conflict with `asdf`:

1. Uninstall dependencies you installed with your operating system's package manager. For example,
   for macOS:

   ```shell
   brew uninstall go postgresql@12 minio/stable/minio redis yarn
   ```

1. Uninstall your Ruby dependency manager, usually `rvm` or `rbenv`. If you're unsure which Ruby
   dependency manager you were using, run `which ruby` at the command line. The dependency manager in
   use should be indicated by the output. For more information, see:

   - [`rbenv` uninstall](https://github.com/rbenv/rbenv#uninstalling-rbenv) documentation.
   - [`rvm` removal](https://rvm.io/support/troubleshooting) documentation. Relevant is the
     section "How do I completely clean out all traces of RVM from my system, including for
     system wide installs?".

1. Uninstall your Node dependency manager (usually `nvm` or `brew`). If you're unsure which Node
   dependency manager you were using, run `which node` at the command line. The dependency manager in
   use should be indicated by the output:

   - If using `nvm`, see [uninstalling `nvm` documentation](https://github.com/nvm-sh/nvm#uninstalling--removal).
   - If not using `nvm`, try running `brew uninstall node`.

1. Remove configuration from your home directory relating to these dependency managers. For example:

   - `~/.rvm`.
   - `~/.rbenv`.
   - `~/.nvm`.

1. Remove shell-related configuration settings related to your dependency managers in files such as:

   - `.bashrc` for `bash`.
   - `.zshrc` for `zsh`.

It's possible:

- You have more than one dependency manager handling the same dependency. In this case, repeat the
  process for each. For example, removing an `nvm`-managed `node` might reveal a `brew`-managed
  `node`.
- That your system provides a dependency also (for example, macOS comes with Ruby itself). Don't
  try to remove these because `asdf` is less likely to conflict with these.
- That in order for `asdf` to successfully install Node.js, you may need to import
  [Node.js release keys](https://github.com/nodejs/node#release-keys) into GPG.
