# frozen_string_literal: true

module GDK
  module Command
    # Executes bundled psql command pointing to the Geo Tracking database with any provided extra arguments
    class PsqlGeo < BaseCommand
      def run(args = [])
        exec(GDK::PostgresqlGeo.new.psql_cmd(args), chdir: GDK.root)
      end
    end
  end
end
