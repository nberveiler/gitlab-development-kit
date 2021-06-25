# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Status do
  context 'with no extra arguments' do
    it 'queries runit for status to all enabled services' do
      expect_runit_to_execute(command: 'status')

      subject.run
    end
  end

  context 'with extra arguments' do
    it 'queries runit for status to specific services only' do
      expect_runit_to_execute(command: 'status', args: ['rails-web'])

      subject.run(%w[rails-web])
    end
  end

  def expect_runit_to_execute(command:, args: [])
    expect(Runit).to receive(:sv).with(command, args).and_return(true)
  end
end
