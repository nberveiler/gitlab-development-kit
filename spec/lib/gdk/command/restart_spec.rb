# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Restart do
  context 'with no extra arguments' do
    it 'calls stop then start without specifying services' do
      expect_any_instance_of(GDK::Command::Stop).to receive(:run).with([])
      expect_any_instance_of(GDK::Command::Start).to receive(:run).with([])

      subject.run
    end
  end

  context 'with extra arguments' do
    it 'calls stop then start specifying services' do
      services = %w[rails-web]

      expect_any_instance_of(GDK::Command::Stop).to receive(:run).with(services)
      expect_any_instance_of(GDK::Command::Start).to receive(:run).with(services)

      subject.run(services)
    end
  end
end
