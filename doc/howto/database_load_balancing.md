# Database load balancing

This document describes the required steps to enable and test the [database load balancing](https://docs.gitlab.com/ee/administration/database_load_balancing.html) feature in GDK.

## Prerequisites

Database load balancing is an Enterprise feature, so you will need to generate a license for your GDK installation. See [Use GitLab Enterprise features](../index.md#use-gitlab-enterprise-features) for instructions.

## Assumptions

For these instructions, we will assume that your GDK root is located at `/full/path/to/gdk-root` and that you are located there. Make sure to use the correct path for your installation.

## Prepare

The first step is to prepare both primary and secondary databases for replication and enabling load balancing.

### Primary

```shell
make postgresql-replication-primary
```

### Secondary

1. Initialize the secondary database:

    ```shell
    make postgresql-replication/data
    ```

1. Remove the secondary database data as we will be replacing the data with that from the primary:

    ```shell
    rm -rf postgresql-replica/data/*
    ```

1. Copy data from primary to secondary with `pg_basebackup`:

    ```shell
    pg_basebackup -R -h /full/path/to/gdk-root/postgresql -D /full/path/to/gdk-root/postgresql-replica/data -P -U gitlab_replication --wal-method=fetch
    ```

   This automatically creates `postgresql.auto.conf` in the PostgreSQL data directory. Older
   versions stored this information in `recovery.conf`, a file that must be deleted for
   PostgreSQL 12 to function.

## Configure GDK

1. Edit `gitlab/config/database.yml`:

   ```yaml
   development:
     # ...
     load_balancing:
       hosts:
         - /full/path/to/gdk-root/postgresql
         - /full/path/to/gdk-root/postgresql-replica
   ```

   Note that `hosts` contains both primary and secondary hosts.

1. Edit `gdk.yml`:

   ```yaml
   postgresql:
     replica:
       enabled: true
   load_balancing:
     enabled: true
   gdk:
     protected_config_files:
     - 'gitlab/config/database.yml'
   ```

   Note that we are protecting `gitlab/config/database.yml` to avoid GDK removing the `postgresql-replica` host line that we just added to `gitlab/config/database.yml`.

1. Reconfigure GDK:

    ```shell
    gdk reconfigure
    ```

1. Restart GDK:

    ```shell
    gdk restart
    ```

At this point you should see both a `postgresql` and a `postgresql-replica` service entry in the `gdk restart` output:

```plaintext
ok: run: ./services/postgresql: (pid 81204) 1s, normally down
ok: run: ./services/postgresql-replica: (pid 81202) 1s, normally down
```

Any data created in GitLab should now be replicated to the secondary database in realtime, and most `SELECT` queries should be routed to the secondary.

## Validate

Now that the databases were prepared for replication, we should validate whether the applied configurations produced the desired effect.

### Primary

1. Open a `psql` console:

    ```shell
    gdk psql
    ```

1. Enable expanded display mode:

    ```plaintext
    \x
    ```

1. Check `pg_stat_activity`:

    ```sql
    select * from pg_stat_activity where usename='gitlab_replication';
    ```

    You should see something like this:

    ```plaintext
    -[ RECORD 1 ]----+------------------------------
    datid            |
    datname          |
    pid              | 81890
    usesysid         | 39897
    usename          | gitlab_replication
    application_name | walreceiver
    client_addr      |
    client_hostname  |
    client_port      | -1
    backend_start    | 2021-01-14 16:56:56.190756+00
    xact_start       |
    query_start      |
    state_change     | 2021-01-14 16:56:56.192009+00
    wait_event_type  | Activity
    wait_event       | WalSenderMain
    state            | active
    backend_xid      |
    backend_xmin     |
    query            |
    backend_type     | walsender
    ```

### Secondary

Check the secondary logs with `gdk tail postgresql-replica`. You should see something like this:

```plaintext
2021-01-14_15:46:15.83178 postgresql-replica    : 2021-01-14 15:46:15.831 WET [60837] LOG:  listening on Unix socket "/full/path/to/gdk-root/postgresql-replica/.s.PGSQL.5432"
2021-01-14_15:46:15.87366 postgresql-replica    : 2021-01-14 15:46:15.873 WET [60991] LOG:  entering standby mode
2021-01-14_15:46:15.88190 postgresql-replica    : 2021-01-14 15:46:15.881 WET [60991] LOG:  redo starts at 0/6010EC8
2021-01-14_15:46:15.88241 postgresql-replica    : 2021-01-14 15:46:15.882 WET [60991] LOG:  consistent recovery state reached at 0/6017678
2021-01-14_15:46:15.88274 postgresql-replica    : 2021-01-14 15:46:15.882 WET [60837] LOG:  database system is ready to accept read only connections
2021-01-14_15:47:13.89654 postgresql-replica    : 2021-01-14 15:47:13.896 WET [60991] LOG:  invalid record length at 0/6018598: wanted 24, got 0
2021-01-14_15:47:13.90324 postgresql-replica    : 2021-01-14 15:47:13.903 WET [61711] LOG:  started streaming WAL from primary at 0/6000000 on timeline 1
```

## Debug

Use these instructions if needing to debug database load balancing.

### Query log

If you want to see which queries go to primary and secondary, you can enable statement logging for each instance, editing `postgresql/data/postgresql.conf` and `postgresql-replica/data/postgresql.conf`, respectively:

```plaintext
log_statement = 'all'                        # none, ddl, mod, all
```

Once done, restart the instances with GDK and tail their logs.

### Simulating replication delay

You can simulate replication delay by adding a minimum delay. The
following setting delays replication by at least 1 minute:

```plaintext
recovery_min_apply_delay = '1min'
```
