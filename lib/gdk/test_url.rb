# frozen_string_literal: true

module GDK
  class TestURL
    MAX_ATTEMPTS = 90

    UrlAppearsInvalid = Class.new(StandardError)

    def self.default_url
      "#{GDK.config.__uri}/users/sign_in"
    end

    def initialize(url, quiet: true)
      raise UrlAppearsInvalid unless URI::DEFAULT_PARSER.make_regexp.match?(url)

      @uri = URI.parse(url)
      @quiet = quiet
    end

    def wait
      @start_time = Time.now

      GDK::Output.print(GDK::Output.notice_format("Waiting until #{uri} is ready.."))
      GDK::Output.puts unless quiet

      if check_url
        GDK::Output.puts
        GDK::Output.notice("#{uri} is up (#{http_helper.last_response_reason}). Took #{duration} second(s).")
        true
      else
        GDK::Output.notice("#{uri} does not appear to be up. Waited #{duration} second(s).")
        false
      end
    end

    private

    attr_reader :uri, :quiet, :start_time

    def check_url
      1.upto(MAX_ATTEMPTS) do |i|
        if quiet
          GDK::Output.print('.')
        else
          GDK::Output.puts
          GDK::Output.puts("> Testing attempt ##{i}..")
        end

        return true if http_helper.up?

        GDK::Output.puts(http_helper.last_response_reason) unless quiet

        sleep(sleep_between_attempts)
      end

      GDK::Output.puts
      false
    end

    def duration
      (Time.now - start_time).round(2)
    end

    def sleep_between_attempts
      @sleep_between_attempts ||= quiet ? 5 : 1
    end

    def http_helper
      @http_helper ||= GDK::HTTPHelper.new(uri, cache_response: false)
    end
  end
end
