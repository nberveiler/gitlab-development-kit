# frozen_string_literal: true

module GDK
  module Command
    # Handles `gdk run` command execution
    #
    # @deprecated GDK run command has been deprecated should be removed in a future update
    class Run < BaseCommand
      def run(args = [])
        abort <<~GDK_RUN_NO_MORE
          'gdk run' is no longer available; see doc/runit.md.

          Use 'gdk start', 'gdk stop', and 'gdk tail' instead.
        GDK_RUN_NO_MORE
      end
    end
  end
end
