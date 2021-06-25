# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK do
  let(:hooks) { %w[date] }

  before do
    stub_pg_bindir
  end

  def expect_exec(input, cmdline)
    expect(subject).to receive(:exec).with(*cmdline)

    ARGV.replace(input)
    subject.main
  end

  describe '.main' do
    GDK::Command::COMMANDS.each do |command, command_class_proc|
      context "when invoking 'gdk #{command}' from command-line" do
        it "delegates execution to #{command_class_proc.call}" do
          stub_const('ARGV', [command])

          expect_any_instance_of(command_class_proc.call).to receive(:run).and_return(true)
          described_class.main
        end
      end
    end
  end

  describe '.validate_yaml!' do
    let(:raw_yaml) { nil }

    before do
      described_class.instance_variable_set(:@config, nil)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('gdk.example.yml').and_return(raw_yaml)
    end

    context 'with valid YAML' do
      let(:raw_yaml) { "---\ngdk:\n  debug: true" }

      it 'returns nil' do
        expect(described_class.validate_yaml!).to be_nil
      end
    end

    shared_examples 'invalid YAML' do |error_message|
      it 'prints an error' do
        expect(GDK::Output).to receive(:error).with("Your gdk.yml is invalid.\n\n")
        expect(GDK::Output).to receive(:puts).with(error_message, stderr: true)

        expect { described_class.validate_yaml! }.to raise_error(SystemExit).and output("\n").to_stderr
      end
    end

    context 'with invalid YAML' do
      let(:raw_yaml) { "---\ngdk:\n  debug" }

      it_behaves_like 'invalid YAML', %(undefined method `fetch' for "debug":String)
    end

    context 'with partially invalid YAML' do
      let(:raw_yaml) { "---\ngdk:\n  debug: fals" }

      it_behaves_like 'invalid YAML', "Value 'fals' for gdk.debug is not a valid bool"
    end
  end
end
