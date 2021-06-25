# frozen_string_literal: true

require 'cgi'
require 'etc'
require 'uri'
require_relative 'config_settings'

module GDK
  class Config < ConfigSettings
    GDK_ROOT = Pathname.new(__dir__).parent.parent
    FILE = File.join(GDK_ROOT, 'gdk.yml')

    string(:__architecture) { RbConfig::CONFIG['target_cpu'] }
    string(:__platform) do
      case RbConfig::CONFIG['host_os']
      when /darwin/i
        'darwin'
      when /linux/i
        'linux'
      else
        'unknown'
      end
    end

    bool(:__platform_linux) { config.__platform == 'linux' }
    bool(:__platform_darwin) { config.__platform == 'darwin' }
    bool(:__platform_supported?) { config.__platform != 'unknown' }

    settings :common do
      string(:ca_path) { '' }
    end

    settings :repositories do
      string(:gitlab) { 'https://gitlab.com/gitlab-org/gitlab.git' }
      string(:gitlab_shell) { 'https://gitlab.com/gitlab-org/gitlab-shell.git' }
      string(:gitaly) { 'https://gitlab.com/gitlab-org/gitaly.git' }
      string(:gitlab_pages) { 'https://gitlab.com/gitlab-org/gitlab-pages.git' }
      string(:gitlab_k8s_agent) { 'https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent.git' }
      string(:gitlab_docs) { 'https://gitlab.com/gitlab-org/gitlab-docs.git' }
      string(:gitlab_elasticsearch_indexer) { 'https://gitlab.com/gitlab-org/gitlab-elasticsearch-indexer.git' }
      string(:gitlab_ui) { 'https://gitlab.com/gitlab-org/gitlab-ui.git' }
      string(:gitlab_runner) { 'https://gitlab.com/gitlab-org/gitlab-runner.git' }
      string(:omnibus_gitlab) { 'https://gitlab.com/gitlab-org/omnibus-gitlab.git' }
      string(:charts_gitlab) { 'https://gitlab.com/gitlab-org/charts/gitlab.git' }
    end

    settings :dev do
      path(:__go_path) { GDK.root.join('dev') }
      path(:__bins) { config.dev.__go_path.join('bin') }
      path(:__go_binary) { MakeMakefile.find_executable('go') }
      bool(:__go_binary_available?) do
        !config.dev.__go_binary.nil?
      rescue TypeError
        false
      end

      settings(:checkmake) do
        path(:__binary) { config.dev.__bins.join('checkmake') }
      end

      settings(:vale) do
        string(:version) { '2.10.3' }
        string(:__platform) { config.__platform == 'darwin' ? 'macos' : config.__platform }
        path(:__binary) { config.dev.__bins.join('vale') }
        path(:__versioned_binary) { config.dev.__bins.join("vale_#{config.dev.vale.version}") }
      end

      settings(:shellcheck) do
        string(:version) { '0.7.2' }
        path(:__binary) { config.dev.__bins.join('shellcheck') }
        path(:__versioned_binary) { config.dev.__bins.join("shellcheck_#{config.dev.shellcheck.version}") }
      end
    end

    array(:git_repositories) do
      # This list in not exhaustive yet, as some git repositories are based on
      # a fake GOPATH inside a projects sub directory
      %w[/ gitlab]
        .map { |d| File.join(gdk_root, d) }
        .select { |d| Dir.exist?(d) }
    end

    path(:gdk_root) { self.class::GDK_ROOT }

    settings :gdk do
      bool(:ask_to_restart_after_update) { true }
      bool(:debug) { false }
      integer(:runit_wait_secs) { 20 }
      bool(:quiet) { true }
      bool(:auto_reconfigure) { true }
      settings :experimental do
        bool(:quiet) { config.gdk.quiet? }
        bool(:auto_reconfigure) { config.gdk.auto_reconfigure? }
      end
      bool(:overwrite_changes) { false }
      array(:protected_config_files) { [] }
      settings :start_hooks do
        array(:before) { [] }
        array(:after) { [] }
      end
      settings :stop_hooks do
        array(:before) { [] }
        array(:after) { [] }
      end
      settings :update_hooks do
        array(:before, merge: true) { ['cd gitlab && bin/spring stop || true'] }
        array(:after) { [] }
      end
    end

    path(:repositories_root) { config.gdk_root.join('repositories') }
    path(:repository_storages) { config.gdk_root.join('repository_storages') }

    string(:listen_address) { '127.0.0.1' }
    string(:hostname) { read!('hostname') || read!('host') || config.listen_address }
    integer(:port) { read!('port') || 3000 }

    settings :https do
      bool(:enabled) { read!('https_enabled') || false }
    end

    string :relative_url_root do
      read!('relative_url_root') || '/'
    end

    anything :__uri do
      # Only include the port if it's 'non standard'
      klass = config.https? ? URI::HTTPS : URI::HTTP
      relative_url_root = config.relative_url_root.gsub(%r{/+$}, '')

      klass.build(host: config.hostname, port: config.port, path: relative_url_root)
    end

    string(:username) { Etc.getpwuid.name }

    settings :load_balancing do
      bool(:enabled) { false }
    end

    settings :webpack do
      string(:host) { read!('webpack_host') || config.hostname }
      bool(:static) { false }
      bool(:vendor_dll) { false }
      bool(:incremental) { false }
      bool(:sourcemaps) { true }
      bool(:live_reload) { !config.https? }

      integer(:port) { read!('webpack_port') || 3808 }
    end

    settings :action_cable do
      bool(:in_app) { true }
      integer(:worker_pool_size) { 4 }
    end

    settings :workhorse do
      integer(:configured_port) { 3333 }

      settings :__listen_settings do
        string(:__type) do
          if config.gitlab.rails.address.empty?
            'authSocket'
          else
            'authBackend'
          end
        end

        string(:__address) do
          config.gitlab.rails.__workhorse_url
        end
      end

      string(:__active_host) { config.hostname }

      integer :__active_port do
        if config.nginx?
          config.workhorse.configured_port
        else
          # Workhorse is the user-facing entry point whenever neither nginx nor
          # AutoDevOps is used, so in that situation use the configured GDK port.
          config.port
        end
      end

      string :__listen_address do
        "#{config.workhorse.__active_host}:#{config.workhorse.__active_port}"
      end
    end

    settings :gitlab_shell do
      bool(:auto_update) { true }
      string(:dir) { config.gdk_root.join('gitlab-shell') }
    end

    settings :gitlab_ui do
      bool(:enabled) { false }
      bool(:auto_update) { true }
    end

    settings :gitlab_docs do
      bool(:enabled) { false }
      bool(:auto_update) { true }
      integer(:port) { 3005 }

      bool(:__all_configured?) { config.gitlab_docs.enabled? && config.gitlab_runner.enabled? && config.omnibus_gitlab.enabled? && config.charts_gitlab.enabled? }

      string(:__nanoc_cmd_common) { "--host #{config.hostname} --port #{config.gitlab_docs.port}" }
      string(:__nanoc_live_cmd) { "bundle exec nanoc live #{config.gitlab_docs.__nanoc_cmd_common}" }
      string(:__nanoc_view_cmd) { "bundle exec nanoc compile && bundle exec nanoc view #{config.gitlab_docs.__nanoc_cmd_common}" }
    end

    settings :gitlab_runner do
      bool(:enabled) { false }
      bool(:auto_update) { true }
    end

    settings :omnibus_gitlab do
      bool(:enabled) { false }
      bool(:auto_update) { true }
    end

    settings :charts_gitlab do
      bool(:enabled) { false }
      bool(:auto_update) { true }
    end

    settings :gitlab_elasticsearch_indexer do
      bool(:auto_update) { true }
      path(:__dir) { config.gdk_root.join('gitlab-elasticsearch-indexer') }
    end

    settings :registry do
      bool(:enabled) { read!('registry_enabled') || false }
      string(:host) { config.hostname }
      string(:listen_address) { config.listen_address }
      string(:api_host) { config.hostname }

      integer :port do
        read!('registry_port') || 5000
      end

      string :image do
        read!('registry_image') ||
          'registry.gitlab.com/gitlab-org/build/cng/gitlab-container-registry:'\
        'v2.9.1-gitlab'
      end

      bool(:self_signed) { false }
      bool(:auth_enabled) { true }

      string(:uid) { '' }
      string(:gid) { '' }

      bool(:compatibility_schema1_enabled) { false }
    end

    settings :object_store do
      bool(:consolidated_form) { false }
      bool(:enabled) { read!('object_store_enabled') || false }
      string(:host) { config.listen_address }
      integer(:port) { read!('object_store_port') || 9000 }
      hash_setting(:connection) do
        {
          'provider' => 'AWS',
          'aws_access_key_id' => 'minio',
          'aws_secret_access_key' => 'gdk-minio',
          'region' => 'gdk',
          'endpoint' => "http://#{config.object_store.host}:#{config.object_store.port}",
          'path_style' => true
        }
      end
      hash_setting(:objects) do
        {
          'artifacts' => { 'bucket' => 'artifacts' },
          'external_diffs' => { 'bucket' => 'external-diffs' },
          'lfs' => { 'bucket' => 'lfs-objects' },
          'uploads' => { 'bucket' => 'uploads' },
          'packages' => { 'bucket' => 'packages' },
          'dependency_proxy' => { 'bucket' => 'dependency_proxy' },
          'terraform_state' => { 'bucket' => 'terraform' },
          'pages' => { 'bucket' => 'pages' }
        }
      end
    end

    settings :gitlab_pages do
      bool(:enabled) { false }
      string(:host) { "#{config.listen_address}.nip.io" }
      integer(:port) { read!('gitlab_pages_port') || 3010 }
      string(:__uri) { "#{config.gitlab_pages.host}:#{config.gitlab_pages.port}" }
      bool(:auto_update) { true }
      string(:secret_file) { config.gdk_root.join('gitlab-pages-secret') }
      bool(:verbose) { false }
      bool(:access_control) { false }
      string(:auth_client_id) { '' }
      string(:auth_client_secret) { '' }
      # random 32-byte string
      string(:__auth_secret) { SecureRandom.alphanumeric(32) }
      string(:__auth_redirect_uri) { "http://#{config.gitlab_pages.__uri}/auth" }
    end

    settings :gitlab_k8s_agent do
      bool(:enabled) { false }
      bool(:auto_update) { true }

      string(:agent_listen_network) { 'tcp' }
      string(:agent_listen_address) { "#{config.listen_address}:8150" }
      string(:__agent_listen_url_path) { '/-/kubernetes-agent' }
      bool(:__agent_listen_websocket) do
        if config.nginx?
          # nginx's grpc_pass requires HTTP/2 enabled which requires TLS.
          # It's easier to use WebSockets than ask the user to generate
          # TLS certificates.
          true
        else
          false
        end
      end
      string(:__url_for_agentk) do
        if config.nginx?
          # kas is behind nginx
          if config.https?
            "wss://#{config.nginx.__listen_address}#{config.gitlab_k8s_agent.__agent_listen_url_path}"
          else
            "ws://#{config.nginx.__listen_address}#{config.gitlab_k8s_agent.__agent_listen_url_path}"
          end
        elsif config.gitlab_k8s_agent.agent_listen_network == 'tcp'
          "grpc://#{config.gitlab_k8s_agent.agent_listen_address}"
        else
          raise UnsupportedConfiguration, "Unsupported listen network #{config.gitlab_k8s_agent.agent_listen_network}"
        end
      end

      string(:private_api_listen_network) { 'tcp' }
      string(:private_api_listen_address) { "#{config.listen_address}:8155" }
      string(:__private_api_secret_file) { config.gitlab_k8s_agent.__secret_file }
      string(:__private_api_url) { "grpc://#{config.gitlab_k8s_agent.private_api_listen_address}" }

      string(:k8s_api_listen_network) { 'tcp' }
      string(:k8s_api_listen_address) { "#{config.listen_address}:8154" }
      string(:__k8s_api_listen_url_path) { '/-/k8s-proxy' }

      string(:internal_api_listen_network) { 'tcp' }
      string(:internal_api_listen_address) { "#{config.listen_address}:8153" }
      string(:__internal_api_url) do
        case config.gitlab_k8s_agent.internal_api_listen_network
        when 'tcp'
          "grpc://#{internal_api_listen_address}"
        when 'unix'
          "unix://#{internal_api_listen_address}"
        else
          raise UnsupportedConfiguration, "Unsupported listen network #{config.gitlab_k8s_agent.internal_api_listen_network}"
        end
      end

      string(:__gitlab_address) { "http://#{config.workhorse.__listen_address}" }
      string(:__config_file) { config.gdk_root.join('gitlab-k8s-agent-config.yml') }
      string(:__secret_file) { config.gdk_root.join('gitlab', '.gitlab_kas_secret') }
    end

    settings :omniauth do
      settings :google_oauth2 do
        string(:enabled) { !!read!('google_oauth_client_secret') || '' }
        string(:client_id) { read!('google_oauth_client_id') || '' }
        string(:client_secret) { read!('google_oauth_client_secret') || '' }
      end
      settings :github do
        bool(:enabled) { false }
        string(:client_id) { '' }
        string(:client_secret) { '' }
      end
      settings :group_saml do
        bool(:enabled) { false }
      end
    end

    settings :geo do
      bool(:enabled) { false }
      bool(:secondary) { false }
      string(:node_name) { config.gdk_root.basename.to_s }
      settings :registry_replication do
        bool(:enabled) { false }
        string(:primary_api_url) { 'http://localhost:5000' }
      end
    end

    settings :elasticsearch do
      bool(:enabled) { false }
      string(:version) { '7.10.2' }
      string(:mac_checksum) { '0f2f72fffd89e5b2cb55d427b59d73fb6a39fd899a9e0c1c4654475165cfba2c46e83d227c71630532f431da3db65c150445c08d83e160cfc683024298a0b625' }
      string(:linux_checksum) { 'd1956a9945b86099b1c89b246ec74ada294eab40f342a1af590f7dde7f69a3dce835f7f555dfeb1bc02726febc3facb3d92f52c8421b5d96cf803df16c1d4240' }
    end

    settings :tracer do
      string(:build_tags) { 'tracer_static tracer_static_jaeger' }
      settings :jaeger do
        bool(:enabled) { false }
        string(:version) { '1.21.0' }
        string(:listen_address) { config.hostname }
        string(:__tracer_url) do
          http_endpoint = "http://#{config.tracer.jaeger.listen_address}:14268/api/traces"

          "opentracing://jaeger?http_endpoint=#{CGI.escape(http_endpoint)}&sampler=const&sampler_param=1"
        end

        string(:__search_url) do
          tags = CGI.escape('{"correlation_id":"__CID__"}').gsub('__CID__', '{{ correlation_id }}')

          "http://#{config.tracer.jaeger.listen_address}:16686/search?service={{ service }}&tags=#{tags}"
        end
      end
    end

    settings :nginx do
      bool(:enabled) { false }
      string(:listen) { config.hostname }
      string(:bin) { find_executable!('nginx') || '/usr/local/bin/nginx' }
      settings :ssl do
        string(:certificate) { 'localhost.crt' }
        string(:key) { 'localhost.key' }
      end
      settings :http do
        bool(:enabled) { false }
        integer(:port) { 8080 }
      end
      settings :http2 do
        bool(:enabled) { false }
      end
      string(:__listen_address) { "#{config.nginx.listen}:#{config.port}" }
      array(:__request_buffering_off_routes) do
        [
          '/api/v\d/jobs/\d+/artifacts$',
          '\.git/git-receive-pack$',
          '\.git/gitlab-lfs/objects',
          '\.git/info/lfs/objects/batch$'
        ]
      end
    end

    settings :postgresql do
      integer(:port) { read!('postgresql_port') || 5432 }
      path(:bin_dir) { cmd!(%w[support/pg_bindir]) || '/usr/local/bin' }
      path(:bin) { config.postgresql.bin_dir.join('postgres') }
      string(:replication_user) { 'gitlab_replication' }
      path(:dir) { config.gdk_root.join('postgresql') }
      path(:data_dir) { config.postgresql.dir.join('data') }
      string(:host) { config.postgresql.dir.to_s }
      string(:active_version) { GDK::Postgresql::TARGET_VERSION.to_s }
      string(:__active_host) { GDK::Postgresql.new.use_tcp? ? config.postgresql.host : '' }
      path(:replica_dir) { config.gdk_root.join('postgresql-replica') }
      path(:replica_data_dir) { config.postgresql.replica_dir.join('data') }
      settings :replica do
        bool(:enabled) { false }
      end
      settings :geo do
        integer(:port) { 5431 }
        path(:dir) { config.gdk_root.join('postgresql-geo') }
        string(:host) { config.postgresql.geo.dir.to_s }
        string(:__active_host) { GDK::PostgresqlGeo.new.use_tcp? ? config.postgresql.geo.host : '' }
      end
    end

    settings :gitaly do
      path(:dir) { config.gdk_root.join('gitaly') }
      path(:ruby_dir) { config.gitaly.dir.join('ruby') }
      bool(:enabled) { !config.praefect? || storage_count > 1 }
      path(:address) { config.gdk_root.join('gitaly.socket') }
      path(:assembly_dir) { config.gitaly.dir.join('assembly') }
      path(:config_file) { config.gitaly.dir.join('gitaly.config.toml') }
      path(:log_dir) { config.gdk_root.join('log', 'gitaly') }
      path(:storage_dir) { config.repositories_root }
      path(:repository_storages) { config.repository_storages }
      path(:internal_socket_dir) { config.gdk_root.join('tmp', 'gitaly') }
      string(:auth_token) { '' }
      bool(:auto_update) { true }
      integer(:storage_count) { 1 }
      path(:__build_path) { config.gitaly.dir.join('_build') }
      path(:__build_bin_path) { config.gitaly.__build_path.join('bin') }
      path(:__build_deps_path) { config.gitaly.__build_path.join('deps') }
      path(:__gitaly_build_bin_path) { config.gitaly.__build_bin_path.join('gitaly') }
      path(:git_bin_path) { config.gitaly.__build_deps_path.join('git', 'install', 'bin', 'git') }
      settings_array :__storages, size: -> { storage_count } do |i|
        string(:name) { i.zero? ? 'default' : "gitaly-#{i}" }
        path(:path) do
          if i.zero?
            parent.parent.storage_dir
          else
            File.join(config.repository_storages, 'gitaly', name)
          end
        end
      end
    end

    settings :praefect do
      path(:address) { config.gdk_root.join('praefect.socket') }
      path(:config_file) { config.gitaly.dir.join('praefect.config.toml') }
      bool(:enabled) { true }
      path(:internal_socket_dir) { config.gdk_root.join('tmp', 'praefect') }
      path(:__praefect_build_bin_path) { config.gitaly.__build_bin_path.join('praefect') }
      settings :database do
        string(:host) { config.geo.secondary? ? config.postgresql.geo.host : config.postgresql.host }
        integer(:port) { config.geo.secondary? ? config.postgresql.geo.port : config.postgresql.port }
        string(:dbname) { 'praefect_development' }
        string(:sslmode) { 'disable' }
      end
      integer(:node_count) { 1 }
      settings_array :__nodes, size: -> { config.praefect.node_count } do |i|
        path(:address) { config.gdk_root.join("gitaly-praefect-#{i}.socket") }
        string(:config_file) { "gitaly/gitaly-#{i}.praefect.toml" }
        path(:log_dir) { config.gdk_root.join('log', "praefect-gitaly-#{i}") }
        string(:service_name) { "praefect-gitaly-#{i}" }
        string(:storage) { "praefect-internal-#{i}" }
        path(:storage_dir) { config.repositories_root }
        path(:repository_storages) { config.repository_storages }
        path(:internal_socket_dir) { config.gdk_root.join('tmp', 'praefect', "gitaly-#{i}") }
        settings_array :__storages, size: 1 do |j|
          string(:name) { parent.parent.storage }
          path(:path) { i.zero? && j.zero? ? parent.parent.storage_dir : File.join(parent.parent.repository_storages, parent.parent.service_name, name) }
        end
      end
    end

    settings :sshd do
      string(:__full_command) do
        if config.sshd.use_gitlab_sshd?
          "#{config.gitlab_shell.dir}/bin/gitlab-sshd -config-dir #{config.gitlab_shell.dir}"
        else
          "#{config.sshd.bin} -e -D -f #{config.gdk_root.join('openssh', 'sshd_config')}"
        end
      end

      string(:__log_file) do
        if config.sshd.use_gitlab_sshd?
          "/dev/stdout"
        else
          "#{config.gitlab_shell.dir}/gitlab-shell.log"
        end
      end

      string(:__listen) do
        host = config.sshd.listen_address
        host = "[#{host}]" if host.include?(':')

        "#{host}:#{config.sshd.listen_port}"
      end

      bool(:enabled) { true }
      bool(:use_gitlab_sshd) { true }
      string(:listen_address) { config.hostname }
      integer(:listen_port) { 2222 }
      string(:user) do
        if config.sshd.use_gitlab_sshd?
          'git'
        else
          config.username
        end
      end
      path(:host_key) { config.gdk_root.join('openssh', 'ssh_host_rsa_key') }

      # gitlab-sshd only
      bool(:proxy_protocol) { false }
      string(:web_listen) { '' }

      # OpenSSH only
      path(:bin) { find_executable!('sshd') || '/usr/local/sbin/sshd' }
      string(:additional_config) { '' }
      path(:authorized_keys_file) { config.gdk_root.join('.ssh', 'authorized_keys') }
    end

    settings :git do
      path(:bin) { find_executable!('git') || '/usr/local/bin/git' }
    end

    settings :runner do
      path(:config_file) { config.gdk_root.join('gitlab-runner-config.toml') }
      bool(:enabled) { !!read!(config.runner.config_file) }
      array(:extra_hosts) { [] }
      string(:token) { 'DEFAULT TOKEN: Register your runner to get a valid token' }
      path(:bin) { find_executable!('gitlab-runner') || '/usr/local/bin/gitlab-runner' }
      bool(:network_mode_host) { false }
      bool(:__network_mode_host) do
        raise UnsupportedConfiguration, 'runner.network_mode_host is only supported on Linux' if config.runner.network_mode_host && !config.__platform_linux?

        config.runner.network_mode_host
      end
    end

    settings :grafana do
      bool(:enabled) { false }
      integer(:port) { 4000 }
    end

    settings :prometheus do
      bool(:enabled) { false }
      integer(:port) { 9090 }
      integer(:gitaly_exporter_port) { 9236 }
      integer(:praefect_exporter_port) { 10_101 }
      integer(:sidekiq_exporter_port) { 3807 }
    end

    settings :openldap do
      bool(:enabled) { false }
    end

    settings :mattermost do
      bool(:enabled) { false }
      integer(:port) { 8065 }
      string(:image) { 'mattermost/mattermost-preview' }
    end

    settings :gitlab do
      bool(:auto_update) { true }
      path(:dir) { config.gdk_root.join('gitlab') }
      bool(:cache_classes) { false }

      settings :rails do
        string(:address) { '' }
        string(:__bind) { "#{config.gitlab.rails.__listen_settings.__protocol}://#{config.gitlab.rails.__listen_settings.__address}" }
        string(:__workhorse_url) do
          if config.gitlab.rails.address.empty?
            config.gitlab.rails.__socket_file
          else
            "http://#{config.gitlab.rails.__listen_settings.__address}"
          end
        end
        path(:__socket_file) { config.gdk_root.join('gitlab.socket') }
        string(:__socket_file_escaped) { CGI.escape(config.gitlab.rails.__socket_file.to_s) }

        settings :__listen_settings do
          string(:__protocol) do
            if config.gitlab.rails.address.empty?
              'unix'
            else
              'tcp'
            end
          end

          string(:__address) do
            if config.gitlab.rails.address.empty?
              config.gitlab.rails.__socket_file
            else
              config.gitlab.rails.address
            end
          end
        end

        bool(:sherlock) { false }

        settings :puma do
          integer(:workers) { 2 }

          integer(:threads_max) { 4 }
          integer(:__threads_max) { config.gitlab.rails.puma.__threads_min > config.gitlab.rails.puma.threads_max ? config.gitlab.rails.puma.__threads_min : config.gitlab.rails.puma.threads_max }
          integer(:threads_min) { 1 }
          integer(:__threads_min) { config.gitlab.rails.puma.workers.zero? ? config.gitlab.rails.puma.threads_max : config.gitlab.rails.puma.threads_min }
        end
      end

      settings :actioncable do
        path(:__socket_file) do
          if config.action_cable.in_app?
            config.gdk_root.join('gitlab.socket')
          else
            config.gdk_root.join('gitlab.actioncable.socket')
          end
        end
      end
    end

    settings :redis do
      path(:dir) { config.gdk_root.join('redis') }
      path(:__socket_file) { dir.join('redis.socket') }
    end

    settings :asdf do
      bool(:opt_out) { false }
    end

    settings :packages do
      path(:__dpkg_deb_path) do
        if config.__platform_darwin?
          '/usr/local/bin/dpkg-deb'
        else
          '/usr/bin/dpkg-deb'
        end
      end
    end
  end
end
