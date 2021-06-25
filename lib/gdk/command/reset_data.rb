# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk reset-data` command execution
    class ResetData < BaseCommand
      def run(args = [])
        return false unless prompt_and_return_acceptance
        return false unless stop_and_backup!

        reset_data!
      end

      private

      def stop_and_backup!
        Runit.stop

        return true if backup_data

        GDK::Output.error('Failed to backup data.')
        display_help_message

        false
      end

      def reset_data!
        if GDK.make
          GDK::Output.notice('Successfully reset data!')
          GDK::Command::Start.new.run
        else
          GDK::Output.error('Failed to reset data.')
          display_help_message

          false
        end
      end

      def prompt_and_return_acceptance
        GDK::Output.warn("We're about to remove PostgreSQL data, Rails uploads and git repository data.")
        GDK::Output.warn("Backups will be made in '#{GDK.root.join('.backups')}', just in case!")

        accepted = GDK::Output.prompt('Are you sure? [y/N]')
        accepted.match?(/\Ay(?:es)*\z/i)
      end

      def backup_data
        move_postgres_data && move_rails_uploads && move_git_repository_data
      end

      def current_timestamp
        @current_timestamp ||= Time.now.strftime('%Y-%m-%d_%H.%M.%S')
      end

      def create_directory(directory)
        directory = gdk_root_pathed(directory)
        Dir.mkdir(directory) unless directory.exist?

        true
      rescue Errno::ENOENT => e
        GDK::Output.error("Failed to create directory '#{directory}' - #{e}")
        false
      end

      def backup_directory(message, *directory)
        backup_directory = gdk_backup_pathed_timestamped(*directory)
        directory = gdk_root_pathed(*directory)
        return true unless directory.exist?

        GDK::Output.notice("Moving #{message} from '#{directory}' to '#{backup_directory}'")

        # Ensure the base directory exists
        FileUtils.mkdir_p(backup_directory.dirname)
        File.rename(directory, backup_directory)

        true
      rescue SystemCallError => e
        GDK::Output.error("Failed to rename directory '#{directory}' to '#{backup_directory}' - #{e}")
        false
      end

      def gdk_backup_pathed_timestamped(*path)
        path = path.flatten
        path[-1] = "#{path[-1]}.#{current_timestamp}"
        GDK.root.join('.backups', *path)
      end

      def gdk_root_pathed(*path)
        GDK.root.join(*path.flatten)
      end

      def move_postgres_data
        backup_directory('PostgreSQL data', %w[postgresql data])
      end

      def move_rails_uploads
        backup_directory('Rails uploads', %w[gitlab public uploads])
      end

      def move_git_repository_data
        backup_directory('git repository data', 'repositories') &&
          restore_repository_data_dir
      end

      def restore_repository_data_dir
        sh = Shellout.new('git restore repositories', chdir: GDK.root)
        sh.try_run
        sh.success?
      end

      def touch_file(file)
        File.open(file, 'w') {}
        true
      rescue SystemCallError
        false
      end
    end
  end
end
