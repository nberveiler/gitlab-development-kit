# frozen_string_literal: true

require 'spec_helper'
require 'gdk/gitlab_rails/db'

RSpec.describe GDK::GitlabRails::DB, :hide_stdout do
  describe '#migrate' do
    let(:shellout_mock) { double('Shellout', stream: nil, success?: true) }

    subject(:migrate) { described_class.new.migrate }

    before do
      stub_pg_bindir
    end

    context 'database is not in recovery' do
      before do
        allow_any_instance_of(GDK::Postgresql).to receive(:in_recovery?).and_return(false)
      end

      it 'migrates the main database' do
        expect(Shellout).to receive(:new).with(array_including('db:migrate'), any_args).and_return(shellout_mock)

        migrate
      end

      it 'migrates the Geo database when Geo is enabled' do
        stub_gdk_yaml('geo' => { 'enabled' => true })

        expect(Shellout).to receive(:new).with(array_including('geo:db:migrate'), any_args).and_return(shellout_mock)

        migrate
      end

      it 'does not migrate the main database when Geo is a secondary' do
        stub_gdk_yaml('geo' => { 'enabled' => true, 'secondary' => true })

        allow(Shellout).to receive(:new).and_return(shellout_mock)
        expect(Shellout).not_to receive(:new).with(array_including('db:migrate'), any_args)

        migrate
      end
    end

    context 'database is in recovery' do
      before do
        allow_any_instance_of(GDK::Postgresql).to receive(:in_recovery?).and_return(true)
      end

      it 'does nothing' do
        expect(Shellout).not_to receive(:new)

        migrate
      end

      it 'migrates the Geo database when Geo is enabled' do
        stub_gdk_yaml('geo' => { 'enabled' => true })

        expect(Shellout).to receive(:new).with(array_including('geo:db:migrate'), any_args).and_return(shellout_mock)

        migrate
      end
    end
  end
end
