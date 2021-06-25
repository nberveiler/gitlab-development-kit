# frozen_string_literal: true

module GDK
  module Command
    class Doctor < BaseCommand
      def initialize(diagnostics: GDK::Diagnostic.all, **args)
        @diagnostics = diagnostics

        super(**args)
      end

      def run(_ = [])
        start_necessary_services

        if diagnostic_results.empty?
          show_healthy

          true
        else
          show_results

          false
        end
      end

      private

      attr_reader :diagnostics

      def diagnostic_results
        @diagnostic_results ||= jobs.map { |x| x.join[:results] }.compact
      end

      def jobs
        diagnostics.map do |diagnostic|
          Thread.new do
            Thread.current[:results] = perform_diagnosis_for(diagnostic)
            GDK::Output.print('.', stderr: true)
          end
        end
      end

      def perform_diagnosis_for(diagnostic)
        diagnostic.diagnose
        diagnostic.message unless diagnostic.success?
      end

      def start_necessary_services
        Shellout.new('gdk start postgresql').run
      end

      def show_healthy
        GDK::Output.puts("\n")
        GDK::Output.success('GDK is healthy.')
      end

      def show_results
        GDK::Output.puts("\n")
        GDK::Output.warn('GDK may need attention:')
        GDK::Output.puts("\n")
        GDK::Output.puts(warning)
        diagnostic_results.each do |result|
          GDK::Output.puts(result)
        end
      end

      def warning
        <<~WARNING
          #{'=' * 80}
          Please note these warning only exist for debugging purposes and can
          help you when you encounter issues with GDK.
          If your GDK is working fine, you can safely ignore them. Thanks!
          #{'=' * 80}
        WARNING
      end
    end
  end
end
