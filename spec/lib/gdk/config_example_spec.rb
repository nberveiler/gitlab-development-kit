# frozen_string_literal: true

require 'spec_helper'
require 'gdk/config_example'

RSpec.describe GDK::ConfigExample do
  subject(:config) { described_class.new }

  describe '#gdk_root' do
    it 'returns the gdk directory in ~git' do
      expect(config.gdk_root.to_s).to eq('/home/git/gdk')
    end
  end

  describe '#username' do
    it 'returns git' do
      expect(config.username).to eq('git')
    end
  end

  describe '#praefect' do
    let(:praefect) { config.praefect }

    it 'returns a stubbed settings object' do
      expect(praefect).to be_a(GDK::ConfigExample::Settings)
    end

    describe '#database' do
      let(:database) { praefect.database }

      describe '#sslmode' do
        let(:sslmode) { database.sslmode }

        it { expect(sslmode).to eq('disable') }
      end
    end
  end

  describe '#dump!' do
    it 'does not read any file' do
      expect(File).not_to receive(:read)

      config.dump!
    end
  end
end
