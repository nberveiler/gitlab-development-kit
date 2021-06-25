# frozen_string_literal: true

module GDK
  class Postgresql
    TARGET_VERSION = Gem::Version.new(12.6)

    def self.target_version_major
      TARGET_VERSION.canonical_segments[0]
    end

    def psql_cmd(args)
      database = args.empty? ? default_database : nil

      pg_cmd(args, database: database).join(" ")
    end

    def current_data_dir
      @current_data_dir ||= begin
        config = GDK::Config.new
        File.join(config.postgresql.dir, 'data')
      end
    end

    def current_version
      @current_version ||= begin
        raise "PG_VERSION not found in #{pg_version_file}. Is PostgreSQL initialized?" unless installed?

        version = File.read(pg_version_file).to_f

        # After PostgreSQL 9.6, PG_VERSION uses a single integer (10, 11, 12, etc.)
        version >= 10 ? version.to_i : version
      end
    end

    def installed?
      File.exist?(pg_version_file)
    end

    def ready?
      last_error = nil
      cmd = pg_cmd(database: 'template1')

      10.times do
        shellout = Shellout.new(cmd)
        shellout.run
        last_error = shellout.read_stderr

        return true if shellout.success?

        sleep 1
      end

      GDK::Output.error(last_error)
      false
    end

    def use_tcp?
      !config.host.start_with?('/')
    end

    def upgrade_needed?(target_version = self.class.target_version_major)
      current_version < target_version.to_f
    end

    def db_exists?(dbname)
      Shellout.new(pg_cmd(database: dbname)).tap(&:try_run).success?
    end

    def createdb(*args)
      cmd = pg_cmd(*args, program: 'createdb')

      Shellout.new(cmd).run
    end

    def in_recovery?
      cmd = pg_cmd('--no-psqlrc', '--tuples-only',
                   database: 'postgres',
                   command: 'SELECT pg_is_in_recovery();')

      Shellout.new(cmd).try_run.downcase.strip.chomp == 't'
    end

    private

    def config
      @config ||= GDK.config.postgresql
    end

    def host
      config.dir.to_s
    end

    def port
      config.port.to_s
    end

    def pg_version_file
      @pg_version_file ||= File.join(current_data_dir, 'PG_VERSION')
    end

    def pg_cmd(*args, program: 'psql', database: nil, command: nil)
      cmd = [bin_dir.join(program).to_s]
      cmd << "--host=#{host}"
      cmd << "--port=#{port}"
      cmd << "--dbname=#{database}" if database
      cmd << "--command=#{command}" if command

      cmd + args
    end

    def default_database
      'gitlabhq_development'
    end

    def bin_dir
      config.bin_dir
    end
  end
end
