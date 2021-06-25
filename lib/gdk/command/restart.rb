# frozen_string_literal: true

module GDK
  module Command
    # Stop and restart all enabled services or specified ones only
    class Restart < BaseCommand
      def run(args = [])
        GDK::Command::Stop.new.run(args)
        GDK::Command::Start.new.run(args)
      end
    end
  end
end
