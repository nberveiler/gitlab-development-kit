# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Runit::Config do
  let(:tmp_root) { File.expand_path('../../../tmp', __dir__) }
  let(:gdk_root) { Dir.mktmpdir(nil, tmp_root) }

  subject { described_class.new(gdk_root) }

  after do
    FileUtils.rm_rf(gdk_root)
  end

  describe '#stale_service_links' do
    let(:services) { [described_class::Service.new('svc1', nil), described_class::Service.new('svc2', nil)] }
    let(:services_dir) { File.join(gdk_root, 'services') }

    it 'removes unknown symlinks from the services directory' do
      FileUtils.mkdir_p(services_dir)

      %w[svc1 svc2 stale].each do |entry|
        File.symlink('/', File.join(services_dir, entry))
      end

      FileUtils.touch(File.join(services_dir, 'should-be-ignored'))

      expect(subject.stale_service_links(services)).to eq([File.join(services_dir, 'stale')])
    end
  end

  describe '#run_env', :aggregate_failures do
    it 'memoize output from generate_run_env' do
      expect(subject).to receive(:generate_run_env).once.and_call_original

      2.times { subject.run_env }
    end

    it 'exports GITLAB_TRACING related env variables when jaeger is enabled' do
      yaml = {
        'tracer' => {
          'jaeger' => {
            'enabled' => true
          }
        }
      }
      stub_gdk_yaml(yaml)

      expect(subject.run_env).to match(/GITLAB_TRACING=/)
      expect(subject.run_env).to match(/GITLAB_TRACING_URL=/)
    end

    it 'doesnt include GITLAB_TRACING related env variables when jaeger is disabled' do
      expect(subject.run_env).not_to match(/GITLAB_TRACING=/)
      expect(subject.run_env).not_to match(/GITLAB_TRACING_URL=/)
    end
  end
end
