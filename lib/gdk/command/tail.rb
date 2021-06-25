# frozen_string_literal: true

module GDK
  module Command
    # Tail all logs from enabled processes
    class Tail < BaseCommand
      def run(args = [])
        Runit.tail(args)
      end
    end
  end
end
