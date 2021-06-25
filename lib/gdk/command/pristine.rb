# frozen_string_literal: true

require 'fileutils'

module GDK
  module Command
    # Handles `gdk pristine` command execution
    class Pristine < BaseCommand
      GO_CLEAN_CACHE_CMD = 'go clean -cache'
      BUNDLE_INSTALL_CMD = 'bundle install --jobs 4 --quiet'
      BUNDLE_PRISTINE_CMD = 'bundle pristine'
      YARN_CLEAN_CMD = 'yarn clean'
      GIT_CLEAN_TMP_CMD = 'git clean -fX -- tmp/'

      def run(_args = [])
        %i[
          gdk_stop
          gdk_tmp_clean
          go_clean_cache
          gdk_bundle
          gitlab_bundle
          gitaly_bundle
          gitlab_tmp_clean
          gitlab_yarn_clean
        ].each do |task_name|
          run_task(task_name)
        end

        GDK::Output.success("Successfully ran 'gdk pristine'!")

        true
      rescue StandardError => e
        GDK::Output.error("Failed to run 'gdk pristine' - #{e.message}.")
        display_help_message

        false
      end

      private

      def run_task(method_name)
        send(method_name) || # rubocop:disable GitlabSecurity/PublicSend
          raise("Had an issue with '#{method_name}'")
      end

      def notice(msg)
        GDK::Output.notice(msg)
      end

      def gdk_stop
        notice('Stopping GDK..')
        Runit.stop
      end

      def gdk_tmp_clean
        notice('Cleaning GDK tmp/ ..')
        shellout(GIT_CLEAN_TMP_CMD, chdir: config.gdk_root)
      end

      def go_clean_cache
        notice('Cleaning go cache..')
        shellout(GO_CLEAN_CACHE_CMD)
      end

      def gdk_bundle
        notice('Ensuring GDK Ruby gems are installed and pristine..')
        gdk_bundle_install && gdk_bundle_pristine
      end

      def gdk_bundle_install
        shellout(BUNDLE_INSTALL_CMD, chdir: config.gdk_root)
      end

      def gdk_bundle_pristine
        shellout(BUNDLE_PRISTINE_CMD, chdir: config.gdk_root)
      end

      def gitlab_bundle
        notice('Ensuring gitlab/ Ruby gems are installed and pristine..')
        gitlab_bundle_install && gitlab_bundle_pristine
      end

      def gitlab_bundle_install
        shellout(BUNDLE_INSTALL_CMD, chdir: config.gitlab.dir)
      end

      def gitlab_bundle_pristine
        shellout(BUNDLE_PRISTINE_CMD, chdir: config.gitlab.dir)
      end

      def gitlab_yarn_clean
        notice('Cleaning gitlab/ Yarn cache..')
        shellout(YARN_CLEAN_CMD, chdir: config.gitlab.dir)
      end

      def gitlab_tmp_clean
        notice('Cleaning gitlab/tmp/ ..')
        shellout(GIT_CLEAN_TMP_CMD, chdir: config.gitlab.dir)
      end

      def gitaly_bundle
        notice('Ensuring gitaly/ruby/ Ruby gems are installed and pristine..')
        gitaly_bundle_install && gitaly_bundle_pristine
      end

      def gitaly_bundle_install
        shellout(BUNDLE_INSTALL_CMD, chdir: config.gitaly.ruby_dir)
      end

      def gitaly_bundle_pristine
        shellout(BUNDLE_PRISTINE_CMD, chdir: config.gitaly.ruby_dir)
      end

      def shellout(cmd, chdir: config.gdk_root)
        sh = Shellout.new(cmd, chdir: chdir)
        sh.stream
        sh.success?
      rescue StandardError => e
        GDK::Output.puts(e.message, stderr: true)
        false
      end
    end
  end
end
