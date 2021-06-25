# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk reconfigure` command execution
    class Reconfigure < BaseCommand
      def run(args = [])
        result = GDK.make('reconfigure')

        unless result
          GDK::Output.error('Failed to reconfigure.')
          display_help_message
        end

        result
      end
    end
  end
end
