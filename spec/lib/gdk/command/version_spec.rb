# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Version do
  describe '#run' do
    it 'returns GitLab Development Kit 0.2.12 (abc123)' do
      stub_const('GDK::VERSION', 'GitLab Development Kit 0.2.12')
      shellout_double = instance_double(Shellout)
      allow(Shellout).to receive(:new).with('git rev-parse --short HEAD', chdir: GDK.root).and_return(shellout_double)
      allow(shellout_double).to receive(:run).and_return('abc123')

      expect { subject.run }.to output("GitLab Development Kit 0.2.12 (abc123)\n").to_stdout
    end
  end
end
