# frozen_string_literal: true

require 'fileutils'

module GDK
  module Command
    class DiffConfig < BaseCommand
      DIFFABLE_FILES = %w[
        Procfile
        gitaly/gitaly.config.toml
        gitaly/praefect.config.toml
        gitlab-pages/gitlab-pages.conf
        gitlab-runner-config.toml
        gitlab-shell/.gitlab_shell_secret
        gitlab-shell/config.yml
        gitlab/workhorse/config.toml
        gitlab/config/cable.yml
        gitlab/config/database.yml
        gitlab/config/database_geo.yml
        gitlab/config/gitlab.yml
        gitlab/config/puma.rb
        gitlab/config/resque.yml
        nginx/conf/nginx.conf
        openssh/sshd_config
        prometheus/prometheus.yml
        redis/redis.conf
        registry/config.yml
      ].freeze

      def run(_ = [])
        Shellout.new(GDK::MAKE, 'touch-examples').run

        # Iterate over each file from files Array and print any output to
        # stderr that may have come from running `make <file>`.
        #
        results = jobs.map { |x| x.join[:results] }.compact

        results.each do |diff|
          output = diff.make_output.to_s.chomp
          next if output.empty?

          GDK::Output.puts(output)
          GDK::Output.puts("\n")
        end

        true
      end

      private

      def jobs
        DIFFABLE_FILES.map do |file|
          Thread.new do
            Thread.current[:results] = ConfigDiff.new(file)
          end
        end
      end

      class ConfigDiff
        attr_reader :file, :output, :make_output

        def initialize(file)
          @file = file

          execute
        end

        def file_path
          @file_path ||= GDK.root.join(file)
        end

        private

        def execute
          # It's entirely possible file_path doesn't exist because it may be
          # a config file that user does not need and therefore has not been
          # generated.
          return nil unless file_path.exist?

          # We must not do the equivalent of "mv && make" here,
          # because we'd race with other checks when "gdk doctor"
          # runs us in parallel with checks that need to read these
          # config files.
          FileUtils.cp_r(file_path, file_path_unchanged) # must handle files & preserve symlinks
          @make_output = update_config_file

          @output = diff_with_unchanged
        ensure
          File.rename(file_path_unchanged, file_path) if File.exist?(file_path_unchanged)
        end

        def file_path_unchanged
          @file_path_unchanged ||= "#{file_path}.unchanged"
        end

        def update_config_file
          run(GDK::MAKE, '--silent', file)
        end

        def diff_with_unchanged
          run('git', 'diff', '--no-index', '--color', "#{file}.unchanged", file)
        end

        def run(*commands)
          Shellout.new(commands, chdir: GDK.root).run
        end
      end
    end
  end
end
