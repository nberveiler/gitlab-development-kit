# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/git/configure'

describe Git::Configure, :hide_stdout do
  describe '#run!' do
    it 'validates an incorrect value' do
      allow($stdin).to receive(:gets).and_return("bleep\n")

      expect { subject.run! }.to output(/Invalid input: bleep/).to_stderr.and raise_error(/Invalid input: bleep/)
    end

    it 'succeeds' do
      allow($stdin).to receive(:gets).and_return("\n")

      subject.run!
    end
  end
end
