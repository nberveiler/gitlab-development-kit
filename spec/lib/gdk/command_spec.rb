# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command do
  context 'with declared available command classes' do
    GDK::Command::COMMANDS.each do |_, command_class_proc|
      it "expects #{command_class_proc.call} to inherit from GDK::Command::BaseCommand directly or indirectly" do
        command_class = command_class_proc.call

        expect(command_class < GDK::Command::BaseCommand).to be_truthy
      end
    end
  end
end
