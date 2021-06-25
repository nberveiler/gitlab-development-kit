# frozen_string_literal: true

module GDK
  module Command
    # Start all enabled services or specified ones only
    class Start < BaseCommand
      def run(args = [])
        unless args.delete('--help').nil?
          print_help
          return true
        end

        show_progress = !args.delete('--show-progress').nil?

        result = GDK::Hooks.with_hooks(config.gdk.start_hooks, 'gdk start') do
          Runit.start(args)
        end

        if args.empty?
          # Only print if run like `gdk start`, not e.g. `gdk start rails-web`
          print_url_ready_message

          # Only test URL if --show-progress specified
          test_url if show_progress
        end

        result
      end

      private

      def print_help
        help = <<~HELP
          Usage: gdk start [<args>]

            --help            Display help
            --show-progress   Indicate when GDK is ready to use
        HELP

        GDK::Output.puts(help)
      end

      def test_url
        GDK::TestURL.new(GDK::TestURL.default_url).wait
      end

      def print_url_ready_message
        GDK::Output.puts
        GDK::Output.notice("GitLab will be available at #{config.__uri} shortly.")
        GDK::Output.notice("GitLab Docs will be available at http://#{config.hostname}:#{config.gitlab_docs.port} shortly.") if config.gitlab_docs.enabled?
        GDK::Output.notice("GitLab Kubernetes Agent Server available at #{config.gitlab_k8s_agent.__url_for_agentk}.") if config.gitlab_k8s_agent?
      end
    end
  end
end
