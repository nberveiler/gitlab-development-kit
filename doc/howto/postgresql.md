# PostgreSQL

GDK users often need to interact with PostgreSQL.

## Access PostgreSQL

### Command-line access

GDK uses the PostgreSQL binaries installed on your system (see [install](../index.md) section),
but keeps the data files within the GDK directory structure, under `gitlab-development-kit/postgresql/data`.

This means that the databases cannot be seen with `psql -l`, but you can use the `gdk psql` wrapper
to access the GDK databases:

```shell
# Connect to the default gitlabhq_development database
gdk psql

# List all databases
gdk psql -l

# Connect to a different database
gdk psql -d gitlabhq_test

# Show all options
gdk psql --help
```

You can also use the Rails `dbconsole` command, but it's much slower to start up:

```shell
cd gitlab-development-kit/gitlab

# Use default development environment
bundle exec rails dbconsole

# Use a different Rails environment
bundle exec rails dbconsole -e test
```

### GUI access

To access the database using an [GUI SQL client](https://wiki.postgresql.org/wiki/PostgreSQL_Clients) provide the following:

- Host Name (path to data file): for example, `gitlab-development-kit/postgresql`.
- Database port: for example, `5432`.
- Database name: for example, `gitlabhq_development` or `gitlabhq_test`.
- Username and Password should be left blank

The CLI client is more capable. Not all GUI clients support a blank username or the use of a local file as the host name.

## Upgrade PostgreSQL

There are two ways to upgrade PostgreSQL:

1. [Run the upgrade script](#run-the-upgrade-script)
1. [Dump and restore](#dump-and-restore)

macOS users with Homebrew may find it easiest to use the first approach
since there is a convenient script that makes upgrading a single-line
command. Use the second approach if you are not using macOS or the
script fails for some reason.

## Run the upgrade script

For [systems that support simple installation](../index.md), there is a convenient script that
automatically runs `pg_upgrade` with the correct parameters:

```shell
support/upgrade-postgresql
```

This script attempts to:

1. Find both the current and target PostgreSQL binaries.
1. Initialize a new `data` directory for the target PostgreSQL version.
1. Upgrade the current `postgresql/data` directory.
1. Back up the original `postgresql/data` directory.
1. Promote the newly-upgraded `data` for the target PostgreSQL version by
   renaming this directory to `postgresql/data`.

## Dump and restore

If the upgrade script does not work, you can also dump the current
contents of the PostgreSQL database and restore it to the new database
verson:

1. (Optional) To retain the current database contents, create a backup of the database:

   ```shell
   # cd into your gitlab-development-kit directory
   cd gitlab-development-kit

   # Start the GDK database
   gdk start db

   # Create a backup of the current contents of the GDK database
   pg_dumpall -l gitlabhq_development -h "$PWD/postgresql"  -p 5432 > db_backup

   gdk stop db
   ```

1. Remove the current PostgreSQL `data` folder:

   ```shell
   # Backup the current data folder
   mv postgresql/data postgresql/data.bkp
   ```

1. Upgrade your PostgreSQL installation to a newer version. For example, to upgrade to
   PostgreSQL 12 on macOS using Homebrew:

   ```shell
   brew install postgresql@12
   ```

   If you are using [`asdf`](https://github.com/asdf-vm/asdf), the GDK [.tool-versions](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/.tool-versions) file includes required PostgreSQL versions and can be installed by running:

   ```shell
   asdf install
   ```

1. Initialize a new data folder with the new version of PostgreSQL by running `make`:

   ```shell
   make postgresql/data
   ```

1. Restore the backup:

   ```shell
   # Start the database.
   gdk start db

   # Restore the contents of the backup into the new database.
   gdk psql -d postgres -f db_backup
   ```

Your GDK should now be ready to use.

## Access Geo Secondary Database

```shell
# Connect to the default gitlabhq_geo_development database
gdk psql-geo

# List all databases
gdk psql-geo -l

# Connect to a different database
gdk psql-geo -d gitlabhq_geo_test

# Show all options
gdk psql-geo --help
```
