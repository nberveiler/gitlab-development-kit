# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Stop do
  let(:hooks) { %w[date] }

  before do
    allow_any_instance_of(GDK::Config).to receive_message_chain('gdk.stop_hooks').and_return(hooks)
  end

  context 'with no extra arguments' do
    it 'executes hooks and stops all enabled services' do
      expect(GDK::Hooks).to receive(:with_hooks).with(hooks, 'gdk stop').and_yield
      expect(Runit).to receive(:stop).and_return(true)

      subject.run
    end
  end

  context 'with extra arguments' do
    it 'executes hooks and stops specified services' do
      services = %w[rails-web]

      expect(GDK::Hooks).to receive(:with_hooks).with(hooks, 'gdk stop').and_yield
      expect_runit_to_execute(command: 'force-stop', args: services)

      subject.run(services)
    end
  end

  def expect_runit_to_execute(command:, args: [])
    expect(Runit).to receive(:sv).with(command, args).and_return(true)
  end
end
