# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk thin` command execution
    class Thin < BaseCommand
      def run(args = [])
        stop_rails_web!

        start_thin!
      end

      private

      def stop_rails_web!
        # We cannot use Runit.sv because that calls Kernel#exec. Use system instead.
        system('gdk', 'stop', 'rails-web')
      end

      def start_thin!
        exec(
          { 'RAILS_ENV' => 'development' },
          *thin_command,
          chdir: GDK.root.join('gitlab')
        )
      end

      def thin_command
        args =
          if config.gitlab.rails.__listen_settings.__protocol == 'unix'
            %W[--socket #{config.gitlab.rails.__socket_file}]
          else
            url = URI(config.gitlab.rails.__bind)
            %W[--address #{url.host} --port #{url.port}]
          end

        %w[bundle exec thin] + args + %w[start]
      end
    end
  end
end
