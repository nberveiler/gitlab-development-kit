# frozen_string_literal: true

module GDK
  module Command
    # Base interface for GDK commands
    class BaseCommand
      attr_reader :stdout, :stderr

      def initialize(stdout: $stdout, stderr: $stderr)
        @stdout = stdout
        @stderr = stderr
      end

      def run(args = [])
        raise NotImplementedError
      end

      protected

      def config
        @config ||= GDK.config
      end

      def display_help_message
        GDK.puts_separator <<~HELP_MESSAGE
          You can try the following that may be of assistance:

          - Run 'gdk doctor'.

          - Visit the troubleshooting documentation:
            https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/troubleshooting.md.
          - Visit https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues to
            see if there are known issues.

          - Run 'gdk reset-data' if appropriate.
          - Run 'gdk pristine' which will restore your GDK to a pristine state.
        HELP_MESSAGE
      end
    end
  end
end
