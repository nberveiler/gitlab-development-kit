# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Tail do
  context 'with no extra arguments' do
    it 'asks runit to tail logs for all enabled services' do
      expect(Runit).to receive(:tail)

      subject.run
    end
  end

  context 'with extra arguments' do
    it 'asks runit to tail logs for specific services only' do
      services = %w[rails-web]
      expect(Runit).to receive(:tail).with(services)

      subject.run(services)
    end
  end
end
