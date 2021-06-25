FROM ubuntu:20.04
LABEL authors.maintainer "GDK contributors: https://gitlab.com/gitlab-org/gitlab-development-kit/-/graphs/main"

## We are building this docker file with an experimental --squash in order
## to reduce the resulting layer size: https://docs.docker.com/engine/reference/commandline/build/#squash-an-images-layers---squash-experimental
##
## The CI script that build this file can be found under: support/docker

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

RUN apt-get update && apt-get install -y sudo locales locales-all software-properties-common \
    && add-apt-repository ppa:git-core/ppa -y

RUN useradd --user-group --create-home --groups sudo gdk
RUN echo "gdk ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/gdk_no_password

WORKDIR /home/gdk/gitlab-development-kit
RUN chown gdk:gdk /home/gdk/gitlab-development-kit

USER gdk
COPY --chown=gdk . .

ENV PATH="/home/gdk/.asdf/shims:/home/gdk/.asdf/bin:${PATH}"

RUN bash ./support/bootstrap \
  # simple tests that tools work
  && bash -lec "asdf version; yarn --version; node --version; ruby --version" \
  # Remove unneeded packages
  && sudo apt-get purge software-properties-common -y \
  && sudo apt-get autoremove -y \
  # clear tmp caches e.g. from postgres compilation
  && sudo rm -rf /tmp/* ~/.asdf/tmp/* \
  # Remove files we copied in
  && sudo rm -rf .cache .gdk-install-root .tool-versions packages*.txt support/
