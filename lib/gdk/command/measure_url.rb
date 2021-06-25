# frozen_string_literal: true

module GDK
  module Command
    class MeasureUrl < MeasureBase
      def run(urls_or_paths)
        @urls_or_paths = Array(urls_or_paths)

        super
      end

      private

      attr_reader :urls_or_paths

      def check!
        GDK::Output.abort('Please add URL(s) as an argument (e.g. http://localhost:3000/explore, /explore or https://gitlab.com/explore)') if urls.empty?
        super
      end

      def gdk_ok?
        return true unless has_local_url?

        gdk_running?
      end

      def use_git_branch_name?
        has_local_url?
      end

      def urls
        @urls ||= begin
          urls_or_paths.map do |url|
            # Transform local relative URL's
            url = "#{config.__uri}#{url}" if url_is_local?(url)

            url = url.gsub('localhost', 'host.docker.internal')
            url.gsub('127.0.0.1', 'host.docker.internal')
          end
        end.uniq
      end
      alias_method :items, :urls

      def url_is_local?(url)
        url.start_with?('/')
      end

      def has_local_url?
        @has_local_url ||= urls_or_paths.any? { |url| url_is_local?(url) }
      end

      def docker_command
        super << urls.join(' ')
      end
    end
  end
end
