# frozen_string_literal: true

require 'net/http'

module GDK
  class HTTPHelper
    attr_reader :last_response_reason

    def initialize(uri, read_timeout: 5, open_timeout: 5, cache_response: true)
      raise 'uri needs to be an instance of URI' unless uri.is_a?(URI)

      @uri = uri
      @read_timeout = read_timeout
      @open_timeout = open_timeout
      @cache_response = cache_response
    end

    def up?(codes_to_consider_up: %w[200 301 302])
      response_to_process = cache_response ? cached_response : response
      return false unless response_to_process

      codes_to_consider_up.include?(response_to_process.code)
    end

    private

    attr_reader :uri, :read_timeout, :open_timeout, :cache_response

    def cached_response
      @cached_response ||= response
    end

    def response
      resp = http_client.start do |http|
        path = uri.path.empty? ? '/' : uri.path
        http.get(path)
      end

      @last_response_reason = "#{resp.code} #{resp.message}"
      resp
    rescue Errno::ECONNREFUSED
      @last_response_reason = 'Connection refused'
      false
    rescue Net::ReadTimeout
      @last_response_reason = 'Request timed out'
      false
    end

    def http_client
      Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.read_timeout = read_timeout
        client.open_timeout = open_timeout
        client.use_ssl = uri.port == 443
      end
    end
  end
end
