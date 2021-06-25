# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk version` command execution
    class Version < BaseCommand
      def run(_ = [])
        GDK::Output.puts("#{GDK::VERSION} (#{git_revision})")

        true
      end

      private

      def git_revision
        Shellout.new('git rev-parse --short HEAD', chdir: GDK.root).run
      end
    end
  end
end
