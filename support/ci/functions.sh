# shellcheck shell=bash

GDK_CHECKOUT_PATH="$(pwd)/gitlab-development-kit"

init() {
  install_gem
  git clone https://gitlab.com/gitlab-org/gitlab-development-kit.git "${GDK_CHECKOUT_PATH}"
  # TODO: Touching .gdk-install-root will be redundant shortly.
  echo "${GDK_CHECKOUT_PATH}" > "${GDK_CHECKOUT_PATH}/.gdk-install-root"
}

install_gem() {
  cd gem || exit
  gem build gitlab-development-kit.gemspec
  gem install gitlab-development-kit-*.gem
}

test_gem() {
  gdk
}

checkout() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  # $CI_MERGE_REQUEST_SOURCE_PROJECT_URL only exists in pipelines generated in merge requests.
  if [ -n "${CI_MERGE_REQUEST_SOURCE_PROJECT_URL}" ]; then
    git remote set-url origin "${CI_MERGE_REQUEST_SOURCE_PROJECT_URL}.git"
  fi
  git fetch
  git checkout "${1}"
}

set_gitlab_upstream() {
  cd gitlab || exit

  local remote_name
  local default_branch

  remote_name="upstream"
  default_branch="master"

  if git remote | grep -Eq "^${remote_name}$"; then
    echo "Remote ${remote_name} already exists in $(pwd)."
    return
  fi

  git remote add "${remote_name}" "https://gitlab.com/gitlab-org/gitlab.git"

  git remote set-url --push "${remote_name}" none # make 'upstream' fetch-only
  echo "Fetching ${default_branch} from ${remote_name}..."

  GIT_CURL_VERBOSE=1 git fetch "${remote_name}" ${default_branch}

  # check if the default branch already exists
  if git show-ref --verify --quiet refs/heads/${default_branch}; then
    git branch --set-upstream-to="${remote_name}/${default_branch}" ${default_branch}
  else
    git branch ${default_branch} "${remote_name}/${default_branch}"
  fi
}

install() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  echo "> Installing GDK.."
  gdk install
  test_gem
  set_gitlab_upstream
}

update() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  echo "> Updating GDK.."
  # we use `make update` instead of `gdk update` to ensure the working directory
  # is not reset to the default branch.
  make update
  set_gitlab_upstream
  restart
}

start() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  echo "> Starting up GDK.."
  gdk start
}

stop() {
  gdk stop || true
}

restart() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  echo "> Restarting GDK.."
  stop_start

  echo "> Upgrading PostgreSQL data directory if necessary.."
  support/upgrade-postgresql

  echo "> Restarting GDK.."
  stop_start
}

stop_start() {
  stop

  gdk status || true
   # shellcheck disable=SC2009
  ps -ef | grep "[r]unsv"
  gdk start
}

doctor() {
  cd "${GDK_CHECKOUT_PATH}" || exit
  echo "> Running gdk doctor.."
  gdk doctor
}

wait_for_boot() {
  echo "> Waiting 90 secs to give GDK a chance to boot up.."
  sleep 90
}
