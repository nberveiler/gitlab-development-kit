# frozen_string_literal: true

module GDK
  module Diagnostic
    class PostgreSQL < Base
      TITLE = 'PostgreSQL'

      # Check if the version of PostgreSQL in the PATH matches the
      # version in the data directory.
      def diagnose
        psql_command.try_run
        data_dir_version

        nil
      end

      def success?
        psql_command.success? && psql_version && data_dir_version && versions_match?
      end

      def detail
        return if success?

        cmd_version = psql_version || 'unknown'
        data_version = data_dir_version || 'unknown'

        <<~MESSAGE
          `psql` is version #{cmd_version}, but your PostgreSQL data dir is using version #{data_version}.
          Check that your PATH is pointing to the right PostgreSQL version, or see the PostgreSQL upgrade guide:
          https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/postgresql.md#upgrade-postgresql
        MESSAGE
      end

      private

      def versions_match?
        if psql_version >= 10
          data_dir_version.to_i == psql_version.to_i
        else
          # Avoid floating point comparison issues by using rationals
          data_dir_version.to_r.round(2) == psql_version.to_r.round(2)
        end
      end

      def psql_version
        return unless psql_command.success?

        match = psql_command.read_stdout&.match(/psql \(PostgreSQL\) (.*)/)

        return unless match

        match[1].to_f
      end

      def psql_command
        @psql_command ||= Shellout.new(%w[psql --version])
      end

      def data_dir_version
        return unless File.exist?(data_dir_version_filename)

        @data_dir_version ||= File.read(data_dir_version_filename).to_f
      end

      def data_dir_version_filename
        @data_dir_version_filename ||= File.join(GDK::Config.new.postgresql.data_dir, 'PG_VERSION')
      end
    end
  end
end
