# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Thin do
  it 'stops rails-web before starting thin server' do
    expect(subject).to receive(:stop_rails_web!)
    expect(subject).to receive(:start_thin!)

    subject.run
  end

  context 'when thin is configured to use sockets' do
    before do
      allow(subject).to receive(:stop_rails_web!)
      yaml = {
        'gitlab' => {
          'rails' => {
            'socket' => '/home/git/gdk/gitaly.socket'
          }
        }
      }
      stub_gdk_yaml(yaml)
    end

    it 'starts thin with socket params' do
      expect(subject.send(:thin_command)).to eq(%w[bundle exec thin --socket /home/git/gdk/gitlab.socket start])
      expect(subject).to receive(:exec)

      subject.run
    end
  end

  context 'when thin is configured to use TCP address and port' do
    before do
      allow(subject).to receive(:stop_rails_web!)
      yaml = {
        'gitlab' => {
          'rails' => {
            'address' => 'myhost:1234'
          }
        }
      }
      stub_gdk_yaml(yaml)
    end

    it 'starts thin with address and port params' do
      expect(subject.send(:thin_command)).to eq(%w[bundle exec thin --address myhost --port 1234 start])
      expect(subject).to receive(:exec)

      subject.run
    end
  end
end
