# frozen_string_literal: true

require 'time'
require 'net/http'

module GDK
  module Command
    class MeasureBase < BaseCommand
      def run(_ = [])
        check!

        if run_sitespeed
          open_report

          true
        else
          GDK::Output.warn('sitespeed failed to complete.')

          false
        end
      end

      private

      def open_report
        GDK::Output.notice("Opening Report open ./sitespeed_result/#{report_folder_name}/index.html")
        Shellout.new("open ./sitespeed-result/#{report_folder_name}/index.html").run
      end

      def check!
        GDK::Output.abort('Docker is not installed or running!') unless docker_running?
        GDK::Output.abort("GDK is not running locally on #{config.__uri}!") unless gdk_ok?
      end

      def use_git_branch_name?
        raise NotImplementedError
      end

      def gdk_ok?
        raise NotImplementedError
      end

      def items
        raise NotImplementedError
      end

      def gdk_running?
        GDK::HTTPHelper.new(config.__uri).up?
      end

      def docker_running?
        sh = Shellout.new('docker info')
        sh.run
        sh.success?
      end

      def report_folder_name
        @report_folder_name ||= begin
          folder_name = use_git_branch_name? ? Shellout.new('git rev-parse --abbrev-ref HEAD', chdir: config.gitlab.dir).run : 'external'
          folder_name + "_#{Time.now.strftime('%F-%H-%M-%S')}"
        end
      end

      def docker_command
        # Start Sitespeed through docker
        command = ['docker run --cap-add=NET_ADMIN --shm-size 2g --rm -v "$(pwd):/sitespeed.io" sitespeedio/sitespeed.io:16.8.1 -b chrome']
        # 4 repetitions
        command << '-n 4'
        # Limit Cable Connection
        command << '-c cable'
        # Deactivate the performance bar as it slows the measurements down
        command << '--cookie perf_bar_enabled=false'
        # Track CPU metrics
        command << '--cpu'
        # Write report to outputFolder
        command << "--outputFolder sitespeed-result/#{report_folder_name}"
      end

      def run_sitespeed
        GDK::Output.notice "Starting Sitespeed measurements for #{items.join(', ')}"

        sh = Shellout.new(docker_command.join(' '))
        sh.stream

        sh.success?
      end
    end
  end
end
