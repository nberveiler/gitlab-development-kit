# frozen_string_literal: true

require 'forwardable'

require_relative '../../shellout'
require_relative '../config'

module GDK
  module GitlabRails
    # Class to work with database migrations on gitlab-rails
    class DB
      extend Forwardable

      MAIN_TASKS = %w[db:migrate db:test:prepare].freeze
      GEO_TASKS = %w[geo:db:migrate geo:db:test:prepare].freeze

      def_delegators :config, :geo?
      def_delegators :postgresql, :in_recovery?

      def migrate
        tasks = migrate_tasks

        return if migrate_tasks.empty?

        display_migrate_message(tasks.keys)
        rake(tasks.values.flatten)
      end

      private

      def migrate_tasks
        tasks = {}
        tasks['rails'] = MAIN_TASKS unless geo_secondary? || in_recovery?
        tasks['Geo'] = GEO_TASKS if geo?

        tasks
      end

      def display_migrate_message(tasks)
        str = tasks.join(' and ')

        GDK::Output.divider
        GDK::Output.puts("Processing gitlab #{str} DB migrations")
        GDK::Output.divider
      end

      def rake(tasks)
        sh = Shellout.new(%w[bin/rake] + tasks,
                          chdir: config.gdk_root.join('gitlab'))
        sh.stream
        sh.success?
      end

      def geo_secondary?
        config.geo.secondary?
      end

      def config
        @config ||= GDK.config
      end

      def postgresql
        @postgresql ||= GDK::Postgresql.new
      end
    end
  end
end
