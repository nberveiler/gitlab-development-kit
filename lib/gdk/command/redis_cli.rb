# frozen_string_literal: true

module GDK
  module Command
    # Executes bundled redis-cli with any provided extra arguments
    class RedisCLI < BaseCommand
      def run(args = [])
        exec('redis-cli', '-s', config.redis.__socket_file.to_s, *args, chdir: GDK.root)
      end
    end
  end
end
