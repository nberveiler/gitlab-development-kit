# frozen_string_literal: true

require 'pathname'

module GDK
  class Backup
    SourceFileOutsideOfGdk = Class.new(StandardError)

    attr_reader :source_file

    def self.backup_root
      GDK.root.join('.backups')
    end

    def initialize(source_file)
      @source_file = Pathname.new(source_file.to_s).realpath

      validate!
    end

    def backup!(advise: true)
      ensure_backup_directory_exists
      make_backup_of_source_file
      advise_user if advise

      true
    end

    def destination_file
      @destination_file ||= begin
        backup_root.join("#{relative_source_file.to_s.gsub('/', '__')}.#{Time.now.strftime('%Y%m%d%H%M%S')}")
      end
    end

    def relative_source_file
      @relative_source_file ||= source_file.relative_path_from(GDK.root)
    end

    def recover_cmd_string
      "cp -f '#{destination_file}' '#{source_file}'"
    end

    private

    def relative_destination_file
      @relative_destination_file ||= destination_file.relative_path_from(GDK.root)
    end

    def validate!
      raise SourceFileOutsideOfGdk unless source_file.to_s.start_with?(GDK.root.to_s)

      true
    end

    def backup_root
      @backup_root ||= self.class.backup_root
    end

    def ensure_backup_directory_exists
      backup_root.mkpath
    end

    def advise_user
      GDK::Output.info("A backup of '#{relative_source_file}' has been made at '#{relative_destination_file}'.")
    end

    def make_backup_of_source_file
      FileUtils.mv(source_file.to_s, destination_file.to_s)
    end
  end
end
