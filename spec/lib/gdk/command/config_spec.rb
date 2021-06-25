# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Config do
  context 'with no extra argument' do
    it 'aborts execution and returns usage instructions' do
      expect { subject.run([]) }.to raise_error(SystemExit).and output(/Usage:/).to_stderr
    end
  end

  context 'with invalid extra arguments' do
    it 'aborts execution and returns usage instructions' do
      expect { subject.run(['non-existent-command']) }.to raise_error(SystemExit).and output(/Usage:/).to_stderr
    end
  end

  context 'with valid extra arguments' do
    it 'returns values retrieved from configuration store' do
      expect { subject.run(%w[get port]) }.to output(/3000/).to_stdout
    end

    context 'with nonexistent configuration keys' do
      it 'abort execution and returns an error when configuration keys cant be found' do
        expect { subject.run(%w[get unknownkey]) }.to raise_error(SystemExit).and output(/Cannot get config for/).to_stderr
      end
    end
  end
end
