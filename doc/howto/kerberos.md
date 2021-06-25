# Kerberos

In order to test the [Kerberos integration](https://docs.gitlab.com/ee/integration/kerberos.html)
using GDK, set up a local Kerberos server.

## Requirements

These instructions require:

- [Docker](https://docs.docker.com/get-docker/).
- [Docker Compose](https://docs.docker.com/compose/install/).

## Set up integration with GDK

1. Change into the `kerberos/` directory:

   ```shell
   cd kerberos
   ```

1. Run `docker-compose up`. This builds a Docker image and starts a container
   with a Kerberos KDC for `GDK.TEST` realm listening on port `1088`.
1. Copy the `http.keytab` generated in the container to the host system:

   ```shell
   docker cp $(docker-compose ps -qa krb5):/etc/http.keytab .
   ```

   This keytab is then used by GitLab to authenticate Kerberos users.
1. Ensure `http.keytab` is readable only by the user of your GDK.

   Example (`git` as the GDK user):

   ```shell
   chown $(whoami) http.keytab
   chmod 0600 http.keytab
   ```

1. Configure `config/gitlab.yml` following the instructions from Kerberos
   integration [documentation](https://docs.gitlab.com/ee/integration/kerberos.html).
   The `keytab` option should point to where `http.keytab` exists.
1. Restart GDK: `gdk restart`.

## Add a user principal

1. Access the KDC shell and enter `kadmin`:

   ```shell
   docker-compose exec krb5 bash
   kadmin.local
   ```

1. Create user principal to link to a GitLab user account:

   ```shell
   addprinc <GitLab username>
   ```

   You are asked to enter and re-enter password.
1. Create an identity for a user you want to associate with the user principal
   via Rails console.

   ```shell
   Identity.create(user: User.find_by(username: 'user'), extern_uid: 'user@GDK.TEST', provider: 'kerberos')
   ```

## Authenticate with Kerberos

To be able to get a Kerberos ticket, configure the client so it can find the
appropriate KDC for a specific realm.

1. Open `/etc/hosts` and add the following:

   ```plaintext
   127.0.0.1 krb5.gdk.test
   ```

1. Open `/etc/krb5.conf` and add the following under `[realms]`:

   ```plaintext
   GDK.TEST = {
       kdc = tcp/krb5.gdk.test:1088
   }
   ```

   This configures the Kerberos client so it can connect with the KDC for
   `GDK.TEST` realm on port `1088`.

1. Run `kinit` to get a ticket:

   ```shell
   kinit user@GDK.TEST
   ```

   You are asked to enter the password set for the specified user principal.

1. Confirm that you got a ticket by running `klist`. You should see something like:

   ```shell
   $ klist
   Credentials cache: API:ABCDEFGH-1234-ABCD-1234-ABCDEFGHIJKL
           Principal: user@GDK.TEST

     Issued                Expires               Principal
   Nov  6 18:13:08 2020  Nov  7 04:13:05 2020  krbtgt/GDK.TEST@GDK.TEST
   ```

1. Test that you can clone a repository without any credentials:

   ```shell
   git clone http://:@gdk.test:3000/root/gitlab.git
   ```

   If you encounter a `HTTP Basic: Access denied` error, configure `git` to set
   `http.emptyAuth` to `true`.
