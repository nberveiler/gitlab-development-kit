# frozen_string_literal: true

require_relative 'base'

module GDK
  module ConfigType
    class String < Base
      def parse
        return false if value.nil?

        self.value = value.to_s

        true
      end
    end
  end
end
