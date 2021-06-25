# Alternative GDK installation methods

In addition to the [primary GDK installation process](index.md#install-gdk), you can install GDK
using alternative methods.

## Install GDK to alternative platforms

Instead of installing GDK locally, you can install GDK to other platforms.

### Vagrant install

You can install GDK under a
[virtualized environment using Vagrant with Virtualbox or Docker](howto/vagrant.md).

### Minikube install

You can also install GDK on [Minikube](https://github.com/kubernetes/minikube);
see [Kubernetes docs](howto/kubernetes/minikube.md).

### Gitpod integration

Alternatively, you can use [GDK with Gitpod](howto/gitpod.md) to run a pre-configured GDK instance in the cloud.

## Install GDK using alternative projects

Instead of installing GDK from the default GitLab project, you can install GDK from other GitLab
projects.

### Install using GitLab FOSS project

> Learn [how to create a fork](https://docs.gitlab.com/ee/user/project/repository/forking_workflow.html#creating-a-fork)
> of [GitLab FOSS](https://gitlab.com/gitlab-org/gitlab-foss).

After cloning the `gitlab-development-kit` project and running `make bootstrap`, to:

- Clone `gitlab-foss` using SSH, run:

  ```shell
  gdk install gitlab_repo=git@gitlab.com:gitlab-org/gitlab-foss.git
  ```

- Clone `gitlab-foss` using HTTPS, run:

  ```shell
  gdk install gitlab_repo=https://gitlab.com/gitlab-org/gitlab-foss.git
  ```

Use `gdk install shallow_clone=true` for a faster clone that consumes less disk
space. The clone process uses [`git clone --depth=1`](https://www.git-scm.com/docs/git-clone#Documentation/git-clone.txt---depthltdepthgt).

### Install using your own GitLab fork

> Learn [how to create a fork](https://docs.gitlab.com/ee/user/project/repository/forking_workflow.html#creating-a-fork)
> of [GitLab FOSS](https://gitlab.com/gitlab-org/gitlab-foss).

After cloning the `gitlab-development-kit` project and running `make bootstrap`, to:

- Clone `gitlab-foss` using SSH, run:

  ```shell
  gdk install gitlab_repo=git@gitlab.com:gitlab-org/gitlab-foss.git
  ```

- Clone `gitlab-foss` using HTTPS, run:

  ```shell
  gdk install gitlab_repo=https://gitlab.com/gitlab-org/gitlab-foss.git
  ```

Use `gdk install shallow_clone=true` for a faster clone that consumes less disk
space. The clone process uses [`git clone --depth=1`](https://www.git-scm.com/docs/git-clone#Documentation/git-clone.txt---depthltdepthgt).
