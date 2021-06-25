# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Reconfigure do
  context 'with GDK executable injected methods' do
    it 'calls remember!' do
      allow(GDK).to receive(:make).with('reconfigure').and_return('Some output')

      subject.run
    end
  end

  context 'when reconfiguration fails' do
    it 'returns an error message' do
      allow(GDK).to receive(:make).with('reconfigure')

      expect { subject.run }.to output(/Failed to reconfigure/).to_stderr.and output(/You can try the following that may be of assistance/).to_stdout
    end
  end

  context 'when reconfiguration succeeds' do
    it 'finishes without problem' do
      allow(GDK).to receive(:make).with('reconfigure').and_return('Some output')

      expect { subject.run }.not_to raise_error
    end
  end
end
