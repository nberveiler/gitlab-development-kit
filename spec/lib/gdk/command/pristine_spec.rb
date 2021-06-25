# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Pristine do
  let(:config) { GDK.config }

  subject { described_class.new }

  describe '#run' do
    before do
      stub_tty(false)
    end

    context 'when a command fails' do
      it 'displays an error and returns false', :hide_stdout do
        expect(Runit).to receive(:stop).and_return(false)

        expect(GDK::Output).to receive(:error).with("Failed to run 'gdk pristine' - Had an issue with 'gdk_stop'.")

        expect(subject.run).to be(false)
      end
    end

    context 'when all commands succeed' do
      it 'displays an informational message and returns true', :hide_stdout do
        shellout_double = instance_double(Shellout, stream: nil, 'success?': true)

        # gdk_stop
        expect(Runit).to receive(:stop).and_return(true)

        # gdk_tmp_clean
        expect_shellout_command(described_class::GIT_CLEAN_TMP_CMD, config.gdk_root).and_return(shellout_double)

        # go_clean_cache
        expect_shellout_command(described_class::GO_CLEAN_CACHE_CMD, config.gdk_root).and_return(shellout_double)

        # gdk_bundle
        expect_shellout_command(described_class::BUNDLE_INSTALL_CMD, config.gdk_root).and_return(shellout_double)
        expect_shellout_command(described_class::BUNDLE_PRISTINE_CMD, config.gdk_root).and_return(shellout_double)

        # gitlab_bundle
        expect_shellout_command(described_class::BUNDLE_INSTALL_CMD, config.gitlab.dir).and_return(shellout_double)
        expect_shellout_command(described_class::BUNDLE_PRISTINE_CMD, config.gitlab.dir).and_return(shellout_double)

        # gitaly_bundle
        expect_shellout_command(described_class::BUNDLE_INSTALL_CMD, config.gitaly.ruby_dir).and_return(shellout_double)
        expect_shellout_command(described_class::BUNDLE_PRISTINE_CMD, config.gitaly.ruby_dir).and_return(shellout_double)

        # gitlab_tmp_clean
        expect_shellout_command(described_class::GIT_CLEAN_TMP_CMD, config.gitlab.dir).and_return(shellout_double)

        # gitlab_yarn_clean
        expect_shellout_command(described_class::YARN_CLEAN_CMD, config.gitlab.dir).and_return(shellout_double)

        expect(GDK::Output).to receive(:success).with("Successfully ran 'gdk pristine'!")

        expect(subject.run).to be(true)
      end
    end

    def expect_shellout_command(cmd, chdir)
      expect(Shellout).to receive(:new).with(cmd, chdir: chdir)
    end
  end
end
