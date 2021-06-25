# frozen_string_literal: true

module GDK
  class PostgresqlGeo < Postgresql
    def bin_dir
      postgresql_config.bin_dir
    end

    private

    def config
      @config ||= GDK.config.postgresql.geo
    end

    def postgresql_config
      @postgresql_config ||= GDK.config.postgresql
    end

    def default_database
      'gitlabhq_geo_development'
    end
  end
end
