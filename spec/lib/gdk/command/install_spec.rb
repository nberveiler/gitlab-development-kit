# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Install do
  let(:args) { [] }

  context 'when install fails' do
    it 'returns an error message' do
      allow(GDK).to receive(:make).with('install')

      expect { subject.run(args) }.to output(/Failed to install/).to_stderr.and output(/You can try the following that may be of assistance/).to_stdout
    end
  end

  context 'when install succeeds' do
    it 'finishes without problem' do
      allow(GDK).to receive(:make).with('install').and_return('Some output')

      expect { subject.run(args) }.not_to raise_error
    end
  end
end
