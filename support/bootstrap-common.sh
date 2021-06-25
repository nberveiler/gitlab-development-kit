# shellcheck shell=bash

root_path="$(cd "$(dirname "$0")/.." || exit ; pwd -P)"

CURRENT_ASDF_DIR="${ASDF_DIR:-${HOME}/.asdf}"
CURRENT_ASDF_DATA_DIR="${ASDF_DATA_DIR:-${HOME}/.asdf}"

export PATH="${CURRENT_ASDF_DIR}/bin:${CURRENT_ASDF_DATA_DIR}/shims:${PATH}"

CPU_TYPE=$(arch -arm64 uname -m 2> /dev/null || uname -m)

# Add supported linux platform IDs extracted from /etc/os-release into the
# appropriate varible variables below. SUPPORTED_PLATFORMS ends up containing
# all supported platforms and is displayed to the user if their platform is not
# supported, so you can format the ID to be 'Ubuntu' instead of 'ubuntu'
# (which is how ID appears in /etc/os-release) so it's rendered nicely to the
# user. When comparing the user's platform ID against SUPPORTED_PLATFORMS, we
# ensure the check is not case sensitive which means we get the best of both
# worlds.
#
SUPPORTED_UBUNTU_LIKE_PLATFORMS=('Ubuntu Pop neon')
SUPPORTED_DEBIAN_LIKE_PLATFORMS=('Debian PureOS')
SUPPORTED_ARCH_LIKE_PLATFORMS=('Arch Manjaro')
SUPPORTED_FEDORA_LIKE_PLATFORMS=('Fedora RHEL')
SUPPORTED_OTHER_PLATFORMS=('macOS')

SUPPORTED_PLATFORMS=("${SUPPORTED_OTHER_PLATFORMS[@]}" "${SUPPORTED_UBUNTU_LIKE_PLATFORMS[@]}" "${SUPPORTED_DEBIAN_LIKE_PLATFORMS[@]}" "${SUPPORTED_ARCH_LIKE_PLATFORMS[@]}" "${SUPPORTED_FEDORA_LIKE_PLATFORMS[@]}")

GDK_CACHE_DIR="${root_path}/.cache"
GDK_PLATFORM_SETUP_FILE="${GDK_CACHE_DIR}/.gdk_platform_setup"

error() {
  echo
  echo "ERROR: ${1}" >&2
  exit 1
}

echo_if_unsuccessful() {
  output="$("${@}" 2>&1)"

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]] ; then
    echo "${output}" >&2
    return 1
  fi
}

asdf_reshim() {
  asdf reshim
}

prefix_with_asdf_if_available() {
  local command

  command="${*}"

  if asdf version > /dev/null 2>&1; then
    eval "asdf exec ${command}"
  else
    eval "${command}"
  fi
}

ruby_required_bundler_versions() {
  find . -type f -name Gemfile.lock -exec awk '/BUNDLED WITH/{getline;print $NF;}' {} + 2> /dev/null | sort -r | uniq

  return 0
}

ruby_install_required_bundlers() {
  local required_versions

  required_versions=$(ruby_required_bundler_versions)

  for version in ${required_versions}
  do
    if ! bundle "_${version}_" --version > /dev/null 2>&1; then
      prefix_with_asdf_if_available gem install bundler -v "=${version}"
    fi
  done
}

gdk_install_gem() {
  if ! echo_if_unsuccessful ruby_install_required_bundlers; then
    return 1
  fi

  if ! echo_if_unsuccessful prefix_with_asdf_if_available gem install gitlab-development-kit; then
    return 1
  fi

  return 0
}

ruby_configure_opts() {
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    brew_openssl_dir=$(brew --prefix openssl)
    brew_readline_dir=$(brew --prefix readline)

    echo "RUBY_CONFIGURE_OPTS=\"--with-openssl-dir=${brew_openssl_dir} --with-readline-dir=${brew_readline_dir}\""
  fi

  return 0
}

configure_ruby_bundler() {
  local current_postgres_version
  current_postgres_version=$(asdf current postgres | awk '{ print $2 }')

  bundle config build.pg "--with-pg-config=${CURRENT_ASDF_DATA_DIR}/installs/postgres/${current_postgres_version}/bin/pg_config"
  bundle config build.thin --with-cflags="-Wno-error=implicit-function-declaration"
}

ensure_sudo_available() {
  if [ -z "$(command -v sudo)" ]; then
    echo "ERROR: sudo command not found!" >&2
    return 1
  fi

  return 0
}

ensure_not_root() {
  if [[ ${EUID} -eq 0 ]]; then
    return 1
  fi

  return 0
}

ensure_supported_platform() {
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    if [[ "${CPU_TYPE}" == "arm64" ]]; then
      echo "INFO:" >&2
      echo "INFO: GDK currently runs on Apple Silicon hardware using Rosetta 2." >&2
      echo "INFO:" >&2
      echo "INFO: To see the latest on running the GDK natively on Apple Silicon, visit:" >&2
      echo "INFO: https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues/1159" >&2
      echo "INFO:" >&2
      echo "INFO: To learn more about Rosetta 2, visit:" >&2
      echo "INFO: https://en.wikipedia.org/wiki/Rosetta_(software)#Rosetta_2" >&2
      echo "INFO:" >&2
      echo "INFO: Resuming in 3 seconds.." >&2

      sleep 3
    fi

    return 0
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    shopt -s nocasematch

    os_id=$(awk -F= '$1=="ID" { gsub(/"/, "", $2); print $2 ;}' /etc/os-release)

    if [[ ${SUPPORTED_PLATFORMS[*]} =~ ${os_id} ]]; then
      shopt -u nocasematch
      return 0
    fi
  fi

  shopt -u nocasematch

  return 1
}

common_preflight_checks() {
  echo "INFO: Performing common preflight checks.."

  if ! ensure_supported_platform; then
    echo
    echo "ERROR: Unsupported platform. The list of supported platforms are:" >&2
    echo "INFO:" >&2
    for platform in "${SUPPORTED_PLATFORMS[@]}"; do
      echo "INFO: - $platform" >&2
    done
    echo "INFO:" >&2
    echo "INFO: If you want to add your platform to this list, you're welcome to edit bootstrap-common.sh and open a merge request or open an issue in the GDK project." >&2
    echo "INFO:" >&2
    echo "INFO: Please visit https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/advanced.md to bootstrap manually." >&2
    return 1
  fi

  if ! ensure_not_root; then
    error "Running as root is not supported."
  fi

  if ! ensure_sudo_available; then
    error "sudo is required, please install." >&2
  fi
}

setup_platform() {
  if platform_files_checksum_matches; then
    echo "INFO: This GDK has already had platform packages installed."
    echo "INFO: Remove '${GDK_PLATFORM_SETUP_FILE}' to force execution."

    return 0
  fi

  if [[ "${OSTYPE}" == "darwin"* ]]; then
    if setup_platform_darwin; then
      mark_platform_as_setup "Brewfile"
    else
      return 1
    fi
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    os_id=$(awk -F= '$1=="ID" { gsub(/"/, "", $2); print $2 ;}' /etc/os-release)

    shopt -s nocasematch

    if [[ ${SUPPORTED_UBUNTU_LIKE_PLATFORMS[*]} =~ ${os_id} ]]; then
      if setup_platform_linux_with "packages_ubuntu.txt"; then
        mark_platform_as_setup "packages_ubuntu.txt"
      else
        shopt -u nocasematch
        return 1
      fi
    elif [[ ${SUPPORTED_DEBIAN_LIKE_PLATFORMS[*]} =~ ${os_id} ]]; then
      if setup_platform_linux_with "packages_debian.txt"; then
        mark_platform_as_setup "packages_debian.txt"
      else
        shopt -u nocasematch
        return 1
      fi
    elif [[ ${SUPPORTED_ARCH_LIKE_PLATFORMS[*]} =~ ${os_id} ]]; then
      if setup_platform_linux_arch_like_with "packages_arch.txt"; then
        mark_platform_as_setup "packages_arch.txt"
      else
        shopt -u nocasematch
        return 1
      fi
    elif [[ ${SUPPORTED_FEDORA_LIKE_PLATFORMS[*]} =~ ${os_id} ]]; then
      if setup_platform_linux_fedora_like_with "packages_fedora.txt"; then
        mark_platform_as_setup "packages_fedora.txt"
      else
        shopt -u nocasematch
        return 1
      fi
    fi
    shopt -u nocasematch
  fi
}

platform_files_checksum_matches() {
  if [[ ! -f "${GDK_PLATFORM_SETUP_FILE}" ]]; then
    return 1
  fi

  sha256sum --check --status "${GDK_PLATFORM_SETUP_FILE}"
}

mark_platform_as_setup() {
  local platform_file="${1}"

  mkdir -p "${GDK_CACHE_DIR}"
  sha256sum "${platform_file}" > "${GDK_PLATFORM_SETUP_FILE}"
}

setup_platform_linux_with() {
  if ! echo_if_unsuccessful sudo apt-get update; then
    return 1
  fi

  # shellcheck disable=SC2046
  if ! sudo apt-get install -y $(sed -e 's/#.*//' "${1}"); then
    return 1
  fi

  return 0
}

setup_platform_linux_arch_like_with() {
  if ! echo_if_unsuccessful sudo pacman -Syy; then
    return 1
  fi

  # shellcheck disable=SC2046
  if ! sudo pacman -S --needed --noconfirm $(sed -e 's/#.*//' "${1}"); then
    return 1
  fi

  # Check for runit, which needs to be manually installed from AUR.
  if ! echo_if_unsuccessful which runit; then
    cd /tmp || return 1
    git clone --depth 1 https://aur.archlinux.org/runit-systemd.git
    cd runit-systemd || return 1
    makepkg -sri --noconfirm
  fi

  return 0
}

setup_platform_linux_fedora_like_with() {
  if ! echo_if_unsuccessful sudo dnf module enable postgresql:12 -y; then
    return 1
  fi

  # shellcheck disable=SC2046
  if ! sudo dnf install -y $(sed -e 's/#.*//' "${1}" | tr '\n' ' '); then
    return 1
  fi

  if ! echo_if_unsuccessful which runit; then
    echo "INFO: Installing runit into /opt/runit/"
    cd /tmp || return 1
    wget http://smarden.org/runit/runit-2.1.2.tar.gz
    tar xzf runit-2.1.2.tar.gz
    cd admin/runit-2.1.2 || return 1
    sed -i -E 's/ -static$//g' src/Makefile || return 1
    ./package/compile || return 1
    ./package/check || return 1
    sudo mkdir -p /opt/runit || return 1
    sudo mv command/* /opt/runit || return 1
    sudo ln -s /opt/runit/* /usr/local/bin/ || return 1
  fi

  return 0
}

setup_platform_darwin() {
  local shell_file ruby_configure_opts brew_opts

  if [ -z "$(command -v brew)" ]; then
    echo "INFO: Installing Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi

  if ! brew tap homebrew/cask; then
    return 1
  fi

  # Support running brew under Rosetta 2 on Apple M1 machines
  if [[ "${CPU_TYPE}" == "arm64" ]]; then
    brew_opts="arch -x86_64"
  else
    brew_opts=""
  fi

  if ! ${brew_opts} brew bundle; then
    return 1
  fi

  if ! echo_if_unsuccessful brew link pkg-config; then
    return 1
  fi

  case $SHELL in
  */zsh)
    shell_file="${HOME}/.zshrc"
    ;;
  *)
    shell_file="${HOME}/.bashrc"
    ;;
  esac

  icu4c_pkgconfig_path="export PKG_CONFIG_PATH=\"/usr/local/opt/icu4c/lib/pkgconfig:\${PKG_CONFIG_PATH}\""
  if ! grep -Fxq "${icu4c_pkgconfig_path}" "${shell_file}" 2> /dev/null; then
    echo -e "\n# Added by GDK bootstrap\n${icu4c_pkgconfig_path}" >> "${shell_file}"
  fi

  ruby_configure_opts="export $(ruby_configure_opts)"
  if ! grep -Fxq "${ruby_configure_opts}" "${shell_file}" 2> /dev/null; then
    echo -e "\n# Added by GDK bootstrap\n${ruby_configure_opts}" >> "${shell_file}"
  fi

  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    if ! brew list --cask google-chrome > /dev/null 2>&1; then
      if ! ${brew_opts} brew install google-chrome; then
        return 1
      fi
    fi
  fi
}
