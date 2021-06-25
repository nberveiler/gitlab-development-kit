# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe GDK::Diagnostic::PostgreSQL do # rubocop:disable RSpec/FilePath
  before do
    @tmp_file = stub_data_version(11)
  end

  after do
    FileUtils.rm(@tmp_file) if File.exist?(@tmp_file)
  end

  describe '#diagnose' do
    it 'returns nil' do
      expect(subject.diagnose).to be_nil
    end
  end

  describe '#success?' do
    let(:psql_success) { true }

    before do
      stub_psql_version('psql (PostgreSQL) 11.9', success: psql_success)
    end

    context 'when psql --version matches PG_VERSION' do
      it 'returns true' do
        expect(subject).to be_success
      end
    end

    context 'when psql --version differs' do
      before do
        stub_psql_version('psql (PostgreSQL) 12.8', success: psql_success)
      end

      it 'returns false' do
        expect(subject).not_to be_success
      end
    end

    context 'when psql does not succeed' do
      let(:psql_success) { false }

      it 'returns false' do
        expect(subject).not_to be_success
      end
    end

    context 'when psql --version is 9.6' do
      before do
        stub_psql_version('psql (PostgreSQL) 9.6.18', success: psql_success)
      end

      it 'returns false' do
        expect(subject).not_to be_success
      end

      context 'when data version is 9.6' do
        before do
          allow(subject).to receive(:data_dir_version).and_return(9.6)
        end

        it 'returns false' do
          expect(subject).to be_success
        end
      end
    end
  end

  describe '#detail' do
    context 'when successful' do
      before do
        allow(subject).to receive(:success?).and_return(true)
      end

      it 'returns nil' do
        expect(subject.detail).to be_nil
      end
    end

    context 'when unsuccessful' do
      before do
        allow(subject).to receive(:success?).and_return(false)
        allow(subject).to receive(:psql_version).and_return(11.8)
        allow(subject).to receive(:data_dir_version).and_return(12)
      end

      it 'returns help message' do
        expected = <<~MESSAGE
        `psql` is version 11.8, but your PostgreSQL data dir is using version 12.
        Check that your PATH is pointing to the right PostgreSQL version, or see the PostgreSQL upgrade guide:
        https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/postgresql.md#upgrade-postgresql
        MESSAGE

        expect(subject.detail).to eq(expected)
      end
    end
  end

  def stub_data_version(version)
    tmpfile = Tempfile.new
    tmpfile.write(version)
    tmpfile.close
    allow(subject).to receive(:data_dir_version_filename).and_return(tmpfile.path)

    tmpfile.path
  end

  def stub_psql_version(result, success: true)
    shellout = double('Shellout', try_run: result, read_stdout: result, success?: success)
    allow(Shellout).to receive(:new).with(%w[psql --version]).and_return(shellout)
    allow(shellout).to receive(:try_run).and_return(result)
  end
end
