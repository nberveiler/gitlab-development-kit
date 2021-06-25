# Troubleshooting

Before attempting the specific troubleshooting steps documented below, many problems can be resolved
by:

- Running the following commands:

  ```shell
  cd <gdk-dir>/gitlab
  yarn install && bundle install
  bundle exec rails db:migrate RAILS_ENV=development
  ```

  This installs required Node.js modules and Ruby gems, and performs database migrations, which can
  fix errors caused by switching branches.

- [Updating GDK](index.md#update-gdk).

## Sections

GDK troubleshooting information is available for the following:

- [Ruby](#ruby)
- [Node.js](#nodejs)
- [PostgreSQL](#postgresql)
- [Git](#git)
- [Webpack](#webpack)
- [Running tests](#running-tests)
- [Puma](#puma)
- [Sidekiq Cluster](#sidekiq-cluster)
- [Jaeger](#jaeger)
- [Gitaly](#gitaly)
- [Elasticsearch](#elasticsearch)
- [Homebrew](#homebrew)
- [Live reloading](#live-reloading)
- [Praefect](#praefect)

If you can't solve your problem, or if you have a problem in another area, open an
issue on the [GDK issue tracker](https://gitlab.com/gitlab-org/gitlab-development-kit/issues).

## Ruby

The following are possible solutions to problems you might encounter with Ruby and GDK.

### Rebuilding gems with native extensions

There may be times when local libraries that are used to build some gems'
native extensions are updated (for example, `libicu`), thus resulting in errors like:

```shell
rails-background-jobs.1 | /home/user/.rvm/gems/ruby-2.3.0/gems/activesupport-4.2.5.2/lib/active_support/dependencies.rb:274:in 'require': libicudata.so
cannot open shared object file: No such file or directory - /home/user/.rvm/gems/ruby-2.3.0/gems/charlock_holmes-0.7.3/lib/charlock_holmes/charlock_holmes.so (LoadError)
```

```shell
cd /home/user/gitlab-development-kit/gitlab && bundle exec rake gettext:compile > /home/user/gitlab-development-kit/gitlab/log/gettext.log 2>&1
make: *** [.gettext] Error 1
```

```shell
rake aborted!
LoadError: dlopen(/home/user/.rbenv/versions/2.6.3/lib/ruby/gems/2.5.0/gems/charlock_holmes-0.7.6/lib/charlock_holmes/charlock_holmes.bundle, 9): Library not loaded: /usr/local/opt/icu4c/lib/libicudata.63.1.dylib
  Referenced from: /home/user/.rbenv/versions/2.6.3/lib/ruby/gems/2.5.0/gems/charlock_holmes-0.7.6/lib/charlock_holmes/charlock_holmes.bundle
  Reason: image not found - /home/user/.rbenv/versions/2.6.3/lib/ruby/gems/2.5.0/gems/charlock_holmes-0.7.6/lib/charlock_holmes/charlock_holmes.bundle
```

In that case, find the offending gem and use `pristine` to rebuild its native
extensions:

```shell
gem pristine charlock_holmes
```

Or for example `re2` on MacOS:

```shell
/Users/user/gitlab-development-kit/gitlab/lib/gitlab/untrusted_regexp.rb:25:  [BUG] Segmentation fault at 0x0000000000000000
ruby 2.6.6p146 (2020-03-31 revision 67876) [x86_64-darwin19]
```

In which case you would run:

```shell
gem pristine re2
```

### An error occurred while installing thin (1.7.2) on macOS

```plaintext
[SNIPPED]

thin.c:338:8: error: implicit declaration of function 'thin_http_parser_has_error' is invalid in C99 [-Werror,-Wimplicit-function-declaration]
    if(thin_http_parser_has_error(http)) {
       ^
thin.c:338:8: note: did you mean 'http_parser_has_error'?
./parser.h:44:5: note: 'http_parser_has_error' declared here
int http_parser_has_error(http_parser *parser);
    ^
thin.c:359:10: error: implicit declaration of function 'thin_http_parser_has_error' is invalid in C99 [-Werror,-Wimplicit-function-declaration]
  return thin_http_parser_has_error(http) ? Qtrue : Qfalse;
         ^
thin.c:374:10: error: implicit declaration of function 'thin_http_parser_is_finished' is invalid in C99 [-Werror,-Wimplicit-function-declaration]
  return thin_http_parser_is_finished(http) ? Qtrue : Qfalse;
         ^
9 errors generated.
make: *** [thin.o] Error 1

make failed, exit code 2

Gem files will remain installed in /Users/tkuah/.rbenv/versions/2.7.2/lib/ruby/gems/2.7.0/gems/thin-1.7.2 for inspection.
Results logged to /Users/tkuah/.rbenv/versions/2.7.2/lib/ruby/gems/2.7.0/extensions/x86_64-darwin-19/2.7.0/thin-1.7.2/gem_make.out

An error occurred while installing thin (1.7.2), and Bundler cannot continue.
Make sure that `gem install thin -v '1.7.2' --source 'https://rubygems.org/'` succeeds before bundling.
```

To fix this, you can run the following in the `gitlab` directory:

```shell
bundle config build.thin --with-cflags="-Wno-error=implicit-function-declaration"
bundle install
```

See this [issue](https://github.com/macournoyer/thin/pull/364) for more details.

### An error occurred while installing `gpgme` on macOS

Check if you have `gawk` installed >= 5.0.0 and uninstall it.

Re-run the `gdk install` again and follow any on-screen instructions related to installing `gpgme`.

### `charlock_holmes` `0.7.5` cannot be installed with icu4c 61.1

The installation of the `charlock_holmes` v0.7.5 gem during `bundle install`
may fail with the following error:

```plaintext
[SNIPPED]

transliterator.cpp:108:3: error: no template named 'StringByteSink'; did you mean 'icu_61::StringByteSink'?
  StringByteSink<std::string> sink(&result);
  ^~~~~~~~~~~~~~
  icu_61::StringByteSink
/usr/local/include/unicode/bytestream.h:232:7: note: 'icu_61::StringByteSink' declared here
class StringByteSink : public ByteSink {
    ^
transliterator.cpp:106:34: warning: implicit conversion loses integer precision: 'size_t' (aka 'unsigned long') to 'int32_t' (aka 'int') [-Wshorten-64-to-32]
  u_txt = new UnicodeString(txt, txt_len);
            ~~~~~~~~~~~~~      ^~~~~~~
1 warning and 9 errors generated.
make: *** [transliterator.o] Error 1
```

To fix this, you can run:

```shell
gem install charlock_holmes -v '0.7.5' -- --with-cppflags=-DU_USING_ICU_NAMESPACE=1
```

0.7.6 fixes this issue. See [this issue](https://github.com/brianmario/charlock_holmes/issues/126) for more details.

### undefined symbol: SSLv2_method

This happens if your local OpenSSL library is updated and your Ruby binary is
built against an older version.

If you are using `rvm`, you should reinstall the Ruby binary. The following
command fetches Ruby 2.3 and installs it from source:

```shell
rvm reinstall --disable-binary 2.3
```

### 'gem install nokogiri' fails

Make sure that Xcode Command Line Tools installed on your development machine. For the discussion see
this [issue](https://gitlab.com/gitlab-org/gitlab-development-kit/issues/124).

```shell
brew unlink gcc-4.2      # you might not need this step
gem uninstall nokogiri
xcode-select --install
gem install nokogiri
```

### `gem install gpgme` `2.0.x` fails to compile native extension on macOS Mojave

If building `gpgme` gem fails with an `Undefined symbols for architecture x86_64` error on macOS Mojave, build `gpgme` using system libraries instead.

1. Ensure necessary dependencies are installed:

   ```shell
   brew install gpgme
   ```

1. (optional) Try building the `gpgme` gem manually to ensure it compiles. If it fails, debug the failure with the error messages. To compile the `gpgme` gem manually run:

   ```shell
   gem install gpgme -- --use-system-libraries
   ```

1. Configure Bundler to use system libraries for the `gpgme` gem:

   ```shell
   bundle config build.gpgme --use-system-libraries
   ```

You can now run `gdk install` or `bundle` again.

### `gem install nokogumbo` fails

If you see the following error installing the `nokogumbo` gem via `gdk install`:

```shell

Running 'configure' for libxml2 2.9.9... OK
Running 'compile' for libxml2 2.9.9... ERROR, review
...
sed -e
's?\@XML_LIBDIR\@?-L/Users/erick/Development/gitlab-development-kit/gitlab/-?/gems/nokogiri-1.10.4/ports/x86_64-apple-darwin18.7.0/libxml2/2.9.9/lib?g'
\
-e
's?\@XML_INCLUDEDIR\@?-I/Users/erick/Development/gitlab-development-kit/gitlab/-?/gems/nokogiri-1.10.4/ports/x86_64-apple-darwin18.7.0/libxml2/2.9.9/include/libxml2?g'
\
        -e 's?\@VERSION\@?2.9.9?g' \
        -e 's?\@XML_LIBS\@?-lxml2 -lz -L/usr/local/Cellar/xz/5.2.4/lib -llzma -lpthread  -liconv  -lm ?g' \
           < ./xml2Conf.sh.in > xml2Conf.tmp \
    && mv xml2Conf.tmp xml2Conf.sh
sed: 1: "s?\@XML_LIBDIR\@?-L/Use ...": bad flag in substitute command: '/'
make[3]: *** [xml2Conf.sh] Error 1
make[2]: *** [all-recursive] Error 1
make[1]: *** [all] Error 2
...
An error occurred while installing nokogumbo (1.5.0), and Bundler cannot continue.
Make sure that `gem install nokogumbo -v '1.5.0' --source 'https://rubygems.org/'` succeeds before bundling.

In Gemfile:
  sanitize was resolved to 4.6.6, which depends on
    nokogumbo
make: *** [.gitlab-bundle] Error 5
```

A solution is to:

1. Instruct Bundler to use the system libraries when building `nokogumbo`:

   ```shell
   bundle config build.nokogumbo --use-system-libraries
   ```

1. Re-run `gdk install`

### FFI gem issues

The following are problems you might encounter when installing the
[FFI gem](https://github.com/ffi/ffi/wiki) with possible solutions.

### `gem install ffi` fails with '`ffi.h` file not found'

If you see the following error installing the `ffi` gem via `gdk install`:

```shell
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.
...
sed: 1: "s?\@XML_LIBDIR\@?-L/Use ...": bad flag in substitute command: '/'
...
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.
...
An error occurred while installing nokogiri (1.10.4), and Bundler cannot continue.
Make sure that `gem install nokogiri -v '1.10.4' --source 'https://rubygems.org/'` succeeds before bundling.
...
compiling AbstractMemory.c
In file included from AbstractMemory.c:47:
In file included from ./AbstractMemory.h:42:
./Types.h:78:10: fatal error: 'ffi.h' file not found
#include <ffi.h>
        ^~~~~~~
1 error generated.
make[1]: *** [AbstractMemory.o] Error 1
...
An error occurred while installing ffi (1.11.1), and Bundler cannot continue.
Make sure that `gem install ffi -v '1.11.1' --source 'https://rubygems.org/'` succeeds before bundling.
```

A solution on macOS is to:

1. Ensure the `PKG_CONFIG_PATH` and `LDFLAGS` environment variables are correctly set:

   ```shell
   export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$(brew --prefix)/opt/libffi/lib/pkgconfig"
   export LDFLAGS="$LDFLAGS:-L$(brew --prefix)/opt/libffi/lib"
   ```

1. Re-run `gdk install`

### `gem install ffi` fails with 'error: implicit declaration of function'

```shell
Installing ffi 1.13.1 with native extensions
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.

current directory:
/Users/gdk/.rbenv/versions/2.6.6/lib/ruby/gems/2.6.0/gems/ffi-1.13.1/ext/ffi_c
-- snip --
compiling Function.c
Function.c:852:17: error: implicit declaration of function
'ffi_prep_closure_loc' is invalid in C99
[-Werror,-Wimplicit-function-declaration]
ffiStatus = ffi_prep_closure_loc(code, &fnInfo->ffi_cif, callback_invoke,
closure, code);
                ^
Function.c:852:17: note: did you mean 'ffi_prep_closure'?
/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include/ffi/ffi.h:269:1:
note: 'ffi_prep_closure' declared here
ffi_prep_closure(
^
1 error generated.
make[2]: *** [Function.o] Error 1

make failed, exit code 2

Gem files will remain installed in
/Users/gdk/.rbenv/versions/2.6.6/lib/ruby/gems/2.6.0/gems/ffi-1.13.1 for
inspection.
Results logged to
/Users/gdk/.rbenv/versions/2.6.6/lib/ruby/gems/2.6.0/extensions/x86_64-darwin-18/2.6.0/ffi-1.13.1/gem_make.out

An error occurred while installing ffi (1.13.1), and Bundler cannot continue.
Make sure that `gem install ffi -v '1.13.1' --source 'https://rubygems.org/'`
succeeds before bundling.

In Gemfile:
  rbtrace was resolved to 0.4.14, which depends on
    ffi
make[1]: *** [/Users/gdk/code/ee-gdk/gitaly/.ruby-bundle] Error 5
make: *** [gitaly/bin/gitaly] Error 2
```

A solution on macOS is to re-install [Xcode Command Line Tools](https://apple.stackexchange.com/questions/93573/how-to-reinstall-xcode-command-line-tools).

### LoadError due to readline

On macOS, GitLab may fail to start and fail with an error message about
`libreadline`:

```plaintext
LoadError:
    dlopen(/Users/gdk/.rbenv/versions/2.6.3/lib/ruby/2.5.0/x86_64-darwin15/readline.bundle, 9): Library not loaded: /usr/local/opt/readline/lib/libreadline.7.dylib
        Referenced from: /Users/gdk/.rbenv/versions/2.6.3/lib/ruby/2.5.0/x86_64-darwin15/readline.bundle
        Reason: image not found - /Users/gdk/.rbenv/versions/2.6.3/lib/ruby/2.5.0/x86_64-darwin15/readline.bundle
```

This happens because the Ruby interpreter was linked with a version of
the `readline` library that may have been updated on your system. To fix
the error, reinstall the Ruby interpreter. For example, for environments
managed with:

- [rbenv](https://github.com/rbenv/rbenv), run `rbenv install 2.7.2`.
- [RVM](https://rvm.io), run `rvm reinstall ruby-2.7.2`.

### 'LoadError: dlopen' when starting Ruby apps

This can happen when you try to load a Ruby gem with native extensions that
were linked against a system library that is no longer there. A typical culprit
is Homebrew on macOS, which encourages frequent updates (`brew update && brew
upgrade`) which may break binary compatibility.

```shell
bundle exec rake db:create dev:setup
rake aborted!
LoadError: dlopen(/Users/gdk/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle, 9): Library not loaded: /usr/local/opt/icu4c/lib/libicui18n.52.1.dylib
  Referenced from: /Users/gdk/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle
  Reason: image not found - /Users/gdk/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle
/Users/gdk/gitlab-development-kit/gitlab/config/application.rb:6:in `<top (required)>'
/Users/gdk/gitlab-development-kit/gitlab/Rakefile:5:in `require'
/Users/gdk/gitlab-development-kit/gitlab/Rakefile:5:in `<top (required)>'
(See full trace by running task with --trace)
```

In the above example, you see that the charlock_holmes gem fails to load
`libicui18n.52.1.dylib`. You can try fixing this by [re-installing
charlock_holmes](#rebuilding-gems-with-native-extensions).

### 'bundle install' fails due to permission problems

This can happen if you are using a system-wide Ruby installation. You can
override the Ruby gem install path with `BUNDLE_PATH`:

```shell
# Install gems in (current directory)/vendor/bundle
make BUNDLE_PATH=$(pwd)/vendor/bundle
```

### 'bundle install' fails while compiling eventmachine gem

On OS X El Capitan, the eventmachine gem compilation might fail with:

```plaintext
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.
<snip>
make "DESTDIR=" clean

make "DESTDIR="
compiling binder.cpp
In file included from binder.cpp:20:
./project.h:116:10: fatal error: 'openssl/ssl.h' file not found
#include <openssl/ssl.h>
        ^
1 error generated.
make: *** [binder.o] Error 1

make failed, exit code 2
```

To fix it:

```shell
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

and then do `bundle install` once again.

### Bootsnap-related problems

If your local instance does not start up and you see `bootsnap` errors like this:

```plaintext
2020-07-09_07:29:27.20103 rails-web             : .rvm/gems/ruby-2.6.6/gems/bootsnap-1.4.6/lib/bootsnap/load_path_cache/core_ext/active_support.rb:61:in `block in load_missing_constant': uninitialized constant EE::OperationsHelper (NameError)
2020-07-09_07:29:27.20104 rails-web             : .rvm/gems/ruby-2.6.6/gems/bootsnap-1.4.6/lib/bootsnap/load_path_cache/core_ext/active_support.rb:17:in `allow_bootsnap_retry'
```

You should remove the `bootsnap` cache:

```shell
gdk stop
rm -rf gitlab/tmp/cache/bootsnap-*
gdk start
```

## Node.js

The following are possible solutions to problems you might encounter with Node.js and GDK.

### Error installing node-gyp

node-gyp may fail to build on macOS Catalina installations. Follow [the node-gyp troubleshooting guide](https://github.com/nodejs/node-gyp/blob/master/macOS_Catalina.md).

### 'yarn install' fails due node incompatibility issues

If you're running a version of node between 13.0 and 13.7, you might see the following error message:

```plaintext
error extract-files@8.1.0: The engine "node" is incompatible with this module. Expected version "10 - 12 || >= 13.7". Got "13.2.0"
error Found incompatible module.
```

If you're using `nvm`, you can confirm the version of node that you're using:

```shell
nvm current node -v
```

You can adjust node to an acceptable version with the following command:

```shell
nvm install <version>
```

### yarn: error: no such option: --pure-lockfile

The full error you might be getting is:

```plaintext
Makefile:134: recipe for target '.gitlab-yarn' failed
make: *** [.gitlab-yarn] Error 2
```

This is likely to happen if you installed `yarn` using `apt install cmdtest`.

To fix this, install yarn using npm instead:

```shell
npm install --global yarn
```

## PostgreSQL

The following are possible solutions to problems you might encounter with PostgreSQL and GDK.

### Unable to build and install `pg` gem on GDK install

After installing PostgreSQL with brew, you have to set the proper path to PostgreSQL.
You may run into the following errors on running `gdk install`

```plaintext
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.

    current directory: /Users/gdk/.rvm/gems/ruby-2.3.3/gems/pg-0.18.4/ext
/Users/gdk/.rvm/rubies/ruby-2.3.3/bin/ruby -r ./siteconf20180330-95521-1k5x76v.rb extconf.rb
checking for pg_config... no
No pg_config... trying anyway. If building fails, please try again with
 --with-pg-config=/path/to/pg_config

 ...

An error occurred while installing pg (0.18.4), and Bundler cannot continue.
Make sure that `gem install pg -v '0.18.4'` succeeds before bundling.
```

This is because the script fails to find the PostgreSQL instance in the path.
The instructions for this may show up after installing PostgreSQL.
The example below is from running `brew install postgresql@11` on a macOS installation.
For other versions, other platform install and other shell terminal please adjust the path accordingly.

```plaintext
If you need to have this software first in your PATH run:
  echo 'export PATH="/usr/local/opt/postgresql@11/bin:$PATH"' >> ~/.bash_profile
```

Once this is set, run the `gdk install` command again.

### Error in database migrations when pg_trgm extension is missing

Since GitLab 8.6+ the PostgreSQL extension `pg_trgm` must be installed. If you
are installing GDK for the first time this is handled automatically from the
database schema. In case you are updating your GDK and you experience this
error, make sure you pull the latest changes from the GDK repository and run:

```shell
./support/enable-postgres-extensions
```

### PostgreSQL is looking for wrong version of icu4c

If the Rails server cannot connect to PostgreSQL and you see the following when running `gdk tail postgresql`:

```plaintext
2020-07-06_00:26:20.51557 postgresql            : support/postgresql-signal-wrapper:16:in `<main>': undefined method `exitstatus' for nil:NilClass (NoMethodError)
2020-07-06_00:26:21.62892 postgresql            : dyld: Library not loaded: /usr/local/opt/icu4c/lib/libicui18n.66.dylib
2020-07-06_00:26:21.62896 postgresql            :   Referenced from: /usr/local/opt/postgresql@11/bin/postgres
2020-07-06_00:26:21.62897 postgresql            :   Reason: image not found
```

This means the PostgreSQL is trying to load an older version of `icu4c` (`66` in the example), and failing.
This can happen when `icu4c` is not pinned and is upgraded beyond the version supported
by PostgreSQL.

To resolve this, reinstall PostgreSQL with:

```shell
brew reinstall postgresql@11
```

### ActiveRecord::PendingMigrationError at /

After running the GitLab Development Kit using `gdk start` and browsing to `http://localhost:3000/`, you may see an error page that says `ActiveRecord::PendingMigrationError at /. Migrations are pending`.

To fix this error, the pending migration must be resolved. Perform the following steps in your terminal:

1. Change to the `gitlab` directory using `cd gitlab`
1. Run the following command to perform the migration: `rails db:migrate RAILS_ENV=development`

Once the operation is complete, refresh the page.

### Database files incompatible with server

If you see `FATAL: database files are incompatible with server` errors, it means
the PostgreSQL data directory was initialized by an old PostgreSQL version, which
is not compatible with your current PostgreSQL version.

You can solve it in one of two ways, depending if you would like to retain your data or not:

### If you do not need to retain your data

Note that this wipes out the existing contents of your database.

```shell
# cd into your GDK folder
cd gitlab-development-kit

# Remove your existing data
mv postgresql/data postgresql/data.bkp

# Initialize a new data folder
make postgresql/data

# Initialize the gitlabhq_development database
gdk reconfigure

# Start your database.
gdk start db
```

You may remove the `data.bkp` folder if your database is working well.

### If you would like to retain your data

Check the version of PostgreSQL that your data is compatible with:

```shell
# cd into your GDK folder
cd gitlab-development-kit

cat postgresql/data/PG_VERSION
```

If the content of the `PG_VERSION` file is `10`, your data folder is compatible
with PostgreSQL 10.

Downgrade your PostgreSQL to the compatible version. For example, to downgrade to
PostgreSQL 10 on macOS using Homebrew:

```shell
brew install postgresql@10
brew link --force postgresql@10
```

You also need to update your `Procfile` to use the downgraded PostgreSQL binaries:

```shell
# Change Procfile to use downgraded PostgreSQL binaries
gdk reconfigure
```

You can now follow the steps described in [Upgrade PostgreSQL](howto/postgresql.md#upgrade-postgresql)
to upgrade your PostgreSQL version while retaining your current data.

### Rails cannot connect to PostgreSQL

- Use `gdk status` to see if `postgresql` is running.
- Check for custom PostgreSQL connection settings defined via the environment; we
  assume none such variables are set. Look for them with `set | grep '^PG'`.

### Fix conflicts in database migrations if you use the same db for CE and EE

NOTE:
The recommended way to fix the problem is to rebuild your database and move
your EE development into a new directory.

In case you use the same database for both CE and EE development, sometimes you
can get stuck in a situation when the migration is up in `rake db:migrate:status`,
but in reality the database doesn't have it.

For example, <https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/3186>
introduced some changes when a few EE migrations were added to CE. If you were
using the same db for CE and EE you would get hit by the following error:

```shell
undefined method `share_with_group_lock' for #<Group
```

This exception happened because the system thinks that such migration was
already run, and thus Rails skipped adding the `share_with_group_lock` field to
the `namespaces` table.

The problem is that you can not run `rake db:migrate:up VERSION=xxx` since the
system thinks the migration is already run. Also, you can not run
`rake db:migrate:redo VERSION=xxx` since it tries to do `down` before `up`,
which fails if column does not exist or can cause data loss if column exists.

A quick solution is to remove the database data and then recreate it:

```shell
bundle exec rake setup
```

---

If you don't want to nuke the database, you can perform the migrations manually.
Open a terminal and start the rails console:

```shell
rails console
```

And run manually the migrations:

```plaintext
require Rails.root.join("db/migrate/20130711063759_create_project_group_links.rb")
CreateProjectGroupLinks.new.change
require Rails.root.join("db/migrate/20130820102832_add_access_to_project_group_link.rb")
AddAccessToProjectGroupLink.new.change
require Rails.root.join("db/migrate/20150930110012_add_group_share_lock.rb")
AddGroupShareLock.new.change
```

You should now be able to continue your development. You might want to note
that in this case we had 3 migrations happening:

```plaintext
db/migrate/20130711063759_create_project_group_links.rb
db/migrate/20130820102832_add_access_to_project_group_link.rb
db/migrate/20150930110012_add_group_share_lock.rb
```

In general it doesn't matter in which order you run them, but in this case
the last two migrations create columns in a table which is created by the first
migration. So, in this example the order is important. Otherwise you would try
to create a column in a non-existent table which would of course fail.

### Delete non-existent migrations from the database

If for some reason you end up having database migrations that no longer exist
but are present in your database, you might want to remove them.

1. Find the non-existent migrations with `rake db:migrate:status`. You should
   see some entries like:

   ```plaintext
   up     20160727191041  ********** NO FILE **********
   up     20160727193336  ********** NO FILE **********
   ```

1. Open a rails database console with `rails dbconsole`.
1. Delete the migrations you want with:

   ```sql
   DELETE FROM schema_migrations WHERE version='20160727191041';
   ```

You can now run `rake db:migrate:status` again to verify that the entries are
deleted from the database.

## Git

The following are possible solutions to problems you might encounter with Git and GDK.

### 'Invalid reference name' when creating a new tag

Make sure that `git` is configured correctly on your development
machine (where GDK runs).

```shell
git checkout -b can-I-commit
git commit --allow-empty -m 'I can commit'
```

### `fatal: not a git repository`

If any `gdk` command gives you the following error:

```plaintext
fatal: not a git repository (or any of the parent directories): .git
```

Make sure you don't have `gdk` aliased in your shell.
For example the Git module in [prezto](https://github.com/sorin-ionescu/prezto)
has an [alias](https://github.com/sorin-ionescu/prezto/blob/master/modules/git/README.md#data)
for `gdk` that lists killed files.

## Webpack

Since webpack has been added as a new background process which GitLab depends on
in development, the [GDK must be updated and reconfigured](index.md#update-gdk) in
order to work properly again.

If you still encounter some errors, see the troubleshooting FAQ below:

- I'm getting an error when I run `gdk reconfigure`:

  ```plaintext
  Makefile:30: recipe for target 'gitlab/config/gitlab.yml' failed
  make: *** [gitlab/config/gitlab.yml] Error 1
  ```

  This is likely because you have not updated your GitLab CE/EE repository to
  the latest default branch yet. It has a template for `gitlab.yml` in it which
  the GDK needs to update. The `gdk update` step should have taken care of this
  for you, but you can also manually go to your GitLab directory and run
  `git checkout main && git pull origin main`

    ---

- I'm getting an error when I attempt to access my local GitLab in a browser:

  ```plaintext
  Webpack::Rails::Manifest::ManifestLoadError at /
  Could not load manifest from webpack-dev-server at http://localhost:3808/assets/webpack/manifest.json - is it running, and is stats-webpack-plugin loaded?
  ```

  or

  ```plaintext
  Webpack::Rails::Manifest::ManifestLoadError at /
  Could not load compiled manifest from /path/to/gitlab-development-kit/gitlab/public/assets/webpack/manifest.json - have you run `rake webpack:compile`?
  ```

  This probably means that the webpack dev server isn't running or that your
  `gitlab.yml` isn't properly configured. Ensure that you have run
  `gdk reconfigure` **AND** `gdk restart webpack`.

  ---

- I see the following error when run `gdk tail` or `gdk tail webpack`:

  ```plaintext
  09:46:05 webpack.1               | npm ERR! argv "/usr/local/bin/node" "/usr/local/bin/npm" "run" "dev-server"
  09:46:05 webpack.1               | npm ERR! node v5.8.0
  09:46:05 webpack.1               | npm ERR! npm  v3.10.7
  09:46:05 webpack.1               |
  09:46:05 webpack.1               | npm ERR! missing script: dev-server
  ...
  ```

  This means your GitLab CE or EE instance is not running the current default
  branch. If you are running a branch which hasn't been rebased against the
  default branch since Saturday, Feb 4th then you should rebase it against the
  default branch. If you are running the default branch, ensure it is up to date
  with `git pull`.

  ---

- I see the following error when run `gdk tail` or `gdk tail webpack`:

  ```plaintext
  09:54:15 webpack.1               | > @ dev-server /Users/mike/Projects/gitlab-development-kit/gitlab
  09:54:15 webpack.1               | > webpack-dev-server --config config/webpack.config.js
  09:54:15 webpack.1               |
  09:54:15 webpack.1               | sh: webpack-dev-server: command not found
  09:54:15 webpack.1               |
  ...
  ```

  This means you have not run `yarn install` since updating your `gitlab/gitlab-foss`
  repository. The `gdk update` command should have done this for you, but you
  can do so manually as well.

- I see the following error when run `gdk tail` or `gdk tail webpack`:

  ```plaintext
  14:52:22 webpack.1               | [nodemon] starting `node ./node_modules/.bin/webpack-dev-server --config config/webpack.config.js`
  14:52:22 webpack.1               | events.js:160
  14:52:22 webpack.1               |       throw er; // Unhandled 'error' event
  14:52:22 webpack.1               |       ^
  14:52:22 webpack.1               |
  14:52:22 webpack.1               | Error: listen EADDRINUSE 127.0.0.1:3808
  ...
  ```

  This means the port is already in use, probably because webpack failed to
  terminate correctly when the GDK was last shutdown. You can find out the pid
  of the process using the port with the command `lsof -i :3808`. If you are
  using Vagrant the `lsof` command is not available. Instead you can use the
  command `ss -pntl 'sport = :3808'`. The left over process can be killed with
  the command `kill PID`.

## Running tests

There may be times when running spinach feature tests or Ruby Capybara RSpec
tests (tests that are located in the `spec/features` directory) fails.

### ChromeDriver problems

ChromeDriver is the app on your machine that is used to run headless
browser tests.

If you see this error in your test output (you may need to scroll up): `Selenium::WebDriver::Error::SessionNotCreatedError`
coupled with the error message: `This version of ChromeDriver only supports Chrome version [...]`,
you need to update your version of ChromeDriver:

- If you installed ChromeDriver with Homebrew, then you can update by running:

  ```shell
  brew upgrade --cask chromedriver
  ```

- Otherwise you may need to [download and install](https://sites.google.com/a/chromium.org/chromedriver/downloads)
  the latest ChromeDriver directly.

If ChromeDriver fails to open with an error message because the developer "cannot be verified",
create an exception for it as documented in the [macOS documentation](https://support.apple.com/en-gb/guide/mac-help/mh40616/mac).

### Database problems

Another issue can be that your test environment's database schema has
diverged from what the GitLab app expects. This can happen if you tested
a branch locally that changed the database in some way, and have now
switched back to `main` without
[rolling back](https://edgeguides.rubyonrails.org/active_record_migrations.html#rolling-back)
the migrations locally first.

In that case, what you need to do is run the following command inside
the `gitlab` directory to drop all tables on your test database and have
them recreated from the canonical version in `db/structure.sql`. Note,
dropping and recreating your test database tables is perfectly safe!

```shell
cd gitlab
bundle exec rake db:test:prepare
```

### Failures when generating Karma fixtures

In some cases, running `bin/rake karma:fixtures` might fail to generate some fixtures. You can see errors in the console like these:

```plaintext
Failed examples:

rspec ./spec/javascripts/fixtures/blob.rb:25 # Projects::BlobController (JavaScript fixtures) blob/show.html
rspec ./spec/javascripts/fixtures/branches.rb:24 # Projects::BranchesController (JavaScript fixtures) branches/new_branch.html
rspec ./spec/javascripts/fixtures/commit.rb:22 # Projects::CommitController (JavaScript fixtures) commit/show.html
```

To fix this, remove `tmp/tests/` in the `gitlab/` directory and regenerate the fixtures:

```shell
rm -rf tmp/tests/ && bin/rake karma:fixtures
```

### TaskFailedError while setting up Gitaly

If you receive the error below, ensure that you don't have
`GIT_TEMPLATE_DIR="$(overcommit --template-dir)"`
[configured](https://github.com/sds/overcommit#automatically-install-overcommit-hooks).

```plaintext
==> Setting up Gitaly...
rake aborted!
Gitlab::TaskFailedError: Cloning into 'tmp/tests/gitaly'...
This repository contains hooks installed by Overcommit, but the `overcommit` gem is not installed.
Install it with `gem install overcommit`.
```

## Puma

The following are possible solutions to problems you might encounter with Puma and GDK.

### Puma timeout

Browser shows `EOF`. Logs show a timeout:

```plaintext
error: GET "/users/sign_in": badgateway: failed after 62s: EOF
```

Depending on the performance of your development environment, Puma may
time out. Increase the timeout as a workaround.

Use environment variables to override the default timeout:

Variable | Type | Description
-------- | ---- | -----------
`GITLAB_RAILS_RACK_TIMEOUT` | integer | Sets `service_timeout`
`GITLAB_RAILS_WAIT_TIMEOUT` | integer | Sets `wait_timeout`

## Sidekiq Cluster

GDK uses Sidekiq Cluster (running a single Sidekiq process) by default instead
`bundle exec sidekiq` directly, which is a step towards making development a
bit more like production.

Technically, running Sidekiq Cluster with a single Sidekiq process matches the same behavior
of running Sidekiq directly, but eventually problems may arise.

If you're experiencing performance issues or jobs not being picked up, try disabling
Sidekiq Cluster by:

1. Stopping all running processes with `gdk stop`.
1. Opening the `$GDKROOT/Procfile` file.
1. Removing the `SIDEKIQ_WORKERS` environment variable from `rails-background-jobs`.
1. Starting GDK again with `gdk start`.

When doing so, please create an issue describing what happened.

## Jaeger

If you're seeing errors such as:

```shell
ERROR -- : Failure while sending a batch of spans: Failed to open TCP connection to localhost:14268 (Connection refused - connect(2) for "localhost" port 14268)
```

This is most likely because Jaeger is not configured in your `$GDKROOT/Procfile`.
The easiest way to fix this is by re-creating your `Procfile` and then running
a `gdk reconfigure`:

1. `mv Procfile Procfile.old; make Procfile`
1. `gdk reconfigure`

For more information about Jaeger, visit the [distributed tracing GitLab developer
documentation](https://docs.gitlab.com/ee/development/distributed_tracing.html).

## Gitaly

The following are possible solutions to problems you might encounter with Gitaly and GDK.

### `config.toml: no such file or directory`

If you see errors such as:

```shell
07:23:16 gitaly.1                | time="2019-05-17T07:23:16-05:00" level=fatal msg="load config" config_path=<path-to-gdk>/gitaly/gitaly.config.toml error="open <path-to-gdk>/gitaly/gitaly.config.toml: no such file or directory"
```

Somehow, `gitaly/gitaly.config.toml` is missing. You can re-create this file by running
the following in your GDK directory:

```shell
make gitaly-setup
```

### Git fails to compile within Gitaly project

If you see the following error when running a `gdk update`:

```shell
ld: library not found for -lgit2
```

A known fix is to clean your Go cache by running the following from the GDK's root
directory:

```shell
go clean -cache
rm -rf gitaly
```

Now rerun `gdk update`.

### `libegit2.a Error 129`

If you see the following error when running a `gdk install` or a `gdk update`:

```shell
make[1]: Entering directory '/home/user/gitlab-development-kit/gitaly; error: unknown option `initial-branch=master'
make[1]: *** [Makefile:424: /home/user/gitlab-development-kit/gitaly/_build/deps/libgit2/install/lib/libgit2.a] Error 129
```

Check which version of Git you're running with `git --version`, and compare it against
[GitLab requirements](https://docs.gitlab.com/ee/install/requirements.html#git-versions). You
might be running an unsupported version.

If the supported version is not available for you from pre-compiled packages, try following the
instructions for [Ubuntu/Debian](#ubuntudebian) or [Arch/Manjaro](#arch-and-manjaro-linux). If
that doesn't give you the supported version, you might need to [compile Git from source](https://docs.gitlab.com/ee/install/installation.html#git).

## Elasticsearch

Running a spec locally may give you something like the following:

```shell
rake aborted!
Gitlab::TaskFailedError: # pkg-config --cflags  -- icu-i18n icu-i18n
Package icu-i18n was not found in the pkg-config search path.
Perhaps you should add the directory containing `icu-i18n.pc'
to the PKG_CONFIG_PATH environment variable
No package 'icu-i18n' found
Package icu-i18n was not found in the pkg-config search path.
Perhaps you should add the directory containing `icu-i18n.pc'
to the PKG_CONFIG_PATH environment variable
No package 'icu-i18n' found
pkg-config: exit status 1
make: *** [build] Error 2
```

This indicates that Go is trying to link (unsuccessfully) to brew's `icu4c`.

Find the directory where `icu-i18n.pc` resides:

- On macOS, using [Homebrew](https://brew.sh/), it is generally in `/usr/local/opt/icu4c/lib/pkgconfig`
- On Ubuntu/Debian it might be in `/usr/lib/x86_64-linux-gnu/pkgconfig`
- On Fedora it is expected to be in `/usr/lib64/pkgconfig`

You need to add that directory to the `PKG_CONFIG_PATH` environment variable.

To fix this now, run the following on the command line:

```shell
export PKG_CONFIG_PATH="/usr/local/opt/icu4c/lib/pkgconfig:$PKG_CONFIG_PATH"
```

To fix this for the future, add the line above to `~/.bash_profile` or `~/.zshrc`.

### Elasticsearch indexer looks for the wrong version of icu4c

You might get the following error when updating the application:

```plaintext
# gitlab.com/gitlab-org/gitlab-elasticsearch-indexer
/usr/local/Cellar/go/1.14.2_1/libexec/pkg/tool/darwin_amd64/link: running clang failed: exit status 1
ld: warning: directory not found for option '-L/usr/local/Cellar/icu4c/64.2/lib'
ld: library not found for -licui18n
clang: error: linker command failed with exit code 1 (use -v to see invocation)

make[1]: *** [build] Error 2
make: *** [gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer] Error 2
```

This means Go is trying to link to brew's version of `icu4c` (`64.2` in the example), and failing.
This can happen when `icu4c` is not pinned and got updated. Verify the version with:

```shell
$ ls /usr/local/Cellar/icu4c
66.1
```

Clean Go's cache to fix this error. From the GDK's root directory:

```shell
cd gitlab-elasticsearch-indexer/
go clean -cache
```

## Homebrew

Most `brew` problems can be figured out by running:

```shell
brew doctor
```

However, older installations may have significant cruft leftover from previous
installations and updates. To manually remove outdated downloads for all
formulae, casks, and stale lockfiles, run:

```shell
brew cleanup
```

For more information on uninstalling old versions of a formula, see the [Homebrew FAQ](https://docs.brew.sh/FAQ#how-do-i-uninstall-old-versions-of-a-formula).
For additional troubleshooting information, see the Homebrew [Common Issues](https://docs.brew.sh/Common-Issues) page.

## Live reloading

If you previously compiled production assets with `bundle exec rake gitlab:assets:compile`, the GDK
serves the assets from the `public/assets/` directory, which means that changing SCSS files doesn't
have any effect in development until you recompile the assets manually.

To re-enable live reloading of CSS in development, remove the `public/assets/` directory and restart
GDK.

## Praefect

### get shard for "default": primary is not healthy

From the GDK's root directory:

```shell
cd gitaly/ruby
bundle install
```

You may need to run a `gdk restart` for the changes to take effect.
