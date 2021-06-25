# frozen_string_literal: true

module GDK
  module ConfigType
    module Mergable
      attr_reader :merge

      def initialize(parent:, builder:, merge: false)
        @merge = merge

        super(parent: parent, builder: builder)
      end

      def read_value
        super

        @value = mergable_merge(user_value, default_value) if merge
      end
    end
  end
end
