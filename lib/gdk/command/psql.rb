# frozen_string_literal: true

module GDK
  module Command
    # Executes bundled psql command with any provided extra arguments
    class Psql < BaseCommand
      def run(args = [])
        exec(GDK::Postgresql.new.psql_cmd(args), chdir: GDK.root)
      end
    end
  end
end
