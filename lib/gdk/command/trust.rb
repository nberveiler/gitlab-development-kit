# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk trust` command execution
    #
    # @deprecated GDK trust command has been deprecated should be removed in a future update
    class Trust < BaseCommand
      def run(args = [])
        GDK::Output.info("'gdk trust' is deprecated and no longer required.")

        true
      end
    end
  end
end
