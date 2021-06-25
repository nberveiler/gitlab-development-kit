# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Config do
  let(:nginx_enabled) { false }
  let(:group_saml_enabled) { false }
  let(:protected_config_files) { [] }
  let(:overwrite_changes) { false }
  let(:use_gitlab_sshd) { true }
  let(:listen_address) { '127.0.0.1' }
  let(:omniauth_config) { { 'group_saml' => { 'enabled' => group_saml_enabled } } }
  let(:yaml) do
    {
      'gdk' => { 'protected_config_files' => protected_config_files, 'overwrite_changes' => overwrite_changes },
      'nginx' => { 'enabled' => nginx_enabled },
      'hostname' => 'gdk.example.com',
      'omniauth' => omniauth_config,
      'sshd' => { 'use_gitlab_sshd' => use_gitlab_sshd, 'listen_address' => listen_address }
    }
  end

  let(:default_config) { described_class.new }

  subject(:config) { described_class.new(yaml: yaml) }

  before do
    # Ensure a developer's local gdk.yml does not affect tests
    allow_any_instance_of(GDK::ConfigSettings).to receive(:read!).and_return(nil)
  end

  describe 'common' do
    describe 'ca_path' do
      it 'is not set by default' do
        expect(config.common.ca_path).to be('')
      end
    end
  end

  describe '__architecture' do
    it 'returns x86_64' do
      allow(RbConfig::CONFIG).to receive(:[]).with('target_cpu').and_return('x86_64')

      expect(config.__architecture).to eq('x86_64')
    end
  end

  describe '__platform' do
    let(:host_os) { nil }

    before do
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
    end

    context 'when macOS' do
      let(:host_os) { 'Darwin' }

      it 'returns darwin' do
        expect(config.__platform).to eq('darwin')
      end
    end

    context 'when Linux' do
      let(:host_os) { 'Linux' }

      it 'returns linux' do
        expect(config.__platform).to eq('linux')
      end
    end

    context 'when neither macOS of Linux' do
      let(:host_os) { 'NotSure' }

      it 'returns unknown' do
        expect(config.__platform).to eq('unknown')
      end
    end
  end

  describe '__platform_linux' do
    before do
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
    end

    context 'on a macOS system' do
      let(:host_os) { 'darwin' }

      it 'returns false' do
        expect(config.__platform_linux).to be(false)
        expect(config.__platform_linux?).to be(false)
      end
    end

    context 'on a Linux system' do
      let(:host_os) { 'linux' }

      it 'returns true' do
        expect(config.__platform_linux).to be(true)
        expect(config.__platform_linux?).to be(true)
      end
    end
  end

  describe '__platform_darwin' do
    before do
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
    end

    context 'on a Linux system' do
      let(:host_os) { 'linux' }

      it 'returns false' do
        expect(config.__platform_darwin).to be(false)
        expect(config.__platform_darwin?).to be(false)
      end
    end

    context 'on a macOS system' do
      let(:host_os) { 'darwin' }

      it 'returns true' do
        expect(config.__platform_darwin).to be(true)
        expect(config.__platform_darwin?).to be(true)
      end
    end
  end

  describe '__uri' do
    context 'for defaults' do
      it 'returns http://gdk.example.com:3000' do
        expect(config.__uri.to_s).to eq('http://gdk.example.com:3000')
      end
    end

    context 'when port is set to 1234' do
      it 'returns http://gdk.example.com:1234' do
        yaml['port'] = '1234'

        expect(config.__uri.to_s).to eq('http://gdk.example.com:1234')
      end
    end

    context 'when a relative_url_root is set' do
      it 'returns http://gdk.example.com:3000/gitlab' do
        yaml['relative_url_root'] = '/gitlab/'

        expect(config.__uri.to_s).to eq('http://gdk.example.com:3000/gitlab')
      end
    end

    context 'when https is enabled' do
      before do
        yaml['https'] = { 'enabled' => true }
      end

      it 'returns https://gdk.example.com:3000' do
        expect(config.__uri.to_s).to eq('https://gdk.example.com:3000')
      end

      context 'and port is set to 443' do
        it 'returns https://gdk.example.com/' do
          yaml['port'] = '443'

          expect(config.__uri.to_s).to eq('https://gdk.example.com')
        end
      end
    end
  end

  describe 'elasticsearch' do
    let(:checksum) { 'e7c22b994c59d9cf2b48e549b1e24666636045930d3da7c1acb299d1c3b7f931f94aae41edda2c2b207a36e10f8bcb8d45223e54878f5b316e7ce3b6bc019629' }

    describe '#enabled' do
      it 'defaults to false' do
        expect(config.elasticsearch.enabled).to eq(false)
      end

      context 'when enabled in config file' do
        let(:yaml) do
          { 'elasticsearch' => { 'enabled' => true } }
        end

        it 'returns true' do
          expect(config.elasticsearch.enabled).to eq(true)
        end
      end
    end

    describe '#version' do
      it 'has a default value' do
        expect(config.elasticsearch.version).to match(/\d+.\d+.\d+/)
      end

      context 'when specified in config file' do
        let(:version) { '7.8.0' }
        let(:yaml) do
          { 'elasticsearch' => { 'version' => version } }
        end

        it 'returns the version from the config file' do
          expect(config.elasticsearch.version).to eq(version)
        end
      end
    end

    describe '#mac_checksum' do
      it 'has a default value' do
        expect(config.elasticsearch.mac_checksum).to match(/[a-f0-9]{128}/)
      end

      context 'when specified in config file' do
        let(:yaml) do
          { 'elasticsearch' => { 'mac_checksum' => checksum } }
        end

        it 'returns the version from the config file' do
          expect(config.elasticsearch.mac_checksum).to eq(checksum)
        end
      end
    end

    describe '#linux_checksum' do
      it 'has a default value' do
        expect(config.elasticsearch.linux_checksum).to match(/[a-f0-9]{128}/)
      end

      context 'when specified in config file' do
        let(:yaml) do
          { 'elasticsearch' => { 'linux_checksum' => checksum } }
        end

        it 'returns the version from the config file' do
          expect(config.elasticsearch.linux_checksum).to eq(checksum)
        end
      end
    end
  end

  describe 'repositories' do
    describe 'gitlab_ui' do
      it 'returns the gitlab-ui repository URL' do
        expect(config.repositories.gitlab_ui).to eq('https://gitlab.com/gitlab-org/gitlab-ui.git')
      end
    end
  end

  describe 'workhorse' do
    describe '#__active_host' do
      it 'returns the configured hostname' do
        expect(config.workhorse.__active_host).to eq(config.hostname)
      end
    end

    describe '#__listen_address' do
      it 'is set to ip and port' do
        expect(config.workhorse.__listen_address).to eq('gdk.example.com:3000')
      end
    end
  end

  describe '#__active_port' do
    context 'when nginx is not enabled' do
      it 'returns 3000' do
        expect(config.workhorse.__active_port).to eq(3000)
      end
    end

    context 'when nginx is enabled' do
      let(:nginx_enabled) { true }

      it 'returns 3333' do
        expect(config.workhorse.__active_port).to eq(3333)
      end
    end
  end

  describe 'sshd' do
    describe '#__full_command' do
      subject { config.sshd.__full_command }

      context 'when gitlab-sshd is disabled' do
        let(:use_gitlab_sshd) { false }

        it { is_expected.to eq("#{config.sshd.bin} -e -D -f #{config.gdk_root.join('openssh', 'sshd_config')}") }
      end

      context 'when gitlab-sshd is enabled' do
        let(:use_gitlab_sshd) { true }

        it { is_expected.to eq("#{config.gitlab_shell.dir}/bin/gitlab-sshd -config-dir #{config.gitlab_shell.dir}") }
      end
    end

    describe '#__log_file' do
      subject { config.sshd.__log_file }

      context 'when gitlab-sshd is disabled' do
        let(:use_gitlab_sshd) { false }

        it { is_expected.to eq("#{config.gitlab_shell.dir}/gitlab-shell.log") }
      end

      context 'when gitlab-sshd is enabled' do
        let(:use_gitlab_sshd) { true }

        it { is_expected.to eq('/dev/stdout') }
      end
    end

    describe '#___listen' do
      subject { config.sshd.__listen }

      context 'when listen address is IPv4' do
        let(:listen_address) { '127.0.0.1' }

        it { is_expected.to eq('127.0.0.1:2222') }
      end

      context 'when listen address is IPv6' do
        let(:listen_address) { '::1' }

        it { is_expected.to eq('[::1]:2222') }
      end

      context 'when listen address is a hostname' do
        let(:listen_address) { 'localhost' }

        it { is_expected.to eq('localhost:2222') }
      end
    end
  end

  describe '#dump!' do
    before do
      stub_pg_bindir
    end

    it 'successfully dumps the config' do
      expect do
        expect(config.dump!).to be_a_kind_of(Hash)
      end.not_to raise_error
    end

    it 'does not dump options intended for internal use only' do
      expect(config).to respond_to(:__uri)
      expect(config.dump!).not_to include('__uri')
    end

    it 'does not dump options based on question mark convenience methods' do
      expect(config.gdk).to respond_to(:debug?)
      expect(config.gdk.dump!).not_to include('debug?')
    end
  end

  describe '#validate!' do
    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('gdk.example.yml').and_return(raw_yaml)
    end

    context 'when gdk.yml is valid' do
      let(:raw_yaml) { "---\ngdk:\n  debug: true" }

      it 'returns nil' do
        expect(described_class.new.gdk.validate!).to be_nil
      end
    end

    context 'with invalid YAML' do
      let(:raw_yaml) { "---\ngdk:\n  debug" }

      it 'raises an exception' do
        expect { described_class.new.gdk.validate! }.to raise_error(/undefined method `fetch' for "debug":String/)
      end
    end

    context 'with partially invalid YAML' do
      let(:raw_yaml) { "---\ngdk:\n  debug: fals" }

      it 'raises an exception' do
        expect { described_class.new.gdk.validate! }.to raise_error(/Value 'fals' for gdk.debug is not a valid bool/)
      end
    end
  end

  describe '#[]' do
    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('gdk.example.yml').and_return(raw_yaml)
    end

    context 'when looking up a single slug' do
      let(:raw_yaml) { "---\ngdk_root: /tmp/gdk" }

      it 'returns the value' do
        expect(described_class.new['gdk_root'].to_s).to eq('/tmp/gdk')
      end
    end

    context 'when looking up a multiple slugs' do
      let(:raw_yaml) { "---\ngdk:\n  debug: true" }

      it 'is not designed to return a value' do
        expect(described_class.new['gdk.debug'].to_s).to eq('')
      end
    end
  end

  describe '#username' do
    before do
      allow(Etc).to receive_message_chain(:getpwuid, :name) { 'iamfoo' }
    end

    it 'returns the short login name of the current process uid' do
      expect(config.username).to eq('iamfoo')
    end
  end

  describe '#praefect' do
    describe '#database' do
      let(:yaml) do
        {
          'praefect' => {
            'node_count' => 3,
            'database' => {
              'host' => 'localhost',
              'port' => 1234
            }
          }
        }
      end

      describe '#host' do
        it { expect(default_config.praefect.database.host).to eq(default_config.postgresql.dir.to_s) }

        context 'for a non-Geo setup' do
          it 'returns configured value' do
            expect(config.praefect.database.host).to eq('localhost')
          end
        end

        context 'for a Geo secondary' do
          let!(:yaml) do
            {
              'geo' => {
                'enabled' => true,
                'secondary' => true
              }
            }
          end

          it 'returns configured value' do
            expect(config.praefect.database.host).to eq('/home/git/gdk/postgresql-geo')
          end
        end
      end

      describe '#port' do
        it { expect(default_config.praefect.database.port).to eq(5432) }

        context 'for a non-Geo setup' do
          it 'returns configured value' do
            expect(config.praefect.database.port).to eq(1234)
          end
        end

        context 'for a Geo secondary' do
          let!(:yaml) do
            {
              'geo' => {
                'enabled' => true,
                'secondary' => true
              }
            }
          end

          it 'returns configured value' do
            expect(config.praefect.database.port).to eq(5431)
          end
        end
      end

      describe '#__storages' do
        it 'has defaults' do
          expect(default_config.praefect.__nodes.length).to eq(1)
          expect(default_config.praefect.__nodes[0].__storages.length).to eq(1)
          expect(default_config.praefect.__nodes[0].__storages[0].name).to eq('praefect-internal-0')
          expect(default_config.praefect.__nodes[0].__storages[0].path).to eq(Pathname.new('/home/git/gdk/repositories'))
        end

        it 'returns the configured value' do
          expect(config.praefect.__nodes.length).to eq(3)

          expect(config.praefect.__nodes[0].__storages.length).to eq(1)
          expect(config.praefect.__nodes[0].__storages[0].name).to eq('praefect-internal-0')
          expect(config.praefect.__nodes[0].__storages[0].path).to eq(Pathname.new('/home/git/gdk/repositories'))

          expect(config.praefect.__nodes[1].__storages.length).to eq(1)
          expect(config.praefect.__nodes[1].__storages[0].name).to eq('praefect-internal-1')
          expect(config.praefect.__nodes[1].__storages[0].path).to eq(Pathname.new('/home/git/gdk/repository_storages/praefect-gitaly-1/praefect-internal-1'))

          expect(config.praefect.__nodes[2].__storages.length).to eq(1)
          expect(config.praefect.__nodes[2].__storages[0].name).to eq('praefect-internal-2')
          expect(config.praefect.__nodes[2].__storages[0].path).to eq(Pathname.new('/home/git/gdk/repository_storages/praefect-gitaly-2/praefect-internal-2'))
        end
      end

      describe '#__praefect_build_bin_path' do
        it '/home/git/gdk/gitaly/_build/bin/praefect' do
          expect(config.praefect.__praefect_build_bin_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build/bin/praefect'))
        end
      end
    end
  end

  describe '#postgresql' do
    let(:yaml) do
      {
        'postgresql' => {
          'host' => 'localhost',
          'port' => 1234,
          'active_version' => '11.9',
          'geo' => {
            'host' => 'geo',
            'port' => 5678
          }
        }
      }
    end

    describe '#host' do
      it { expect(default_config.postgresql.host).to eq(default_config.postgresql.dir.to_s) }

      it 'returns configured value' do
        expect(config.postgresql.host).to eq('localhost')
      end
    end

    describe '#port' do
      it { expect(default_config.postgresql.port).to eq(5432) }

      it 'returns configured value' do
        expect(config.postgresql.port).to eq(1234)
      end
    end

    describe '#active_version' do
      it { expect(default_config.postgresql.active_version).to eq('12.6') }

      it 'returns configured value' do
        expect(config.postgresql.active_version).to eq('11.9')
      end
    end

    describe '#geo' do
      describe '#host' do
        it { expect(default_config.postgresql.host).to eq(default_config.postgresql.dir.to_s) }

        it 'returns configured value' do
          expect(config.postgresql.geo.host).to eq('geo')
        end
      end

      describe '#port' do
        it { expect(default_config.postgresql.geo.port).to eq(5431) }

        it 'returns configured value' do
          expect(config.postgresql.geo.port).to eq(5678)
        end
      end
    end
  end

  describe '#gitaly' do
    let(:praefect_enabled) { false }
    let(:storage_count) { 3 }
    let(:yaml) do
      {
        'gitaly' => {
          'storage_count' => storage_count
        },
        'praefect' => {
          'enabled' => praefect_enabled
        }
      }
    end

    describe '#dir' do
      it 'returns the gitaly directory' do
        expect(config.gitaly.dir).to eq(Pathname.new('/home/git/gdk/gitaly'))
      end
    end

    describe '#ruby_dir' do
      it 'returns the ruby directory under gitaly' do
        expect(config.gitaly.ruby_dir).to eq(Pathname.new('/home/git/gdk/gitaly/ruby'))
      end
    end

    describe '#enabled' do
      context 'when praefect is disabled' do
        let(:storage_count) { 1 }

        it { expect(config.gitaly).to be_enabled }
      end

      context 'when praefect is enabled' do
        let(:praefect_enabled) { true }

        context 'when there is 1 storage' do
          let(:storage_count) { 1 }

          it { expect(config.gitaly).not_to be_enabled }
        end

        context 'when there is more than 1 storage' do
          it { expect(config.gitaly).to be_enabled }
        end
      end
    end

    describe '#__storages' do
      it 'has defaults' do
        expect(default_config.gitaly.__storages.length).to eq(1)
        expect(default_config.gitaly.__storages[0].name).to eq('default')
        expect(default_config.gitaly.__storages[0].path).to eq(Pathname.new('/home/git/gdk/repositories'))
      end

      it 'returns the configured value' do
        expect(config.gitaly.__storages.length).to eq(3)
        expect(config.gitaly.__storages[0].name).to eq('default')
        expect(config.gitaly.__storages[0].path).to eq(Pathname.new('/home/git/gdk/repositories'))
        expect(config.gitaly.__storages[1].name).to eq('gitaly-1')
        expect(config.gitaly.__storages[1].path).to eq(Pathname.new('/home/git/gdk/repository_storages/gitaly/gitaly-1'))
        expect(config.gitaly.__storages[2].name).to eq('gitaly-2')
        expect(config.gitaly.__storages[2].path).to eq(Pathname.new('/home/git/gdk/repository_storages/gitaly/gitaly-2'))
      end
    end

    describe 'auth_token' do
      it 'is not set by default' do
        expect(config.gitaly.auth_token).to be('')
      end
    end

    describe '#git_bin_path' do
      it 'returns the path to the gitaly compiled git binary' do
        expect(config.gitaly.git_bin_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build/deps/git/install/bin/git'))
      end
    end

    describe '#__build_path' do
      it '/home/git/gdk/gitaly/_build' do
        expect(config.gitaly.__build_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build'))
      end
    end

    describe '#__build_bin_path' do
      it '/home/git/gdk/gitaly/_build/bin' do
        expect(config.gitaly.__build_bin_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build/bin'))
      end
    end

    describe '#__build_deps_path' do
      it '/home/git/gdk/gitaly/_build/deps' do
        expect(config.gitaly.__build_deps_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build/deps'))
      end
    end

    describe '#__gitaly_build_bin_path' do
      it '/home/git/gdk/gitaly/_build/bin/gitaly' do
        expect(config.gitaly.__gitaly_build_bin_path).to eq(Pathname.new('/home/git/gdk/gitaly/_build/bin/gitaly'))
      end
    end
  end

  context 'geo' do
    describe '#enabled' do
      it 'returns false be default' do
        expect(config.geo.enabled?).to be false
      end

      context 'when enabled in config file' do
        let(:yaml) do
          { 'geo' => { 'enabled' => true } }
        end

        it 'returns true' do
          expect(config.geo.enabled?).to be true
        end
      end
    end

    describe '#secondary?' do
      it 'returns false be default' do
        expect(config.geo.secondary?).to be false
      end

      context 'when enabled in config file' do
        let(:yaml) do
          { 'geo' => { 'secondary' => true } }
        end

        it 'returns true' do
          expect(config.geo.secondary?).to be true
        end
      end
    end

    describe '#registry_replication' do
      describe '#enabled' do
        it 'returns false be default' do
          expect(config.geo.registry_replication.enabled).to be false
        end

        context 'when enabled in config file' do
          let(:yaml) do
            {
              'geo' => { 'registry_replication' => { "enabled" => true } }
            }
          end

          it 'returns true' do
            expect(config.geo.registry_replication.enabled).to be true
          end
        end
      end

      describe '#primary_api_url' do
        it 'returns default URL' do
          expect(config.geo.registry_replication.primary_api_url).to eq('http://localhost:5000')
        end

        context 'when URL is specified' do
          let(:yaml) do
            {
              'geo' => { 'registry_replication' => { "primary_api_url" => 'http://localhost:5001' } }
            }
          end

          it 'returns URL from configuration file' do
            expect(config.geo.registry_replication.primary_api_url).to eq('http://localhost:5001')
          end
        end
      end
    end
  end

  describe '#config_file_protected?' do
    subject { config.config_file_protected?('foobar') }

    context 'with full wildcard protected_config_files' do
      let(:protected_config_files) { ['*'] }

      it 'returns true' do
        expect(config.config_file_protected?('foobar')).to eq(true)
      end

      context 'but legacy overwrite_changes set to true' do
        let(:overwrite_changes) { true }

        it 'returns false' do
          expect(config.config_file_protected?('foobar')).to eq(false)
        end
      end
    end
  end

  describe 'runner' do
    before do
      allow_any_instance_of(GDK::ConfigSettings).to receive(:read!).with(config.runner.config_file) { file_contents }
    end

    describe '#extra_hosts' do
      it 'returns []' do
        expect(config.runner.extra_hosts).to eq([])
      end
    end

    describe '#bin' do
      it 'returns gitlab-runner' do
        found = find_executable('gitlab-runner')
        path = found || '/usr/local/bin/gitlab-runner'
        expect(config.runner.bin).to eq(Pathname.new(path))
      end
    end

    describe 'network_mode_host' do
      it 'is disabled by default' do
        expect(config.runner.network_mode_host).to be(false)
      end
    end

    describe '__network_mode_host' do
      context 'when not set in gdk.yml' do
        it 'is disabled by default' do
          expect(config.runner.__network_mode_host).to be(false)
        end
      end

      context 'when enabled in gdk.yml' do
        before do
          yaml['runner'] = {
            'network_mode_host' => 'true'
          }

          allow(RbConfig::CONFIG).to receive(:[]).and_call_original
          allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
        end

        context 'on a macOS system' do
          let(:host_os) { 'darwin' }

          it 'raise an exception' do
            expect { config.runner.__network_mode_host }.to raise_error('runner.network_mode_host is only supported on Linux')
          end
        end

        context 'on a Linux system' do
          let(:host_os) { 'linux' }

          it 'returns true' do
            expect(config.runner.__network_mode_host).to be(true)
          end
        end
      end
    end

    context 'when config_file exists' do
      let(:file_contents) do
        <<~CONTENTS
          concurrent = 1
          check_interval = 0

          [session_server]
            session_timeout = 1800

          [[runners]]
            name = "MyRunner"
            url = "http://example.com"
            token = "XXXXXXXXXX"
            executor = "docker"
            [runners.custom_build_dir]
            [runners.docker]
              tls_verify = false
              image = "ruby:2.6"
              privileged = false
              disable_entrypoint_overwrite = false
              oom_kill_disable = false
              disable_cache = false
              volumes = ["/cache"]
              shm_size = 0
            [runners.cache]
              [runners.cache.s3]
              [runners.cache.gcs]
        CONTENTS
      end

      describe 'enabled' do
        it 'returns true' do
          expect(config.runner.enabled).to be(true)
        end
      end
    end

    context 'when config_file does not exist' do
      let(:file_contents) { nil }

      describe 'enabled' do
        it 'is disabled by default' do
          expect(config.runner.enabled).to be(false)
        end
      end
    end
  end

  describe '#listen_address' do
    it 'returns 127.0.0.1 by default' do
      expect(config.listen_address).to eq('127.0.0.1')
    end
  end

  describe 'gitlab' do
    describe 'auto_update' do
      it 'is enabled by default' do
        expect(config.gitlab.auto_update).to be(true)
        expect(config.gitlab.auto_update?).to be(true)
      end
    end

    describe '#dir' do
      it 'returns the GitLab directory' do
        expect(config.gitlab.dir).to eq(Pathname.new('/home/git/gdk/gitlab'))
      end
    end

    describe '#cache_classes' do
      it 'returns if Ruby classes should be cached' do
        expect(config.gitlab.cache_classes).to be(false)
      end
    end

    describe 'rails' do
      describe '#__socket_file' do
        it 'returns the GitLab socket path' do
          expect(config.gitlab.rails.__socket_file).to eq(Pathname.new('/home/git/gdk/gitlab.socket'))
        end
      end

      describe '#__socket_file_escaped' do
        it 'returns the GitLab socket path CGI escaped' do
          expect(config.gitlab.rails.__socket_file_escaped.to_s).to eq('%2Fhome%2Fgit%2Fgdk%2Fgitlab.socket')
        end
      end

      describe '#listen_settings' do
        it 'defaults to UNIX socket' do
          expect(config.gitlab.rails.address).to eq('')
          expect(config.gitlab.rails.__bind).to eq('unix:///home/git/gdk/gitlab.socket')
          expect(config.gitlab.rails.__workhorse_url).to eq('/home/git/gdk/gitlab.socket')
          expect(config.gitlab.rails.__listen_settings.__protocol).to eq('unix')
          expect(config.gitlab.rails.__listen_settings.__address).to eq('/home/git/gdk/gitlab.socket')
          expect(config.workhorse.__listen_settings.__type).to eq('authSocket')
          expect(config.workhorse.__listen_settings.__address).to eq('/home/git/gdk/gitlab.socket')
        end
      end

      context 'with TCP address' do
        before do
          yaml['gitlab'] = {
            'rails' => {
              'address' => 'localhost:3443'
            }
          }
        end

        it 'sets listen_settings to HTTP port' do
          expect(config.gitlab.rails.address).to eq('localhost:3443')
          expect(config.gitlab.rails.__bind).to eq('tcp://localhost:3443')
          expect(config.gitlab.rails.__workhorse_url).to eq('http://localhost:3443')
          expect(config.gitlab.rails.__listen_settings.__protocol).to eq('tcp')
          expect(config.gitlab.rails.__listen_settings.__address).to eq('localhost:3443')
          expect(config.workhorse.__listen_settings.__type).to eq('authBackend')
          expect(config.workhorse.__listen_settings.__address).to eq('http://localhost:3443')
        end
      end

      describe 'sherlock' do
        it 'is disabled by default' do
          expect(config.gitlab.rails.sherlock).to be(false)
        end
      end

      describe 'puma' do
        describe 'threads_min' do
          it 'is 1 by default' do
            expect(config.gitlab.rails.puma.threads_min).to be(1)
          end
        end

        describe '__threads_min' do
          context 'when running in clustered mode (workers > 0)' do
            before do
              yaml['gitlab'] = {
                'rails' => {
                  'puma' => {
                    'workers' => 2
                  }
                }
              }
            end

            it 'is 1 by default' do
              expect(config.gitlab.rails.puma.__threads_min).to be(1)
            end
          end

          context 'when running in single mode (workers == 0)' do
            before do
              yaml['gitlab'] = {
                'rails' => {
                  'puma' => {
                    'workers' => 0
                  }
                }
              }
            end

            it 'is equal to threads_max' do
              expect(config.gitlab.rails.puma.__threads_min).to be(config.gitlab.rails.puma.threads_max)
            end
          end
        end

        describe 'threads_max' do
          it 'is 4 by default' do
            expect(config.gitlab.rails.puma.threads_max).to be(4)
          end
        end

        describe '__threads_max' do
          let(:threads_max) { nil }

          before do
            yaml['gitlab'] = {
              'rails' => {
                'puma' => {
                  'threads_min' => 2,
                  'threads_max' => threads_max
                }
              }
            }
          end

          context 'when threads_max > threads_min' do
            let(:threads_max) { 3 }

            it 'is equal to threads_max' do
              expect(config.gitlab.rails.puma.__threads_max).to be(config.gitlab.rails.puma.threads_max)
            end
          end

          context 'when threads_max < threads_min' do
            let(:threads_max) { 1 }

            it 'is equal to threads_min' do
              expect(config.gitlab.rails.puma.__threads_max).to be(config.gitlab.rails.puma.threads_min)
            end
          end
        end

        describe 'workers' do
          it 'is 2 by default' do
            expect(config.gitlab.rails.puma.workers).to be(2)
          end
        end
      end
    end

    describe 'actioncable' do
      describe '#__socket_file' do
        it 'returns the GitLab socket path' do
          expect(config.gitlab.actioncable.__socket_file).to eq(Pathname.new('/home/git/gdk/gitlab.socket'))
        end

        context 'when ActionCable in-app mode is disabled' do
          let(:yaml) do
            {
              'action_cable' => { 'in_app' => false }
            }
          end

          it 'returns the GitLab ActionCable socket path' do
            expect(config.gitlab.actioncable.__socket_file).to eq(Pathname.new('/home/git/gdk/gitlab.actioncable.socket'))
          end
        end
      end
    end
  end

  describe 'k8s_agent' do
    describe 'enabled' do
      it 'is disabled by default' do
        expect(config.gitlab_k8s_agent.enabled).to be(false)
      end
    end

    describe 'auto_update' do
      it 'is enabled by default' do
        expect(config.gitlab_k8s_agent.auto_update).to be(true)
      end
    end

    describe 'agent_listen_network' do
      it 'is tcp by default' do
        expect(config.gitlab_k8s_agent.agent_listen_network).to eq('tcp')
      end
    end

    describe 'agent_listen_address' do
      it 'is 127.0.0.1:8150 by default' do
        expect(config.gitlab_k8s_agent.agent_listen_address).to eq('127.0.0.1:8150')
      end
    end

    describe '__agent_listen_url_path' do
      it 'is /-/kubernetes-agent by default' do
        expect(config.gitlab_k8s_agent.__agent_listen_url_path).to eq('/-/kubernetes-agent')
      end
    end

    describe 'private_api_listen_network' do
      it 'is tcp by default' do
        expect(config.gitlab_k8s_agent.private_api_listen_network).to eq('tcp')
      end
    end

    describe 'private_api_listen_address' do
      it 'is 127.0.0.1:8155 by default' do
        expect(config.gitlab_k8s_agent.private_api_listen_address).to eq('127.0.0.1:8155')
      end
    end

    describe 'k8s_api_listen_network' do
      it 'is tcp by default' do
        expect(config.gitlab_k8s_agent.k8s_api_listen_network).to eq('tcp')
      end
    end

    describe 'k8s_api_listen_address' do
      it 'is 127.0.0.1:8154 by default' do
        expect(config.gitlab_k8s_agent.k8s_api_listen_address).to eq('127.0.0.1:8154')
      end
    end

    describe '__k8s_api_listen_url_path' do
      it 'is /-/k8s-proxy by default' do
        expect(config.gitlab_k8s_agent.__k8s_api_listen_url_path).to eq('/-/k8s-proxy')
      end
    end

    describe '__gitlab_address' do
      it 'is http://gdk.example.com:3000 by default' do
        expect(config.gitlab_k8s_agent.__gitlab_address).to eq('http://gdk.example.com:3000')
      end
    end

    describe '__url_for_agentk' do
      let(:https_enabled) { nil }

      let(:yaml) do
        {
          'nginx' => { 'enabled' => nginx_enabled },
          'https' => { 'enabled' => https_enabled }
        }
      end

      context 'when nginx is not enabled' do
        let(:nginx_enabled) { false }

        it 'is grpc://127.0.0.1:8150' do
          expect(config.gitlab_k8s_agent.__url_for_agentk).to eq('grpc://127.0.0.1:8150')
        end
      end

      context 'when nginx is enabled' do
        let(:nginx_enabled) { true }

        context 'but https is not enabled' do
          let(:https_enabled) { false }

          it 'is ws://127.0.0.1:3000/-/kubernetes-agent' do
            expect(config.gitlab_k8s_agent.__url_for_agentk).to eq('ws://127.0.0.1:3000/-/kubernetes-agent')
          end
        end

        context 'and https is enabled' do
          let(:https_enabled) { true }

          it 'is wss://127.0.0.1:3000/-/kubernetes-agent' do
            expect(config.gitlab_k8s_agent.__url_for_agentk).to eq('wss://127.0.0.1:3000/-/kubernetes-agent')
          end
        end
      end
    end

    describe 'internal_api_listen_network' do
      it 'is tcp by default' do
        expect(config.gitlab_k8s_agent.internal_api_listen_network).to eq('tcp')
      end
    end

    describe 'internal_api_listen_address' do
      it 'is 127.0.0.1:8153 by default' do
        expect(config.gitlab_k8s_agent.internal_api_listen_address).to eq('127.0.0.1:8153')
      end
    end

    describe '__internal_api_url' do
      let(:yaml) do
        {
          'gitlab_k8s_agent' => { 'internal_api_listen_network' => internal_api_listen_network }
        }
      end

      context 'when internal_api_listen_network is tcp' do
        let(:internal_api_listen_network) { 'tcp' }

        it 'is grpc://127.0.0.1:8153' do
          expect(config.gitlab_k8s_agent.__internal_api_url).to eq('grpc://127.0.0.1:8153')
        end
      end

      context 'when internal_api_listen_network is unix' do
        let(:internal_api_listen_network) { 'unix' }

        it 'is unix://127.0.0.1:8153' do
          expect(config.gitlab_k8s_agent.__internal_api_url).to eq('unix://127.0.0.1:8153')
        end
      end
    end
  end

  describe 'nginx' do
    describe '#__listen_address' do
      let(:yaml) do
        {
          'port' => 1234,
          'nginx' => { 'listen' => 'localhost' }
        }
      end

      it 'is set to ip and port' do
        expect(config.nginx.__listen_address).to eq('localhost:1234')
      end
    end

    describe '#__request_buffering_off_routes' do
      it 'has some defailt routes' do
        expected_routes = [
          '/api/v\d/jobs/\d+/artifacts$',
          '\.git/git-receive-pack$',
          '\.git/gitlab-lfs/objects',
          '\.git/info/lfs/objects/batch$'
        ]

        expect(config.nginx.__request_buffering_off_routes).to eq(expected_routes)
      end
    end
  end

  describe 'gitlab_elasticsearch_indexer' do
    describe '#__dir' do
      it 'returns the GitLab directory' do
        expect(config.gitlab_elasticsearch_indexer.__dir).to eq(Pathname.new('/home/git/gdk/gitlab-elasticsearch-indexer'))
      end
    end
  end

  describe 'load_balancing' do
    it 'disabled by default' do
      expect(config.load_balancing.enabled).to be false
    end
  end

  describe 'gitlab_ui' do
    describe 'enabled' do
      it 'is disabled by default' do
        expect(config.gitlab_ui.enabled).to be(false)
      end
    end

    describe 'auto_update' do
      it 'is enabled by default' do
        expect(config.gitlab_ui.auto_update).to be(true)
      end
    end
  end

  describe 'webpack' do
    describe '#incremental' do
      it 'is false by default' do
        expect(config.webpack.incremental).to be false
      end
    end

    describe '#vendor_dll' do
      it 'is false by default' do
        expect(config.webpack.vendor_dll).to be false
      end
    end

    describe '#static' do
      it 'is false by default' do
        expect(config.webpack.static).to be false
      end
    end

    describe '#sourcemaps' do
      it 'is true by default' do
        expect(config.webpack.sourcemaps).to be true
      end
    end

    describe '#live_reload' do
      context 'when https is disabled' do
        before do
          yaml['https'] = { 'enabled' => false }
        end

        it 'is true' do
          expect(config.webpack.live_reload).to be true
        end
      end

      context 'when https is enabled' do
        before do
          yaml['https'] = { 'enabled' => true }
        end

        it 'is false' do
          expect(config.webpack.live_reload).to be false
        end
      end
    end
  end

  describe 'action_cable' do
    describe '#in_app' do
      it 'is true by default' do
        expect(config.action_cable.in_app).to be true
      end
    end

    describe '#worker_pool_size' do
      it 'returns 4 by deftault' do
        expect(config.action_cable.worker_pool_size).to eq 4
      end
    end
  end

  describe 'registry' do
    describe '#image' do
      context 'when no image is specified' do
        it 'returns the default image' do
          expect(config.registry.image).to eq('registry.gitlab.com/gitlab-org/build/cng/gitlab-container-registry:v2.9.1-gitlab')
        end
      end
    end

    describe '#api_host' do
      it 'returns the default hostname' do
        expect(config.registry.api_host).to eq('gdk.example.com')
      end
    end

    describe '#listen_address' do
      it 'returns 127.0.0.1 by default' do
        expect(config.registry.listen_address).to eq('127.0.0.1')
      end
    end

    describe '#uid' do
      it 'returns an empty string' do
        expect(config.registry.uid).to eq('')
      end
    end

    describe '#gid' do
      it 'returns an empty string' do
        expect(config.registry.gid).to eq('')
      end
    end
  end

  describe 'object_store' do
    describe '#host' do
      it 'returns the default hostname' do
        expect(config.object_store.host).to eq('127.0.0.1')
      end
    end

    describe '#connection' do
      context 'default settings' do
        let(:default_connection) do
          {
            'provider' => 'AWS',
            'aws_access_key_id' => 'minio',
            'aws_secret_access_key' => 'gdk-minio',
            'region' => 'gdk',
            'endpoint' => "http://127.0.0.1:9000",
            'path_style' => true
          }
        end

        it 'returns the default Minio connection parameters' do
          expect(config.object_store.connection).to eq(default_connection)
        end
      end

      context 'with external S3 provider' do
        let(:s3_connection) do
          {
            'provider' => 'AWS',
            'aws_access_key_id' => 'test_access_key',
            'aws_secret_access_key' => 'secret'
          }
        end

        before do
          yaml.merge!(
            {
              'object_store' => {
                'enabled' => true,
                'connection' => s3_connection
              }
            }
          )
        end

        it 'configures the S3 provider' do
          expect(config.object_store.enabled?).to be true
          expect(config.object_store.connection).to eq(s3_connection)
        end
      end
    end
  end

  describe 'omniauth' do
    context 'defaults' do
      it 'returns false' do
        expect(config.omniauth.google_oauth2.enabled).to eq('')
        expect(config.omniauth.group_saml.enabled).to be false
        expect(config.omniauth.github.enabled).to be false
      end
    end

    context 'when group SAML is disabled' do
      it 'returns false' do
        expect(config.omniauth.group_saml.enabled).to be false
      end
    end

    context 'when group SAML is enabled' do
      let(:group_saml_enabled) { true }

      it 'returns true' do
        expect(config.omniauth.group_saml.enabled).to be true
      end
    end

    context 'when GitHub is enabled' do
      let(:omniauth_config) { { 'github' => { 'enabled' => true, 'client_id' => '12345', 'client_secret' => 'mysecret' } } }

      it 'returns true' do
        expect(config.omniauth.github.enabled).to be true
        expect(config.omniauth.github.client_id).to eq('12345')
        expect(config.omniauth.github.client_secret).to eq('mysecret')
      end
    end
  end

  describe 'gitlab_pages' do
    describe '#enabled' do
      it 'defaults to false' do
        expect(config.gitlab_pages.enabled).to eq(false)
        expect(config.gitlab_pages.enabled?).to eq(false)
      end
    end

    describe '#host' do
      context 'when host is not specified' do
        it 'returns the default hostname' do
          expect(config.gitlab_pages.host).to eq('127.0.0.1.nip.io')
        end
      end

      context 'when host is specified' do
        let(:yaml) do
          {
            'gitlab_pages' => { 'host' => 'pages.localhost' }
          }
        end

        it 'returns the configured hostname' do
          expect(config.gitlab_pages.host).to eq('pages.localhost')
        end
      end
    end

    describe '#port' do
      context 'when port is not specified' do
        it 'returns the default port' do
          expect(config.gitlab_pages.port).to eq(3010)
        end
      end

      context 'when port is specified' do
        let(:yaml) do
          {
            'gitlab_pages' => { 'port' => 5555 }
          }
        end

        it 'returns the configured port' do
          expect(config.gitlab_pages.port).to eq(5555)
        end
      end
    end

    describe '#__uri' do
      it 'returns 127.0.0.1.nip.io:3010' do
        expect(config.gitlab_pages.__uri.to_s).to eq('127.0.0.1.nip.io:3010')
      end
    end

    describe '#access_control' do
      it 'defaults to false' do
        expect(config.gitlab_pages.access_control?).to eq(false)
      end

      context 'when access_control is enabled' do
        let(:yaml) do
          {
            'gitlab_pages' => { 'access_control' => true, 'auth_client_id' => 'client_id', 'auth_client_secret' => 'client_secret' }
          }
        end

        it 'configures auth correctly' do
          expect(config.gitlab_pages.access_control?).to eq(true)
          expect(config.gitlab_pages.auth_client_id).to eq('client_id')
          expect(config.gitlab_pages.auth_client_secret).to eq('client_secret')
          expect(config.gitlab_pages.__auth_secret.length).to eq(32)
          expect(config.gitlab_pages.__auth_redirect_uri).to eq('http://127.0.0.1.nip.io:3010/auth')
        end
      end
    end
  end

  describe 'prometheus' do
    describe '#enabled' do
      it 'defaults to false' do
        expect(config.prometheus.enabled).to eq(false)
      end
    end

    describe '#port' do
      it 'defaults to 9090' do
        expect(config.prometheus.port).to eq(9090)
      end
    end

    describe '#gitaly_exporter_port' do
      it 'defaults to 9236' do
        expect(config.prometheus.gitaly_exporter_port).to eq(9236)
      end
    end

    describe '#praefect_exporter_port' do
      it 'defaults to 10101' do
        expect(config.prometheus.praefect_exporter_port).to eq(10101)
      end
    end

    describe '#sidekiq_exporter_port' do
      it 'defaults to' do
        expect(config.prometheus.sidekiq_exporter_port).to eq(3807)
      end
    end
  end

  describe 'grafana' do
    describe '#enabled' do
      it 'defaults to false' do
        expect(config.grafana.enabled).to eq(false)
        expect(config.grafana.enabled?).to eq(false)
      end
    end

    describe '#port' do
      it 'defaults to 4000' do
        expect(config.grafana.port).to eq(4000)
      end
    end
  end

  describe 'gdk' do
    describe '#quiet' do
      it 'defaults to true' do
        expect(config.gdk.quiet).to eq(true)
        expect(config.gdk.quiet?).to eq(true)
      end
    end

    describe '#auto_reconfigure' do
      it 'defaults to true' do
        expect(config.gdk.auto_reconfigure).to eq(true)
        expect(config.gdk.auto_reconfigure?).to eq(true)
      end
    end

    describe '#runit_wait_secs' do
      it 'is 20 secs by default' do
        expect(config.gdk.runit_wait_secs).to eq(20)
      end
    end

    describe '#start_hooks' do
      describe '#before' do
        it 'is an empty array by default' do
          expect(config.gdk.start_hooks.before).to eq([])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'start_hooks' => { 'before' => ['uptime'] } } }
          end

          it 'replaces hooks with ours' do
            expect(config.gdk.start_hooks.before).to eq(['uptime'])
          end
        end
      end

      describe '#after' do
        it 'is an empty array by default' do
          expect(config.gdk.start_hooks.after).to eq([])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'start_hooks' => { 'after' => ['uptime'] } } }
          end

          it 'replaces hooks with ours' do
            expect(config.gdk.start_hooks.after).to eq(['uptime'])
          end
        end
      end
    end

    describe '#stop_hooks' do
      describe '#before' do
        it 'is an empty array by default' do
          expect(config.gdk.stop_hooks.before).to eq([])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'stop_hooks' => { 'before' => ['uptime'] } } }
          end

          it 'replaces hooks with ours' do
            expect(config.gdk.stop_hooks.before).to eq(['uptime'])
          end
        end
      end

      describe '#after' do
        it 'is an empty array by default' do
          expect(config.gdk.stop_hooks.after).to eq([])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'stop_hooks' => { 'after' => ['uptime'] } } }
          end

          it 'replaces hooks with ours' do
            expect(config.gdk.stop_hooks.after).to eq(['uptime'])
          end
        end
      end
    end

    describe '#update_hooks' do
      describe '#before' do
        it 'has spring stop || true hook by default' do
          expect(config.gdk.update_hooks.before).to eq(['cd gitlab && bin/spring stop || true'])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'update_hooks' => { 'before' => ['uptime'] } } }
          end

          it 'has spring stop || true hook and then our hooks also' do
            expect(config.gdk.update_hooks.before).to eq(['cd gitlab && bin/spring stop || true', 'uptime'])
          end
        end
      end

      describe '#after' do
        it 'is an empty array by default' do
          expect(config.gdk.update_hooks.after).to eq([])
        end

        context 'with custom hooks defined' do
          let(:yaml) do
            { 'gdk' => { 'update_hooks' => { 'after' => ['uptime'] } } }
          end

          it 'replaces hooks with ours' do
            expect(config.gdk.update_hooks.after).to eq(['uptime'])
          end
        end
      end
    end
  end

  describe 'tracer' do
    describe 'build_tags' do
      it "is 'tracer_static tracer_static_jaeger' by default" do
        expect(config.tracer.build_tags).to eq('tracer_static tracer_static_jaeger')
      end
    end

    describe 'jaeger' do
      subject(:jaeger) { config.tracer.jaeger }

      describe 'enabled' do
        it 'is disabled by default' do
          expect(jaeger.enabled).to be(false)
          expect(jaeger.enabled?).to be(false)
        end
      end

      describe 'version' do
        it 'is 1.21.0 by default' do
          expect(jaeger.version).to eq('1.21.0')
        end
      end

      describe 'listen_address' do
        it 'is config.hostname by default' do
          expect(jaeger.listen_address).to eq(config.hostname)
        end
      end

      describe '__tracer_url' do
        it { expect(jaeger.__tracer_url).to eq("opentracing://jaeger?http_endpoint=http%3A%2F%2F#{jaeger.listen_address}%3A14268%2Fapi%2Ftraces&sampler=const&sampler_param=1") }
      end

      describe '__search_url' do
        it { expect(jaeger.__search_url).to eq("http://#{jaeger.listen_address}:16686/search?service={{ service }}&tags=%7B%22correlation_id%22%3A%22{{ correlation_id }}%22%7D") }
      end
    end
  end

  describe 'asdf' do
    describe 'opt_out' do
      it 'is disabled by default' do
        expect(config.asdf.opt_out).to be(false)
        expect(config.asdf.opt_out?).to be(false)
      end
    end
  end

  describe 'gitlab_docs' do
    describe 'enabled' do
      it 'is disabled by default' do
        expect(config.gitlab_docs.enabled).to be(false)
        expect(config.gitlab_docs.enabled?).to be(false)
        expect(config.gitlab_docs?).to be(false)
      end
    end

    describe 'auto_update' do
      it 'is enabled by default' do
        expect(config.gitlab_docs.auto_update).to be(true)
        expect(config.gitlab_docs.auto_update?).to be(true)
      end
    end

    describe '#port' do
      context 'when port is not specified' do
        it 'returns the default port' do
          expect(config.gitlab_docs.port).to eq(3005)
        end
      end

      context 'when port is specified' do
        let(:yaml) do
          {
            'gitlab_docs' => { 'port' => 5555 }
          }
        end

        it 'returns the configured port' do
          expect(config.gitlab_docs.port).to eq(5555)
        end
      end
    end

    describe '__all_configured' do
      context 'when all documentation projects enabled' do
        let(:yaml) do
          {
            'gitlab_docs' => { 'enabled' => true },
            'gitlab_runner' => { 'enabled' => true },
            'omnibus_gitlab' => { 'enabled' => true },
            'charts_gitlab' => { 'enabled' => true }
          }
        end

        it 'returns true' do
          expect(config.gitlab_docs.__all_configured?).to be(true)
        end
      end

      context 'when all documentation projects not enabled' do
        let(:yaml) do
          {
            'gitlab_docs' => { 'enabled' => true },
            'gitlab_runner' => { 'enabled' => true },
            'omnibus_gitlab' => { 'enabled' => false },
            'charts_gitlab' => { 'enabled' => true }
          }
        end

        it 'returns false' do
          expect(config.gitlab_docs.__all_configured?).to be(false)
        end
      end

      describe '__nanoc_cmd_common' do
        context 'when GDK host and GitLab Docs port not configured' do
          let(:yaml) do
            {
            }
          end

          it 'nanoc is passed default options' do
            expect(config.gitlab_docs.__nanoc_cmd_common).to eq('--host 127.0.0.1 --port 3005')
          end
        end

        context 'when GDK host and GitLab Docs port are configured' do
          let(:yaml) do
            {
              'hostname' => 'gdk.test.com',
              'gitlab_docs' => { 'port' => 5555 }
            }
          end

          it 'nanoc is passed configured options' do
            expect(config.gitlab_docs.__nanoc_cmd_common).to eq('--host gdk.test.com --port 5555')
          end
        end
      end
    end

    describe 'gitlab_runner' do
      describe 'enabled' do
        it 'is disabled by default' do
          expect(config.gitlab_runner.enabled).to be(false)
          expect(config.gitlab_runner.enabled?).to be(false)
        end
      end

      describe 'auto_update' do
        it 'is enabled by default' do
          expect(config.gitlab_runner.auto_update).to be(true)
          expect(config.gitlab_runner.auto_update?).to be(true)
        end
      end
    end

    describe 'omnibus_gitlab' do
      describe 'enabled' do
        it 'is disabled by default' do
          expect(config.omnibus_gitlab.enabled).to be(false)
          expect(config.omnibus_gitlab.enabled?).to be(false)
        end
      end

      describe 'auto_update' do
        it 'is enabled by default' do
          expect(config.omnibus_gitlab.auto_update).to be(true)
          expect(config.omnibus_gitlab.auto_update?).to be(true)
        end
      end
    end

    describe 'charts_gitlab' do
      describe 'enabled' do
        it 'is disabled by default' do
          expect(config.charts_gitlab.enabled).to be(false)
          expect(config.charts_gitlab.enabled?).to be(false)
        end
      end

      describe 'auto_update' do
        it 'is enabled by default' do
          expect(config.charts_gitlab.auto_update).to be(true)
          expect(config.charts_gitlab.auto_update?).to be(true)
        end
      end
    end
  end

  describe 'packages' do
    describe '__dpkg_deb_path' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).and_call_original
        allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
      end

      context 'on a macOS system' do
        let(:host_os) { 'darwin' }

        it 'returns /usr/local/bin/dpkg-deb' do
          expect(config.packages.__dpkg_deb_path.to_s).to eq('/usr/local/bin/dpkg-deb')
        end
      end

      context 'on a Linux system' do
        let(:host_os) { 'linux' }

        it 'returns /usr/bin/dpkg-deb' do
          expect(config.packages.__dpkg_deb_path.to_s).to eq('/usr/bin/dpkg-deb')
        end
      end
    end
  end

  describe 'dev' do
    describe 'shellcheck' do
      describe 'version' do
        it 'returns 0.7.2 by default' do
          expect(config.dev.shellcheck.version).to eq('0.7.2')
        end
      end
    end

    describe 'vale' do
      describe 'version' do
        it 'returns 2.10.3 by default' do
          expect(config.dev.vale.version).to eq('2.10.3')
        end
      end
    end
  end
end
