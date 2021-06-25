# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Postgresql do
  let(:yaml) { {} }
  let(:shellout_mock) { double('Shellout', run: nil, try_run: '', success?: true) }
  let(:pg_version_file) { '/home/git/gdk/postgresql/data/PG_VERSION' }

  before do
    stub_pg_bindir
    stub_gdk_yaml(yaml)
  end

  describe '::TARGET_VERSION' do
    it 'is 12.6 by default' do
      expect(described_class::TARGET_VERSION).to be_instance_of(Gem::Version)
      expect(described_class::TARGET_VERSION).to eq(Gem::Version.new('12.6'))
    end
  end

  describe '.target_version_major' do
    it 'is 12 by default' do
      expect(described_class.target_version_major).to eq(12)
    end
  end

  describe '#installed?' do
    let(:pg_version_file_exists) { nil }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(pg_version_file).and_return(pg_version_file_exists)
    end

    context 'when postgresql/data/PG_VERSION does not exist' do
      let(:pg_version_file_exists) { false }

      it 'returns false' do
        expect(subject.installed?).to be(false)
      end
    end

    context 'when postgresql/data/PG_VERSION exists' do
      let(:pg_version_file_exists) { true }

      it 'returns true' do
        expect(subject.installed?).to be(true)
      end
    end
  end

  describe '#use_tcp?' do
    context 'with host defined to a path' do
      let(:yaml) do
        {
          'postgresql' => {
            'host' => '/home/git/gdk/postgresql'
          }
        }
      end

      it 'returns false' do
        expect(subject).not_to be_use_tcp
      end
    end

    context 'with host defined to a hostname' do
      let(:yaml) do
        {
          'postgresql' => {
            'host' => 'localhost'
          }
        }
      end

      it 'returns true' do
        expect(subject).to be_use_tcp
      end
    end
  end

  describe '#db_exists?' do
    it 'calls psql with the correct arguments' do
      expect(Shellout).to receive(:new).with(array_including('/usr/local/bin/psql', '--dbname=blaat'), any_args).and_return(shellout_mock)

      expect(subject.db_exists?('blaat')).to be_truthy
    end
  end

  describe '#createdb' do
    it 'calls createdb' do
      expect(Shellout).to receive(:new).with(array_including('/usr/local/bin/createdb', 'blaat'), any_args).and_return(shellout_mock)

      subject.createdb('blaat')
    end
  end

  describe '#in_recovery?' do
    it 'queries pg_is_in_recovery()' do
      expect(Shellout).to receive(:new).with(array_including('/usr/local/bin/psql', '--command=SELECT pg_is_in_recovery();'), any_args).and_return(shellout_mock)

      subject.in_recovery?
    end

    it 'returns true when psql query returned true' do
      expect(shellout_mock).to receive(:try_run).and_return('t')
      expect(Shellout).to receive(:new).and_return(shellout_mock)

      expect(subject).to be_in_recovery
    end

    it 'returns false when psql query returned false' do
      expect(shellout_mock).to receive(:try_run).and_return('f')
      expect(Shellout).to receive(:new).and_return(shellout_mock)

      expect(subject).not_to be_in_recovery
    end

    it 'returns false when psql failed' do
      expect(shellout_mock).to receive(:try_run).and_return('error: could not connect to server')
      expect(Shellout).to receive(:new).and_return(shellout_mock)

      expect(subject).not_to be_in_recovery
    end
  end

  describe '#current_data_dir' do
    it 'returns the path to the postgresql data directory' do
      expect(subject.current_data_dir).to eq('/home/git/gdk/postgresql/data')
    end
  end

  describe '#current_version' do
    it 'returns the PostgreSQL version set within postgresql/data/PG_VERSION' do
      stub_current_version('12')

      expect(subject.current_version).to eq(12)
    end
  end

  describe '#upgrade_needed?' do
    context 'when current version is 12' do
      before do
        stub_current_version('12')
      end

      context 'and target version is 9.6' do
        it 'returns false' do
          expect(subject.upgrade_needed?(9.6)).to be(false)
          expect(subject.upgrade_needed?('9.6')).to be(false)
        end
      end

      context 'and target version is 11' do
        it 'returns false' do
          expect(subject.upgrade_needed?(11)).to be(false)
          expect(subject.upgrade_needed?('11')).to be(false)
        end
      end

      context 'and target version is the default' do
        it 'returns false' do
          expect(subject.upgrade_needed?).to be(false)
        end
      end

      context 'and target version is 13' do
        it 'returns true' do
          expect(subject.upgrade_needed?(13)).to be(true)
          expect(subject.upgrade_needed?('13')).to be(true)
        end
      end
    end

    it 'returns the PostgreSQL version set within postgresql/data/PG_VERSION' do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:exist?).and_call_original

      allow(File).to receive(:exist?).with(pg_version_file).and_return(true)
      allow(File).to receive(:read).with(pg_version_file).and_return('12')

      expect(subject.current_version).to eq(12)
    end
  end

  def stub_current_version(version)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:exist?).and_call_original

    allow(File).to receive(:exist?).with(pg_version_file).and_return(true)
    allow(File).to receive(:read).with(pg_version_file).and_return(version)
  end
end
