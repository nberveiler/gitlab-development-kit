# Sherlock profiling

If you want to enable [Sherlock profiling](https://docs.gitlab.com/ee/development/profiling.html#sherlock):

1. Add the following to your `<gdk-root>/gdk.yml` file:

   ```yaml
   ---
   gitlab:
     rails:
       sherlock: true
   ```

1. Reconfigure and restart GDK

    ```shell
    gdk reconfigure
    gdk restart
    ```

1. For the default GDK, browse to the [Sherlock profiling page](http://127.0.0.1:3000/sherlock/transactions).
