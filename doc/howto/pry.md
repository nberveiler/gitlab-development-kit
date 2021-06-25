# Debugging with Pry

[Pry](https://pryrepl.org/) allows you to set breakpoints in Ruby code
for interactive debugging. Just drop in the magic word `binding.pry` into your code.

When running tests, Pry's interactive debugging prompt appears in the
terminal window where you start your test command (`rake`, `rspec` etc.).

If you want to get a debugging prompt while browsing on your local
development server (localhost:3000), you should use `binding.remote_pry` instead.

You can then connect to this session by running `pry-remote` in your terminal.

## Using Thin

An alternative to `binding.remote_pry` is to run your Rails web server via Thin.
Start by kicking off the normal GDK processes via `gdk start`. Then open a new terminal session and run:

```shell
gdk thin
```

This kills the Puma server and starts a Thin server in its place. Once
the `binding.pry` breakpoint has been reached, Pry prompts appear in the window
that runs `gdk thin`.

When you have finished debugging, remove the `binding.pry` breakpoint and go
back to using Puma. Terminate `gdk thin` by pressing Ctrl-C
and run `gdk start`.

NOTE:
It's not possible to submit commits from the web without at least two Puma server
threads running. This means when running `thin` for debugging, actions such as creating a file from
the web time out.
