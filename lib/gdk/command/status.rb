# frozen_string_literal: true

module GDK
  module Command
    # Display status of all enabled services or specified ones only
    class Status < BaseCommand
      def run(args = [])
        Runit.sv('status', args)
      end
    end
  end
end
