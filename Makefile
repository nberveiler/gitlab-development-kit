.NOTPARALLEL:

START_TIME := $(shell date "+%s")

DIVIDER = "--------------------------------------------------------------------------------"

SHELL = /bin/bash
ASDF := $(shell command -v asdf 2> /dev/null)
RAKE := $(shell command -v rake 2> /dev/null)
BUNDLE := $(shell command -v bundle 2> /dev/null)
GOLANG := $(shell command -v go 2> /dev/null)
YARN := $(shell command -v yarn 2> /dev/null)

MARKDOWNLINT := $(shell command -v markdownlint 2> /dev/null)
RUBOCOP := $(shell command -v rubocop 2> /dev/null)
RSPEC := $(shell command -v rspec 2> /dev/null)

# Speed up Go module downloads
export GOPROXY ?= https://proxy.golang.org

# Silence Rollup when building GitLab Docs with nanoc
export ROLLUP_OPTIONS = --silent

NO_RUBY_REQUIRED := bootstrap lint

# Generate a Makefile from Ruby and include it
ifdef RAKE
ifeq (,$(filter $(NO_RUBY_REQUIRED), $(MAKECMDGOALS)))
include $(shell rake gdk-config.mk)
endif
endif

ifeq ($(platform),darwin)
OPENSSL_PREFIX := $(shell brew --prefix openssl)
OPENSSL := ${OPENSSL_PREFIX}/bin/openssl
else
OPENSSL := $(shell command -v openssl 2> /dev/null)
endif

gitlab_clone_dir = gitlab
gitlab_shell_clone_dir = gitlab-shell
gitaly_clone_dir = gitaly
gitlab_docs_clone_dir = gitlab-docs
gitlab_runner_clone_dir = gitlab-runner
omnibus_gitlab_clone_dir = omnibus-gitlab
charts_gitlab_clone_dir = charts-gitlab
gitlab_pages_clone_dir = gitlab-pages
gitlab_k8s_agent_clone_dir = gitlab-k8s-agent
gitlab_ui_clone_dir = gitlab-ui

gitlab_shell_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITLAB_SHELL_VERSION")
gitaly_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITALY_SERVER_VERSION")
pages_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITLAB_PAGES_VERSION")
gitlab_k8s_agent_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITLAB_KAS_VERSION")
gitlab_elasticsearch_indexer_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITLAB_ELASTICSEARCH_INDEXER_VERSION")

quiet_bundle_flag = $(shell ${gdk_quiet} && echo "--quiet")
bundle_without_production_cmd = ${BUNDLE} config set without 'production'
bundle_install_cmd = ${BUNDLE} install --jobs 4 ${quiet_bundle_flag} ${BUNDLE_ARGS}
in_gitlab = cd $(gitlab_development_root)/$(gitlab_clone_dir) &&
gitlab_rake_cmd = $(in_gitlab) ${BUNDLE} exec rake
gitlab_git_cmd = git -C $(gitlab_development_root)/$(gitlab_clone_dir)
nanoc_cmd = ${BUNDLE} exec nanoc

psql := $(postgresql_bin_dir)/psql

# Borrowed from https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Makefile#n87
#
ifeq ($(gdk_debug),true)
	Q =
	QQ =
else
	Q = @
	QQ = > /dev/null
endif

QQerr = 2> /dev/null

ifeq ($(shallow_clone),true)
git_depth_param = --depth=1
endif

# This is used by `gdk install` and `gdk reconfigure`
#
.PHONY: all
all: preflight-checks \
gitlab-setup \
gitlab-shell-setup \
gitlab-workhorse-setup \
gitlab-pages-setup \
gitlab-k8s-agent-setup \
support-setup \
gitaly-setup \
geo-config \
prom-setup \
object-storage-setup \
gitlab-elasticsearch-indexer-setup \
grafana-setup \
gitlab-ui-setup \
gitlab-docs-setup

# This is used by `gdk install`
#
.PHONY: install
install: all show-installed-at start

# This is used by `gdk update`
#
# Pull gitlab directory first since dependencies are linked from there.
.PHONY: update
update: update-start \
preflight-checks \
preflight-update-checks \
asdf-update \
gitlab-git-pull \
ensure-databases-running \
unlock-dependency-installers \
gitlab-translations-unlock \
gitlab-shell-update \
gitlab-workhorse-update \
gitlab-pages-update \
gitlab-k8s-agent-update \
gitaly-update \
gitlab-update \
gitlab-elasticsearch-indexer-update \
object-storage-update \
jaeger-update \
grafana-update \
gitlab-ui-update \
gitlab-docs-update \
update-summarize

.PHONY: update-start
update-start:
	@support/dev/makefile-timeit start

.PHONY: update-summarize
update-summarize:
	@echo
	@echo "${DIVIDER}"
	@echo "Timings"
	@echo "${DIVIDER}"
	@echo
	@support/dev/makefile-timeit summarize
	@echo
	@echo "${DIVIDER}"
	@echo "Updated successfully as of $$(date +"%Y-%m-%d %T")"
	@echo "${DIVIDER}"

# This is used by `gdk reconfigure`
#
.PHONY: reconfigure
reconfigure: ensure-required-ruby-bundlers-installed \
touch-examples \
unlock-dependency-installers \
postgresql-sensible-defaults \
all \
show-reconfigured-at

.PHONY: clean
clean:
	@true

self-update: unlock-dependency-installers
	@echo
	@echo "${DIVIDER}"
	@echo "Running self-update on GDK"
	@echo "${DIVIDER}"
	$(Q)git stash ${QQ}
	$(Q)support/self-update-git-worktree ${QQ}

clean-config:
	$(Q)rm -rf \
	Procfile \
	gitaly/gitaly-*.praefect.toml \
	gitaly/gitaly.config.toml \
	gitaly/praefect.config.toml \
	gitlab-pages/gitlab-pages.conf \
	gitlab-runner-config.toml \
	gitlab-shell/.gitlab_shell_secret \
	gitlab-shell/config.yml \
	gitlab/workhorse/config.toml \
	gitlab/config/cable.yml \
	gitlab/config/database.yml \
	gitlab/config/database_geo.yml \
	gitlab/config/gitlab.yml \
	gitlab/config/puma.rb \
	gitlab/config/puma_actioncable.rb \
	gitlab/config/resque.yml \
	jaeger \
	localhost.crt \
	localhost.key \
	nginx/conf/nginx.conf \
	prometheus/prometheus.yml \
	redis/redis.conf \
	registry/config.yml \
	registry_host.crt \
	registry_host.key

touch-examples:
	$(Q)touch \
	gitlab-shell/config.yml.example \
	gitlab/workhorse/config.toml.example \
	gitlab/config/puma_actioncable.example.development.rb \
	$$(find support/templates -name "*.erb")

unlock-dependency-installers:
	$(Q)rm -f \
	.gitlab-bundle \
	.gitlab-shell-bundle \
	.gitlab-yarn \
	.gitlab-ui-yarn

gdk.yml:
	$(Q)touch $@

.PHONY: Procfile
Procfile:
	$(Q)rake $@

.PHONY: preflight-checks
preflight-checks: preflight-checks-timed

.PHONY: preflight-checks-run
preflight-checks-run: rake
	$(Q)rake preflight-checks

.PHONY: preflight-update-checks
preflight-update-checks: preflight-update-checks-timed

.PHONY: preflight-update-checks-run
preflight-update-checks-run: rake
	$(Q)rake preflight-update-checks

.PHONY: rake
rake:
	$(Q)command -v $@ ${QQ} || gem install $@

.PHONY: ensure-databases-running
ensure-databases-running: Procfile postgresql/data gitaly-setup
	@echo
	@echo "${DIVIDER}"
	@echo "Ensuring necessary data services are running"
	@echo "${DIVIDER}"
	$(Q)gdk start rails-migration-dependencies

.PHONY: ensure-required-ruby-bundlers-installed
ensure-required-ruby-bundlers-installed:
	@echo
	@echo "${DIVIDER}"
	@echo "Ensuring all required versions of bundler are installed"
	@echo "${DIVIDER}"
	${Q}. ./support/bootstrap-common.sh ; ruby_install_required_bundlers

##############################################################
# timing
##############################################################

.PHONY: %-timed
%-timed:
	@make $(*F)-timing-start $(*F)-run $(*F)-timing-end

.PHONY: %-timing-start
%-timing-start:
	@support/dev/makefile-timeit time-service-start $(*F)

.PHONY: %-timing-end
%-timing-end:
	@support/dev/makefile-timeit time-service-end $(*F)

##############################################################
# bootstrap
##############################################################

.PHONY: bootstrap
bootstrap:
	@support/bootstrap

.PHONY: bootstrap-packages
bootstrap-packages:
	@support/bootstrap-packages

##############################################################
# asdf
##############################################################

.PHONY: asdf-update
asdf-update: asdf-update-timed

.PHONY: asdf-update-run
asdf-update-run:
ifdef ASDF
ifeq ($(asdf_opt_out),false)
	@support/asdf-update
else
	$(Q)echo "INFO: asdf installed but asdf.opt_out is set to true"
	@true
endif
else
	@true
endif

##############################################################
# GitLab
##############################################################

gitlab-setup: gitlab/.git gitlab-config .gitlab-bundle .gitlab-yarn .gitlab-translations

.PHONY: gitlab-update
gitlab-update: gitlab-update-timed

.PHONY: gitlab-update-run
gitlab-update-run: ensure-databases-running postgresql gitlab-git-pull gitlab-setup gitlab-db-migrate gitlab/doc/api/graphql/reference/gitlab_schema.json

.PHONY: gitlab/git-restore
gitlab/git-restore:
	$(Q)$(gitlab_git_cmd) ls-tree HEAD --name-only -- Gemfile.lock db/structure.sql db/schema.rb ee/db/geo/schema.rb | xargs $(gitlab_git_cmd) checkout --

gitlab/doc/api/graphql/reference/gitlab_schema.json: .gitlab-bundle
	@echo
	@echo "${DIVIDER}"
	@echo "Generating gitlab GraphQL schema files"
	@echo "${DIVIDER}"
	$(Q)$(in_gitlab) bundle exec rake gitlab:graphql:schema:dump ${QQ}

.PHONY: gitlab-git-pull
gitlab-git-pull: gitlab-git-pull-timed

.PHONY: gitlab-git-pull-run
gitlab-git-pull-run: gitlab/.git/pull

gitlab/.git/pull: gitlab/git-restore
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab to current default branch"
	@echo "${DIVIDER}"
	$(Q)GIT_CURL_VERBOSE=${GIT_CURL_VERBOSE} support/component-git-update gitlab "${gitlab_clone_dir}" HEAD false ${QQ}

.PHONY: gitlab-db-migrate
gitlab-db-migrate: ensure-databases-running
	@echo
	$(Q)rake gitlab_rails:db:migrate

gitlab/.git:
	$(Q)git clone ${git_depth_param} ${gitlab_repo} ${gitlab_clone_dir} $(if $(realpath ${gitlab_repo}),--shared)

gitlab-config: gitlab/config/gitlab.yml gitlab/config/database.yml gitlab/config/cable.yml gitlab/config/resque.yml gitlab/public/uploads gitlab/config/puma.rb gitlab/config/puma_actioncable.rb

.PHONY: gitlab/config/gitlab.yml
gitlab/config/gitlab.yml:
	$(Q)rake $@

.PHONY: gitlab/config/database.yml
gitlab/config/database.yml:
	$(Q)rake $@

.PHONY: gitlab/config/puma.rb
gitlab/config/puma.rb:
	$(Q)rake $@

# Versions older than GitLab 12.9 won't have this file
gitlab/config/puma_actioncable.example.development.rb:
	$(Q)touch $@

gitlab/config/puma_actioncable.rb: gitlab/config/puma_actioncable.example.development.rb
	$(Q)support/safe-sed "$@" \
		-e "s|/home/git|${gitlab_development_root}|g" \
		"$<"

.PHONY: gitlab/config/cable.yml
gitlab/config/cable.yml:
	$(Q)rake $@

.PHONY: gitlab/config/resque.yml
gitlab/config/resque.yml:
	$(Q)rake $@

gitlab/public/uploads:
	$(Q)mkdir $@

.gitlab-bundle: ensure-required-ruby-bundlers-installed
	@echo
	@echo "${DIVIDER}"
	@echo "Installing gitlab-org/gitlab Ruby gems"
	@echo "${DIVIDER}"
	$(Q)$(in_gitlab) $(bundle_without_production_cmd) ${QQ}
	$(Q)$(in_gitlab) $(bundle_install_cmd)
	$(Q)touch $@

.gitlab-yarn:
	@echo
	@echo "${DIVIDER}"
	@echo "Installing gitlab-org/gitlab Node.js packages"
	@echo "${DIVIDER}"
	$(Q)$(in_gitlab) ${YARN} install --pure-lockfile ${QQ}
	$(Q)touch $@


.PHONY: gitlab-translations-unlock
gitlab-translations-unlock:
	$(Q)rm -f .gitlab-translations

.PHONY: gitlab-translations
gitlab-translations: gitlab-translations-timed

.PHONY: gitlab-translations-run
gitlab-translations-run: .gitlab-translations

.gitlab-translations:
	@echo
	@echo "${DIVIDER}"
	@echo "Generating gitlab-org/gitlab Rails translations"
	@echo "${DIVIDER}"
	$(Q)$(gitlab_rake_cmd) gettext:compile > ${gitlab_development_root}/gitlab/log/gettext.log
	$(Q)$(gitlab_git_cmd) checkout locale/*/gitlab.po
	$(Q)touch $@

##############################################################
# gitlab-shell
##############################################################

gitlab-shell-setup: ${gitlab_shell_clone_dir}/.git gitlab-shell/config.yml .gitlab-shell-bundle gitlab-shell/.gitlab_shell_secret openssh/ssh_host_rsa_key
	$(Q)make -C gitlab-shell build ${QQ}

.PHONY: gitlab-shell-update
gitlab-shell-update: gitlab-shell-update-timed

.PHONY: gitlab-shell-update-run
gitlab-shell-update-run: gitlab-shell-git-pull gitlab-shell-setup

.PHONY: gitlab-shell-git-pull
gitlab-shell-git-pull: gitlab-shell-git-pull-timed

.PHONY: gitlab-shell-git-pull-run
gitlab-shell-git-pull-run:
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-shell to ${gitlab_shell_version}"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_shell "${gitlab_development_root}/gitlab-shell" "${gitlab_shell_version}"

# This task is phony to allow
# support/move-existing-gitlab-shell-directory to remove the legacy
# symlink, if necessary. See https://gitlab.com/gitlab-org/gitlab-development-kit/-/merge_requests/1086
.PHONY: ${gitlab_shell_clone_dir}/.git
${gitlab_shell_clone_dir}/.git:
	$(Q)support/move-existing-gitlab-shell-directory || git clone --quiet --branch "${gitlab_shell_version}" ${git_depth_param} ${gitlab_shell_repo} ${gitlab_shell_clone_dir}

.PHONY: gitlab-shell/config.yml
gitlab-shell/config.yml: ${gitlab_shell_clone_dir}/.git
	$(Q)rake $@

.gitlab-shell-bundle:
	$(Q)cd ${gitlab_development_root}/gitlab-shell && $(bundle_install_cmd)
	$(Q)touch $@

gitlab-shell/.gitlab_shell_secret:
	$(Q)ln -nfs ${gitlab_development_root}/gitlab/.gitlab_shell_secret $@

##############################################################
# gitaly
##############################################################

gitaly-setup: ${gitaly_build_bin_dir}/gitaly ${gitaly_build_deps_dir}/git/install/bin/git gitaly/gitaly.config.toml gitaly/praefect.config.toml

${gitaly_clone_dir}/.git:
	$(Q)if [ -e gitaly ]; then mv gitaly .backups/$(shell date +gitaly.old.%Y-%m-%d_%H.%M.%S); fi
	$(Q)git clone --quiet ${gitaly_repo} ${gitaly_clone_dir}
	$(Q)support/component-git-update gitaly "${gitaly_clone_dir}" "${gitaly_version}" ${QQ}

.PHONY: gitaly-update
gitaly-update: gitaly-update-timed

.PHONY: gitaly-update-run
gitaly-update-run: gitaly-git-pull gitaly-clean gitaly-setup praefect-migrate

.PHONY: gitaly-git-pull
gitaly-git-pull: gitaly-git-pull-timed

.PHONY: gitaly-git-pull-run
gitaly-git-pull-run: ${gitaly_clone_dir}/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitaly to ${gitaly_version}"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitaly "${gitaly_clone_dir}" "${gitaly_version}" ${QQ}

gitaly-clean:
	$(Q)rm -rf gitlab/tmp/tests/gitaly

.PHONY: ${gitaly_build_bin_dir}/gitaly
${gitaly_build_bin_dir}/gitaly: ${gitaly_clone_dir}/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Building gitlab-org/gitaly ${gitaly_version}"
	@echo "${DIVIDER}"
	$(Q)$(MAKE) -C ${gitaly_clone_dir} BUNDLE_FLAGS=--no-deployment
	$(Q)cd ${gitlab_development_root}/gitaly/ruby && $(bundle_install_cmd)

.PHONY: ${gitaly_build_deps_dir}/git/install/bin/git
${gitaly_build_deps_dir}/git/install/bin/git:
	@echo
	@echo "${DIVIDER}"
	@echo "Building git for gitlab-org/gitaly"
	@echo "${DIVIDER}"
	$(Q)$(MAKE) -C ${gitaly_clone_dir} git

.PHONY: gitaly/gitaly.config.toml
gitaly/gitaly.config.toml:
	$(Q)rake $@

.PHONY: gitaly/praefect.config.toml
gitaly/praefect.config.toml:
	$(Q)rake $@

.PHONY: praefect-migrate
praefect-migrate: postgresql-seed-praefect
	$(Q)support/migrate-praefect

##############################################################
# GitLab Docs
##############################################################

ifeq ($(gitlab_docs_enabled),true)
gitlab-docs-setup: gitlab-docs/.git gitlab-runner omnibus-gitlab charts-gitlab gitlab-docs-deps
else
gitlab-docs-setup:
	@true
endif

ifeq ($(gitlab_runner_enabled),true)
gitlab-runner: gitlab-runner/.git
else
gitlab-runner:
	@true
endif

ifeq ($(gitlab_runner_enabled),true)
gitlab-runner-pull: gitlab-runner/.git/pull
else
gitlab-runner-pull:
	@true
endif

ifeq ($(omnibus_gitlab_enabled),true)
omnibus-gitlab: omnibus-gitlab/.git
else
omnibus-gitlab:
	@true
endif

ifeq ($(omnibus_gitlab_enabled),true)
omnibus-gitlab-pull: omnibus-gitlab/.git/pull
else
omnibus-gitlab-pull:
	@true
endif

ifeq ($(charts_gitlab_enabled),true)
charts-gitlab: charts-gitlab/.git
else
charts-gitlab:
	@true
endif

ifeq ($(charts_gitlab_enabled),true)
charts-gitlab-pull: charts-gitlab/.git/pull
else
charts-gitlab-pull:
	@true
endif

gitlab-docs/.git:
	$(Q)git clone ${git_depth_param} ${gitlab_docs_repo} gitlab-docs

gitlab-docs/.git/pull: gitlab-docs/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-docs to current default branch"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_docs "${gitlab_docs_clone_dir}" HEAD ${QQ}

gitlab-runner/.git:
	$(Q)git clone ${git_depth_param} ${gitlab_runner_repo} gitlab-runner

gitlab-runner/.git/pull: gitlab-runner/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-runner to current default branch"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_runner "${gitlab_runner_clone_dir}" HEAD ${QQ}

omnibus-gitlab/.git:
	$(Q)git clone ${git_depth_param} ${omnibus_gitlab_repo} omnibus-gitlab

omnibus-gitlab/.git/pull: omnibus-gitlab/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/omnibus-gitlab to current default branch"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update omnibus_gitlab "${omnibus_gitlab_clone_dir}" HEAD ${QQ}

charts-gitlab/.git:
	$(Q)git clone ${git_depth_param} ${charts_gitlab_repo} charts-gitlab

charts-gitlab/.git/pull: charts-gitlab/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/charts/gitlab to current default branch"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update charts_gitlab "${charts_gitlab_clone_dir}" HEAD ${QQ}

.PHONY: gitlab-docs-deps
gitlab-docs-deps: gitlab-docs-bundle gitlab-docs-yarn rm-symlink-gitlab-docs

gitlab-docs-bundle:
	$(Q)cd ${gitlab_development_root}/gitlab-docs && $(bundle_install_cmd)

gitlab-docs-yarn:
	$(Q)cd ${gitlab_development_root}/gitlab-docs && ${YARN} install --frozen-lockfile

# Ensure no legacy symlinks are in place
rm-symlink-gitlab-docs:
	$(Q)rm -f ${gitlab_development_root}/${gitlab_docs_clone_dir}/content/ee
	$(Q)rm -f ${gitlab_development_root}/${gitlab_docs_clone_dir}/content/runner
	$(Q)rm -f ${gitlab_development_root}/${gitlab_docs_clone_dir}/content/omnibus
	$(Q)rm -f ${gitlab_development_root}/${gitlab_docs_clone_dir}/content/charts

gitlab-docs-clean:
	$(Q)cd ${gitlab_development_root}/gitlab-docs && rm -rf tmp

gitlab-docs-build:
	$(Q)cd ${gitlab_development_root}/gitlab-docs && $(nanoc_cmd)

.PHONY: gitlab-docs-update
ifeq ($(gitlab_docs_enabled),true)
gitlab-docs-update: gitlab-docs-update-timed
else
gitlab-docs-update:
	@true
endif

.PHONY: gitlab-docs-update-run
gitlab-docs-update-run: gitlab-docs/.git/pull gitlab-runner-pull omnibus-gitlab-pull charts-gitlab-pull gitlab-docs-deps gitlab-docs-build

# Internal links and anchors checks for documentation
ifeq ($(gitlab_docs_enabled),true)
gitlab-docs-check: gitlab-runner-docs-check omnibus-gitlab-docs-check charts-gitlab-docs-check gitlab-docs-build
	$(Q)cd ${gitlab_development_root}/gitlab-docs && \
		$(nanoc_cmd) check internal_links && \
		$(nanoc_cmd) check internal_anchors
else
gitlab-docs-check:
	@echo "ERROR: gitlab_docs is not enabled. See doc/howto/gitlab_docs.md"
	@false
endif

ifneq ($(gitlab_runner_enabled),true)
gitlab-runner-docs-check:
	@echo "ERROR: gitlab_runner is not enabled. See doc/howto/gitlab_docs.md"
	@false
else
gitlab-runner-docs-check:
	@true
endif

ifneq ($(omnibus_gitlab_enabled),true)
omnibus-gitlab-docs-check:
	@echo "ERROR: omnibus_gitlab is not enabled. See doc/howto/gitlab_docs.md"
	@false
else
omnibus-gitlab-docs-check:
	@true
endif

ifneq ($(charts_gitlab_enabled),true)
charts-gitlab-docs-check:
	@echo "ERROR: charts_gitlab is not enabled. See doc/howto/gitlab_docs.md"
	@false
else
charts-gitlab-docs-check:
	@true
endif

##############################################################
# gitlab geo
##############################################################

.PHONY: geo-setup geo-cursor
geo-setup: geo-setup-check Procfile geo-cursor geo-config postgresql/geo

geo-setup-check:
ifneq ($(geo_enabled),true)
	$(Q)echo 'ERROR: geo.enabled is not set to true in your gdk.yml'
	@exit 1
else
	@true
endif

geo-config: gitlab/config/database_geo.yml postgresql/geo/port

geo-cursor:
	$(Q)grep '^geo-cursor:' Procfile || (printf ',s/^#geo-cursor/geo-cursor/\nwq\n' | ed -s Procfile)

.PHONY: gitlab/config/database_geo.yml
gitlab/config/database_geo.yml:
ifeq ($(geo_enabled),true)
	$(Q)rake $@
else
	@true
endif

.PHONY: geo-primary-migrate
geo-primary-migrate: geo-primary-migrate-timed

.PHONY: geo-primary-migrate-run
geo-primary-migrate-run: ensure-databases-running .gitlab-bundle gitlab-db-migrate gitlab/git-restore diff-config

.PHONY: geo-primary-update
geo-primary-update: update geo-primary-migrate diff-config

.PHONY: geo-secondary-migrate
geo-secondary-migrate: ensure-databases-running .gitlab-bundle gitlab-db-migrate gitlab/git-restore

.PHONY: geo-secondary-update
geo-secondary-update: geo-secondary-update-timed

.PHONY: geo-secondary-update-run
geo-secondary-update-run: update geo-secondary-migrate diff-config

.PHONY: diff-config
diff-config:
	$(Q)gdk $@

##############################################################
# gitlab-workhorse
##############################################################

gitlab-workhorse-setup: gitlab/workhorse/gitlab-workhorse gitlab/workhorse/config.toml

.PHONY: gitlab/workhorse/config.toml
gitlab/workhorse/config.toml:
	$(Q)rake $@

.PHONY: gitlab-workhorse-update
gitlab-workhorse-update: gitlab-workhorse-update-timed

.PHONY: gitlab-workhorse-run
gitlab-workhorse-update-run: gitlab-workhorse-clean-bin gitlab/workhorse/config.toml gitlab-workhorse-setup

.PHONY: gitlab-workhorse-compile
gitlab-workhorse-compile:
	@echo
	@echo "${DIVIDER}"
	@echo "Compiling gitlab/workhorse/gitlab-workhorse"
	@echo "${DIVIDER}"

gitlab-workhorse-clean-bin: gitlab-workhorse-compile
	$(Q)$(MAKE) -C gitlab/workhorse clean

.PHONY: gitlab/workhorse/gitlab-workhorse
gitlab/workhorse/gitlab-workhorse: gitlab-workhorse-compile
	$(Q)$(MAKE) -C gitlab/workhorse ${QQ}

##############################################################
# gitlab-elasticsearch
##############################################################

ifeq ($(gitlab_elasticsearch_indexer_enabled),true)
gitlab-elasticsearch-indexer-setup: gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer
else
gitlab-elasticsearch-indexer-setup:
	@true
endif

.PHONY: gitlab-elasticsearch-indexer-update
ifeq ($(gitlab_elasticsearch_indexer_enabled),true)
gitlab-elasticsearch-indexer-update: gitlab-elasticsearch-indexer-update-timed
else
gitlab-elasticsearch-indexer-update:
	@true
endif

.PHONY: gitlab-elasticsearch-indexer-update-run
gitlab-elasticsearch-indexer-update-run: gitlab-elasticsearch-indexer/.git/pull gitlab-elasticsearch-indexer-clean-bin gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer

gitlab-elasticsearch-indexer-clean-bin:
	$(Q)rm -rf gitlab-elasticsearch-indexer/bin

gitlab-elasticsearch-indexer/.git:
	$(Q)git clone --quiet --branch "${gitlab_elasticsearch_indexer_version}" ${git_depth_param} ${gitlab_elasticsearch_indexer_repo} gitlab-elasticsearch-indexer

.PHONY: gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer
gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer: gitlab-elasticsearch-indexer/.git
	$(Q)$(MAKE) -C gitlab-elasticsearch-indexer build ${QQ}

.PHONY: gitlab-elasticsearch-indexer/.git/pull
gitlab-elasticsearch-indexer/.git/pull: gitlab-elasticsearch-indexer/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-elasticsearch-indexer to ${gitlab_elasticsearch_indexer_version}"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_elasticsearch_indexer gitlab-elasticsearch-indexer "${gitlab_elasticsearch_indexer_version}"

##############################################################
# gitlab-pages
##############################################################

gitlab-pages-setup: gitlab-pages-secret gitlab-pages/gitlab-pages.conf gitlab-pages/bin/gitlab-pages

gitlab-pages-secret:
	$(Q)rake $@

.PHONY: gitlab-pages/gitlab-pages.conf
gitlab-pages/gitlab-pages.conf: ${gitlab_pages_clone_dir}/.git
	$(Q)rake $@

.PHONY: gitlab-pages-update
gitlab-pages-update: gitlab-pages-update-timed

.PHONY: gitlab-pages-update-run
gitlab-pages-update-run: ${gitlab_pages_clone_dir}/.git gitlab-pages/.git/pull gitlab-pages-clean-bin gitlab-pages/bin/gitlab-pages gitlab-pages/gitlab-pages.conf

gitlab-pages-clean-bin:
	$(Q)rm -f gitlab-pages/bin/gitlab-pages

.PHONY: gitlab-pages/bin/gitlab-pages
gitlab-pages/bin/gitlab-pages: ${gitlab_pages_clone_dir}/.git
	$(Q)$(MAKE) -C ${gitlab_pages_clone_dir} ${QQ}

${gitlab_pages_clone_dir}/.git:
	$(Q)support/move-existing-gitlab-pages-directory || git clone --quiet --branch "${pages_version}" ${git_depth_param} ${gitlab_pages_repo} ${gitlab_pages_clone_dir} ${QQ}

gitlab-pages/.git/pull:
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-pages to ${pages_version}"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_pages "${gitlab_pages_clone_dir}" "${pages_version}"

##############################################################
# gitlab Kubernetes agent
##############################################################

ifeq ($(gitlab_k8s_agent_enabled),true)
gitlab-k8s-agent-setup: gitlab-k8s-agent/build/gdk/bin/kas_race gitlab-k8s-agent-config.yml
else
gitlab-k8s-agent-setup:
	@true
endif

.PHONY: gitlab-k8s-agent-update
ifeq ($(gitlab_k8s_agent_enabled),true)
gitlab-k8s-agent-update: gitlab-k8s-agent-update-timed
else
gitlab-k8s-agent-update:
	@true
endif

.PHONY: gitlab-k8s-agent-update-run
gitlab-k8s-agent-update-run: ${gitlab_k8s_agent_clone_dir}/.git gitlab-k8s-agent/.git/pull gitlab-k8s-agent/build/gdk/bin/kas_race

.PHONY: gitlab-k8s-agent-config.yml
gitlab-k8s-agent-config.yml:
	$(Q)rake $@

.PHONY: gitlab-k8s-agent-clean
gitlab-k8s-agent-clean:
	$(Q)rm -rf "${gitlab_k8s_agent_clone_dir}/build/gdk/bin"
	cd "${gitlab_k8s_agent_clone_dir}" && bazel clean

gitlab-k8s-agent/build/gdk/bin/kas_race: ${gitlab_k8s_agent_clone_dir}/.git gitlab-k8s-agent/bazel
	@echo
	@echo "${DIVIDER}"
	@echo "Installing gitlab-org/cluster-integration/gitlab-agent"
	@echo "${DIVIDER}"
	$(Q)mkdir -p "${gitlab_k8s_agent_clone_dir}/build/gdk/bin"
	$(Q)$(MAKE) -C "${gitlab_k8s_agent_clone_dir}" gdk-install TARGET_DIRECTORY="$(CURDIR)/${gitlab_k8s_agent_clone_dir}/build/gdk/bin" ${QQ}

ifeq ($(platform),darwin)
gitlab-k8s-agent/bazel: /usr/local/bin/bazelisk
	$(Q)touch $@
else
.PHONY: gitlab-k8s-agent/bazel
gitlab-k8s-agent/bazel:
	@echo "INFO: To install bazel, please consult the docs at https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/kubernetes_agent.md"
endif

/usr/local/bin/bazelisk:
	$(Q)brew install bazelisk

${gitlab_k8s_agent_clone_dir}/.git:
	$(Q)git clone --quiet --branch "${gitlab_k8s_agent_version}" ${git_depth_param} ${gitlab_k8s_agent_repo} ${gitlab_k8s_agent_clone_dir} ${QQ}

gitlab-k8s-agent/.git/pull:
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/cluster-integration/gitlab-agent to ${gitlab_k8s_agent_version}"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_k8s_agent "${gitlab_k8s_agent_clone_dir}" "${gitlab_k8s_agent_version}"

##############################################################
# gitlab-ui
##############################################################

.PHONY: gitlab-ui-setup
ifeq ($(gitlab_ui_enabled),true)
gitlab-ui-setup: gitlab-ui/.git .gitlab-ui-yarn
else
gitlab-ui-setup:
	@true
endif

.PHONY: gitlab-ui-update
ifeq ($(gitlab_ui_enabled),true)
gitlab-ui-update: gitlab-ui-update-timed
else
gitlab-ui-update:
	@true
endif

.PHONY: gitlab-ui-update-run
gitlab-ui-update-run: gitlab-ui/.git gitlab-ui/.git/pull gitlab-ui-clean .gitlab-ui-yarn

gitlab-ui/.git:
	$(Q)git clone ${git_depth_param} ${gitlab_ui_repo} ${gitlab_ui_clone_dir} ${QQ}

gitlab-ui/.git/pull:
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-ui to default branch"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_ui "${gitlab_ui_clone_dir}" main

.PHONY: gitlab-ui-clean
gitlab-ui-clean:
	@rm -f .gitlab-ui-yarn

.gitlab-ui-yarn:
ifeq ($(YARN),)
	@echo "ERROR: YARN is not installed, please ensure you've bootstrapped your machine. See https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/index.md for more details"
	@false
else
	@echo
	@echo "${DIVIDER}"
	@echo "Installing gitlab-org/gitlab-ui Node.js packages"
	@echo "${DIVIDER}"
	$(Q)cd ${gitlab_development_root}/gitlab-ui && ${YARN} install --silent ${QQ}
	$(Q)cd ${gitlab_development_root}/gitlab-ui && ${YARN} build --silent ${QQ}
	$(Q)touch $@
endif

##############################################################
# gitlab performance metrics
##############################################################

performance-metrics-setup: Procfile grafana-setup

##############################################################
# gitlab support setup
##############################################################

support-setup: Procfile redis gitaly-setup jaeger-setup postgresql openssh-setup nginx-setup registry-setup elasticsearch-setup runner-setup

##############################################################
# redis
##############################################################

.PHONY: redis
redis: redis/redis.conf

.PHONY: redis/redis.conf
redis/redis.conf:
	$(Q)rake $@

##############################################################
# postgresql
##############################################################

.PHONY: postgresql
postgresql: postgresql/data postgresql/port postgresql-seed-rails postgresql-seed-praefect

postgresql/data:
	$(Q)${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_data_dir}

.PHONY: postgresql-seed-rails
postgresql-seed-rails: ensure-databases-running postgresql-seed-praefect
	$(Q)support/bootstrap-rails

.PHONY: postgresql-seed-praefect
postgresql-seed-praefect: Procfile postgresql/data postgresql-geo/data postgresql/geo/port
	$(Q)gdk start db
	$(Q)support/bootstrap-praefect

postgresql/port:
	$(Q)support/postgres-port ${postgresql_dir} ${postgresql_port}

postgresql-sensible-defaults:
	$(Q)support/postgresql-sensible-defaults ${postgresql_dir}

##############################################################
# postgresql replication
##############################################################

postgresql-replication-primary: postgresql-replication/access postgresql-replication/role postgresql-replication/config

postgresql-replication-secondary: postgresql-replication/data postgresql-replication/access postgresql-replication/backup postgresql-replication/config

postgresql-geo-replication-secondary: postgresql-geo-secondary-replication/data postgresql-geo-replication/access postgresql-replication/backup postgresql-replication/config

postgresql-replication-primary-create-slot: postgresql-replication/slot

postgresql-replication/data:
	${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_replica_data_dir}

postgresql-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_replica_data_dir}/pg_hba.conf

postgresql-replication/role:
	$(Q)$(psql) -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "CREATE ROLE ${postgresql_replication_user} WITH REPLICATION LOGIN;"

postgresql-replication/backup:
	$(Q)$(eval postgresql_primary_dir := $(realpath postgresql-primary))
	$(Q)$(eval postgresql_primary_host := $(shell cd ${postgresql_primary_dir}/../ && gdk config get postgresql.host $(QQerr)))
	$(Q)$(eval postgresql_primary_port := $(shell cd ${postgresql_primary_dir}/../ && gdk config get postgresql.port $(QQerr)))

	$(Q)$(psql) -h ${postgresql_primary_host} -p ${postgresql_primary_port} -d postgres -c "select pg_start_backup('base backup for streaming rep')"
	$(Q)rsync -cva --inplace --exclude="*pg_xlog*" --exclude="*.pid" ${postgresql_primary_dir}/data postgresql
	$(Q)$(psql) -h ${postgresql_primary_host} -p ${postgresql_primary_port} -d postgres -c "select pg_stop_backup(), current_timestamp"
	$(Q)./support/postgresql-standby-server ${postgresql_primary_host} ${postgresql_primary_port}
	$(Q)$(MAKE) postgresql/port ${QQ}

postgresql-replication/slot:
	$(Q)$(psql) -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_create_physical_replication_slot('gitlab_gdk_replication_slot');"

postgresql-replication/list-slots:
	$(Q)$(psql) -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_replication_slots;"

postgresql-replication/drop-slot:
	$(Q)$(psql) -h ${postgresql_host} -p ${postgresql_port} -d postgres -c "SELECT * FROM pg_drop_replication_slot('gitlab_gdk_replication_slot');"

postgresql-replication/config:
	$(Q)./support/postgres-replication ${postgresql_dir}

##############################################################
# postgresql geo
##############################################################

postgresql/geo: postgresql-geo/data postgresql/geo/port postgresql/geo/seed-data

postgresql-geo/data:
ifeq ($(geo_enabled),true)
	$(Q)${postgresql_bin_dir}/initdb --locale=C -E utf-8 postgresql-geo/data
else
	@true
endif

postgresql/geo/port: postgresql-geo/data
ifeq ($(geo_enabled),true)
	$(Q)support/postgres-port ${postgresql_geo_dir} ${postgresql_geo_port}
else
	@true
endif

postgresql/geo/Procfile:
	$(Q)grep '^postgresql-geo:' Procfile || (printf ',s/^#postgresql-geo/postgresql-geo/\nwq\n' | ed -s Procfile)

postgresql/geo/seed-data:
	$(Q)support/bootstrap-geo

postgresql-geo-replication-primary: postgresql-geo-replication/access postgresql-replication/role postgresql-replication/config

postgresql-geo-secondary-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_data_dir}/pg_hba.conf

postgresql-geo-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_data_dir}/pg_hba.conf

postgresql-geo-secondary-replication/data:
	${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_data_dir}

##############################################################
# influxdb
##############################################################

influxdb-setup:
	$(Q)echo "INFO: InfluxDB was removed from the GDK by https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues/927"

##############################################################
# elasticsearch
##############################################################

ifeq ($(elasticsearch_enabled),true)
elasticsearch-setup: elasticsearch/bin/elasticsearch
else
elasticsearch-setup:
	@true
endif

elasticsearch/bin/elasticsearch: .cache/.elasticsearch_${elasticsearch_version}_installed

.cache/.elasticsearch_${elasticsearch_version}_installed:
	$(Q)rm -rf elasticsearch && mkdir -p elasticsearch
	$(Q)curl -C - -L --fail "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${elasticsearch_version}-${platform}-x86_64.tar.gz" | tar xzf - --strip-components=1 -C elasticsearch
	$(Q)mkdir -p .cache && touch $@

##############################################################
# minio / object storage
##############################################################

.PHONY: object-storage-update
object-storage-update: object-storage-update-timed

.PHONY: object-storage-update-run
object-storage-update-run: object-storage-setup

object-storage-setup: minio/data/lfs-objects minio/data/artifacts minio/data/uploads minio/data/packages minio/data/terraform minio/data/pages minio/data/external-diffs

minio/data/%:
	$(Q)mkdir -p $@

##############################################################
# prometheus
##############################################################

prom-setup: prometheus/prometheus.yml

.PHONY: prometheus/prometheus.yml
prometheus/prometheus.yml:
	$(Q)rake $@

##############################################################
# grafana
##############################################################

ifeq ($(grafana_enabled),true)
grafana-setup: grafana/grafana.ini grafana/grafana/bin/grafana-server grafana/gdk-pg-created
else
grafana-setup:
	@true
endif

grafana/grafana/bin/grafana-server:
	$(Q)cd grafana && ${MAKE} ${QQ}

.PHONY: Procfile
grafana/grafana.ini:
	$(Q)rake $@

grafana/gdk-pg-created:
	$(Q)support/create-grafana-db
	$(Q)touch $@

grafana-update:
	@true

##############################################################
# openssh
##############################################################

openssh-setup: openssh/sshd_config openssh/ssh_host_rsa_key

openssh/ssh_host_rsa_key:
	$(Q)ssh-keygen -f $@ -N '' -t rsa

nginx-setup: nginx/conf/nginx.conf nginx/logs nginx/tmp

.PHONY: nginx/conf/nginx.conf
nginx/conf/nginx.conf:
	$(Q)rake $@

.PHONY: openssh/sshd_config
openssh/sshd_config:
	$(Q)rake $@

##############################################################
# nginx
##############################################################

nginx/logs:
	$(Q)mkdir -p $@

nginx/tmp:
	$(Q)mkdir -p $@

##############################################################
# registry
##############################################################

registry-setup: registry/storage registry/config.yml localhost.crt

localhost.crt: localhost.key

localhost.key:
	$(Q)${OPENSSL} req -new -subj "/CN=${hostname}/" -x509 -days 365 -newkey rsa:2048 -nodes -keyout "localhost.key" -out "localhost.crt"
	$(Q)chmod 600 $@

registry_host.crt: registry_host.key

registry_host.key:
	$(Q)${OPENSSL} req -new -subj "/CN=${registry_host}/" -x509 -days 365 -newkey rsa:2048 -nodes -keyout "registry_host.key" -out "registry_host.crt" -addext "subjectAltName=DNS:${registry_host}"
	$(Q)chmod 600 $@

registry/storage:
	$(Q)mkdir -p $@

.PHONY: registry/config.yml
registry/config.yml: registry_host.crt
	$(Q)rake $@

.PHONY: trust-docker-registry
trust-docker-registry: registry_host.crt
	$(Q)mkdir -p "${HOME}/.docker/certs.d/${registry_host}:${registry_port}"
	$(Q)rm -f "${HOME}/.docker/certs.d/${registry_host}:${registry_port}/ca.crt"
	$(Q)cp registry_host.crt "${HOME}/.docker/certs.d/${registry_host}:${registry_port}/ca.crt"
	$(Q)echo "Certificates have been copied to ~/.docker/certs.d/"
	$(Q)echo "Don't forget to restart Docker!"

##############################################################
# runner
##############################################################

runner-setup: gitlab-runner-config.toml

.PHONY: gitlab-runner-config.toml
ifeq ($(runner_enabled),true)
gitlab-runner-config.toml:
	$(Q)rake $@
else
gitlab-runner-config.toml:
	@true
endif

##############################################################
# jaeger
##############################################################

ifeq ($(jaeger_server_enabled),true)
.PHONY: jaeger-setup
jaeger-setup: jaeger/jaeger-${jaeger_version}/jaeger-all-in-one
else
.PHONY: jaeger-setup
jaeger-setup:
	@true
endif

jaeger/jaeger-${jaeger_version}/jaeger-all-in-one:
	@echo
	@echo "${DIVIDER}"
	@echo "Installing jaeger ${jaeger_version}"
	@echo "${DIVIDER}"

	$(Q)mkdir -p jaeger-artifacts

	@# To save disk space, delete old versions of the download,
	@# but to save bandwidth keep the current version....
	$(Q)find jaeger-artifacts ! -path "jaeger-artifacts/jaeger-${jaeger_version}.tar.gz" -type f -exec rm -f {} + -print

	$(Q)./support/download-jaeger "${jaeger_version}" "jaeger-artifacts/jaeger-${jaeger_version}.tar.gz"

	$(Q)mkdir -p "jaeger/jaeger-${jaeger_version}"
	$(Q)tar -xf "jaeger-artifacts/jaeger-${jaeger_version}.tar.gz" -C "jaeger/jaeger-${jaeger_version}" --strip-components 1

.PHONY: jaeger-update
jaeger-update: jaeger-update-timed

.PHONY: jaeger-update-run
jaeger-update-run: jaeger-setup

##############################################################
# Tests
##############################################################

.PHONY: test
test: checkmake lint shellcheck rubocop rspec verify-gdk-example-yml

.PHONY: rubocop
rubocop:
ifeq ($(BUNDLE),)
	@echo "ERROR: Bundler is not installed, please ensure you've bootstrapped your machine. See https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/index.md for more details"
	@false
else
ifeq ($(RUBOCOP),)
	@echo "INFO: Installing RuboCop.."
	$(Q)${bundle_install_cmd} ${QQ}
endif
	@echo -n "RuboCop: "
	@${BUNDLE} exec $@ --config .rubocop-gdk.yml --parallel
endif

.PHONY: rspec
rspec:
ifeq ($(BUNDLE),)
	@echo "ERROR: Bundler is not installed, please ensure you've bootstrapped your machine. See https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/index.md for more details"
	@false
else
ifeq ($(RSPEC),)
	@echo "INFO: Installing RSpec.."
	$(Q)${bundle_install_cmd} ${QQ}
endif
	@echo -n "RSpec: "
	@${BUNDLE} exec $@ ${RSPEC_ARGS}
endif

.PHONY: lint
lint: vale markdownlint

$(dev_vale_versioned_binary):
	@support/dev/vale-install

.PHONY: vale
vale: $(dev_vale_versioned_binary)
	@echo -n "Vale: "
	@${dev_vale_versioned_binary} --minAlertLevel error *.md doc

.PHONY: markdownlint-install
markdownlint-install:
ifeq ($(YARN)),)
	@echo "ERROR: YARN is not installed, please ensure you've bootstrapped your machine. See https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/index.md for more details"
	@false
else
	@[[ "${YARN}" ]] && ${YARN} install --silent --frozen-lockfile ${QQ}
endif

.PHONY: markdownlint
markdownlint: markdownlint-install
	@echo -n "MarkdownLint: "
	@${YARN} run --silent markdownlint --config .markdownlint.yml 'doc/**/*.md' && echo "OK"

.PHONY: shellcheck
shellcheck: ${dev_shellcheck_versioned_binary}
	@echo -n "Shellcheck: "
	@support/dev/shellcheck && echo "OK"

${dev_shellcheck_versioned_binary}:
	@support/dev/shellcheck-install

.PHONY: checkmake
checkmake: ${dev_checkmake_binary}
	@echo -n "Checkmake: "
	@${dev_checkmake_binary} Makefile && echo -e "\b\bOK"

${dev_checkmake_binary}:
	@support/dev/checkmake-install

.PHONY: verify-gdk-example-yml
verify-gdk-example-yml:
	@echo -n "Checking gdk.example.yml: "
	@support/ci/verify-gdk-example-yml && echo "OK"

##############################################################
# Misc
##############################################################

.PHONY: start
start:
	@echo
	$(Q)gdk start

.PHONY: ask-to-restart
ask-to-restart:
	@echo
	$(Q)support/ask-to-restart
	@echo

.PHONY: show-installed-at
show-installed-at:
	@echo
	@echo "> Installed as of $$(date +"%Y-%m-%d %T"). Took $$(($$(date +%s)-${START_TIME})) second(s)."

.PHONY: show-reconfigured-at
show-reconfigured-at:
	@echo
	@echo "> Reconfigured as of $$(date +"%Y-%m-%d %T"). Took $$(($$(date +%s)-${START_TIME})) second(s)."
