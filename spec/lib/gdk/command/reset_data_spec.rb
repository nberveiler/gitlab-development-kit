# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::ResetData do
  let!(:root) { GDK.root }
  let!(:backup_base_dir) { root.join('.backups') }

  context 'prompt behavior' do
    let(:are_you_sure) { nil }

    before do
      allow(GDK::Output).to receive(:warn).with("We're about to remove PostgreSQL data, Rails uploads and git repository data.")
      allow(GDK::Output).to receive(:warn).with("Backups will be made in '#{backup_base_dir}', just in case!")
      allow(GDK::Output).to receive(:prompt).with('Are you sure? [y/N]').and_return(are_you_sure)
    end

    context 'when the user does not accept / aborts the prompt' do
      let(:are_you_sure) { 'n' }

      it 'does not run' do
        expect(subject).not_to receive(:stop_and_backup!)
        expect(subject).not_to receive(:reset_data!)

        subject.run
      end
    end

    context 'when the user accepts the prompt' do
      let(:are_you_sure) { 'y' }

      it 'runs' do
        expect(subject).to receive(:stop_and_backup!).and_return(true)
        expect(subject).to receive(:reset_data!).and_return(true)

        subject.run
      end
    end
  end

  context 'backup behavior' do
    let!(:now) { Time.now }
    let!(:current_timestamp) { now.strftime('%Y-%m-%d_%H.%M.%S') }
    let!(:postgresql_data_directory) { root.join('postgresql', 'data') }
    let!(:backup_postgresql_data_directory) { backup_base_dir.join('postgresql', "data.#{current_timestamp}") }

    before do
      allow(GDK).to receive(:remember!)
      allow(Runit).to receive(:stop)
      allow(GDK).to receive(:root).and_return(root)
      allow(subject).to receive(:prompt_and_return_acceptance).and_return(true)
    end

    context 'when backup data script fails' do
      it 'errors out', :hide_stdout do
        travel_to(now) do
          stub_postgres_data_move
          allow(File).to receive(:rename).with(postgresql_data_directory, backup_postgresql_data_directory).and_raise(Errno::ENOENT)

          expect(GDK::Output).to receive(:error).with("Failed to rename directory '#{postgresql_data_directory}' to '#{backup_postgresql_data_directory}' - No such file or directory")
          expect(GDK::Output).to receive(:error).with('Failed to backup data.')
          expect(subject).to receive(:display_help_message)
          expect(GDK).not_to receive(:make)

          subject.run
        end
      end
    end

    context 'when backup data script succeeds', :hide_stdout do
      let!(:rails_uploads_directory) { root.join('gitlab', 'public', 'uploads') }
      let!(:backup_rails_uploads_directory) { backup_base_dir.join('gitlab', 'public', "uploads.#{current_timestamp}") }
      let!(:git_repository_data_directory) { root.join('repositories') }
      let!(:backup_git_repository_data_directory) { backup_base_dir.join("repositories.#{current_timestamp}") }

      context 'but make command fails' do
        it 'errors out' do
          travel_to(now) do
            stub_data_moves

            expect(GDK).to receive(:make).and_return(false)

            expect(GDK::Output).to receive(:error).with('Failed to reset data.')
            expect(GDK::Command::Start).not_to receive(:new)
            expect(subject).to receive(:display_help_message)

            subject.run
          end
        end
      end

      context 'and make command succeeds also' do
        it 'resets data' do
          travel_to(now) do
            stub_data_moves

            expect(GDK).to receive(:make).and_return(true)

            expect(GDK::Output).to receive(:notice).with("Moving PostgreSQL data from '#{postgresql_data_directory}' to '#{backup_postgresql_data_directory}'")
            expect(GDK::Output).to receive(:notice).with("Moving Rails uploads from '#{rails_uploads_directory}' to '#{backup_rails_uploads_directory}'")
            expect(GDK::Output).to receive(:notice).with("Moving git repository data from '#{git_repository_data_directory}' to '#{backup_git_repository_data_directory}'")
            expect(GDK::Output).to receive(:notice).with('Successfully reset data!')
            expect_any_instance_of(GDK::Command::Start).to receive(:run)

            subject.run
          end
        end
      end
    end

    def expect_rename_success(directory, new_directory)
      expect(File).to receive(:rename).with(directory, new_directory).and_return(true)
    end

    def allow_make_backup_base_dir(directory)
      directory_base_name = directory.dirname
      allow(FileUtils).to receive(:mkdir_p).with(directory_base_name).and_return([directory_base_name])
    end

    def stub_data_moves
      stub_postgres_data_move
      expect_rename_success(postgresql_data_directory, backup_postgresql_data_directory)

      stub_rails_uploads_move
      expect_rename_success(rails_uploads_directory, backup_rails_uploads_directory)

      stub_git_repository_data_move
      expect_rename_success(git_repository_data_directory, backup_git_repository_data_directory)
    end

    def stub_postgres_data_move
      allow(root).to receive(:join).with('.backups', 'postgresql', "data.#{current_timestamp}").and_return(backup_postgresql_data_directory)
      allow(root).to receive(:join).with('postgresql', 'data').and_return(postgresql_data_directory)

      allow(postgresql_data_directory).to receive(:exist?).and_return(true)
      allow_make_backup_base_dir(backup_postgresql_data_directory)
    end

    def stub_rails_uploads_move
      allow(root).to receive(:join).with('.backups', 'gitlab', 'public', "uploads.#{current_timestamp}").and_return(backup_rails_uploads_directory)
      allow(root).to receive(:join).with('gitlab', 'public', 'uploads').and_return(rails_uploads_directory)

      allow(rails_uploads_directory).to receive(:exist?).and_return(true)
      allow_make_backup_base_dir(backup_rails_uploads_directory)
    end

    def stub_git_repository_data_move
      allow(root).to receive(:join).with('.backups', "repositories.#{current_timestamp}").and_return(backup_git_repository_data_directory)
      allow(root).to receive(:join).with('repositories').and_return(git_repository_data_directory)

      allow_make_backup_base_dir(backup_git_repository_data_directory)
      allow(git_repository_data_directory).to receive(:exist?).and_return(true)

      git_restore_repositoriess_double = instance_double(Shellout, try_run: '', success?: true)
      expect(Shellout).to receive(:new).with('git restore repositories', chdir: root).and_return(git_restore_repositoriess_double)
    end
  end
end
