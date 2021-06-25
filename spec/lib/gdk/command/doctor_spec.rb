# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe GDK::Command::Doctor, :hide_output do
  let(:successful_diagnostic) { double(GDK::Diagnostic, success?: true, diagnose: nil, message: nil) }
  let(:failing_diagnostic) { double(GDK::Diagnostic, success?: false, diagnose: 'error', message: 'check failed') }
  let(:diagnostics) { [] }
  let(:shellout) { double(Shellout, run: nil) }
  let(:warning_message) do
    <<~WARNING
      ================================================================================
      Please note these warning only exist for debugging purposes and can
      help you when you encounter issues with GDK.
      If your GDK is working fine, you can safely ignore them. Thanks!
      ================================================================================
    WARNING
  end

  subject { described_class.new(diagnostics: diagnostics) }

  before do
    allow(Shellout).to receive(:new).with('gdk start postgresql').and_return(shellout)
  end

  it 'starts necessary services' do
    expect(shellout).to receive(:run)

    subject.run
  end

  context 'with passing diagnostics' do
    let(:diagnostics) { [successful_diagnostic, successful_diagnostic] }

    it 'runs all diagnosis' do
      expect(successful_diagnostic).to receive(:diagnose).twice

      subject.run
    end

    it 'prints GDK is ready.' do
      expect(GDK::Output).to receive(:success).with('GDK is healthy.')

      subject.run
    end
  end

  context 'with failing diagnostics' do
    let(:diagnostics) { [failing_diagnostic, failing_diagnostic] }

    it 'runs all diagnosis' do
      expect(failing_diagnostic).to receive(:diagnose).twice

      subject.run
    end

    it 'prints a warning' do
      expect(GDK::Output).to receive(:puts).with("\n").ordered
      expect(GDK::Output).to receive(:warn).with('GDK may need attention:').ordered
      expect(GDK::Output).to receive(:puts).with("\n").ordered
      expect(GDK::Output).to receive(:puts).with(warning_message).ordered
      expect(GDK::Output).to receive(:puts).with('check failed').ordered.twice

      subject.run
    end
  end

  context 'with partial failing diagnostics' do
    let(:diagnostics) { [failing_diagnostic, successful_diagnostic, failing_diagnostic] }

    it 'runs all diagnosis' do
      expect(failing_diagnostic).to receive(:diagnose).twice
      expect(successful_diagnostic).to receive(:diagnose).once

      subject.run
    end

    it 'prints a message from failed diagnostics' do
      expect(failing_diagnostic).to receive(:message).twice
      expect(GDK::Output).to receive(:puts).with("\n").ordered
      expect(GDK::Output).to receive(:warn).with('GDK may need attention:').ordered
      expect(GDK::Output).to receive(:puts).with("\n").ordered
      expect(GDK::Output).to receive(:puts).with(warning_message).ordered
      expect(GDK::Output).to receive(:puts).with('check failed').ordered.twice

      subject.run
    end

    it 'does not print a message from successful diagnostics' do
      expect(successful_diagnostic).not_to receive(:message)

      subject.run
    end
  end
end
