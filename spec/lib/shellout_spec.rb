# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Shellout do
  let(:command) { 'echo foo' }
  let(:opts) { {} }
  let(:tmp_directory) { File.realpath('/tmp') }

  subject { described_class.new(command, opts) }

  describe '#args' do
    let(:command_as_array) { %w[echo foo] }

    context 'when command is a String' do
      it 'parses correctly' do
        expect(subject.args).to eq([command])
      end
    end

    context 'when command is an Array' do
      let(:command) { command_as_array }

      it 'parses correctly' do
        expect(subject.args).to eq(command)
      end
    end

    context 'when command is a series of arguments' do
      subject { described_class.new('echo', 'foo') }

      it 'parses correctly' do
        expect(subject.args).to eq(command_as_array)
      end
    end
  end

  describe '#exit_code' do
    describe '#run has not yet been executed' do
      it 'returns nil' do
        expect(subject.exit_code).to be_nil
      end
    end

    describe '#run has been executed' do
      before do
        subject.run
      end

      context 'when command is successful' do
        it 'returns 0' do
          expect(subject.exit_code).to be(0)
        end
      end

      context 'when command is not successful' do
        let(:command) { 'echo error 1>&2; exit 1' }

        it 'returns 1' do
          expect(subject.exit_code).to be(1)
        end
      end
    end
  end

  describe '#stream' do
    it 'returns output of shell command', :hide_stdout do
      expect(subject.stream).to eq('foo')
    end

    it 'send output to stdout' do
      expect { subject.stream }.to output("foo\n").to_stdout
    end

    context 'when chdir: is specified' do
      let(:command) { 'pwd' }
      let(:opts) { { chdir: tmp_directory } }

      it 'changes into the specified directory before executing' do
        expect { expect(subject.stream).to eq(tmp_directory) }.to output("#{tmp_directory}\n").to_stdout
      end
    end
  end

  describe '#readlines' do
    let(:command) { 'env' }

    it 'reads the number of lines given' do
      expect(subject.readlines(3).count).to eq(3)
    end
  end

  describe '#run' do
    it 'returns output of shell command' do
      expect(subject.run).to eq('foo')
    end

    context 'when chdir: is specified' do
      let(:command) { 'pwd' }
      let(:opts) { { chdir: tmp_directory } }

      it 'changes into the specified directory before executing' do
        expect(subject.run).to eq(tmp_directory)
      end
    end
  end

  describe '#try_run' do
    let(:command) { 'foo bar' }

    it 'returns empty string' do
      expect(subject.try_run).to eq('')
    end

    it 'does not raise error' do
      expect { subject.try_run }.not_to raise_error
    end

    context 'when chdir: is specified' do
      let(:command) { 'pwd' }
      let(:opts) { { chdir: tmp_directory } }

      it 'changes into the specified directory before executing' do
        expect(subject.try_run).to eq(tmp_directory)
      end
    end
  end

  describe '#read_stdout' do
    before do
      subject.run
    end

    it 'returns stdout of shell command' do
      expect(subject.read_stdout).to eq('foo')
    end
  end

  describe '#read_stderr' do
    let(:command) { 'echo error 1>&2; exit 1' }

    before do
      subject.run
    end

    it 'returns stdout of shell command' do
      expect(subject.read_stderr).to eq('error')
    end
  end

  describe '#success?' do
    describe '#run has not yet been executed' do
      it 'returns false' do
        expect(subject.success?).to be false
      end
    end

    describe '#run has been executed' do
      before do
        subject.run
      end

      context 'when command is successful' do
        it 'returns true' do
          expect(subject.success?).to be true
        end
      end

      context 'when command is not successful' do
        let(:command) { 'echo error 1>&2; exit 1' }

        it 'returns false' do
          expect(subject.success?).to be false
        end
      end
    end
  end
end
