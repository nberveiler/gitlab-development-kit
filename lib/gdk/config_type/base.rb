# frozen_string_literal: true

module GDK
  module ConfigType
    class Base
      extend ::Forwardable

      attr_reader :builder, :parent, :value, :user_value

      def_delegators :builder, :key, :blk

      def initialize(parent:, builder:)
        @parent = parent
        @builder = builder

        read_value

        validate!
      end

      def read_value
        @value = @user_value = parent.yaml.fetch(key)
      rescue KeyError
        @value = default_value
      end

      def default_value
        parent.instance_eval(&blk)
      end

      def user_defined?
        !!defined?(@user_value)
      end

      def validate!
        orig_value = value

        return if parse

        raise ::TypeError, "Value '#{orig_value}' for #{slug} is not a valid #{type}"
      end

      def dump!(user_only: false)
        value
      end

      def slug
        [parent.slug, key].compact.join('.')
      end

      def root
        parent&.root || self
      end
      alias_method :config, :root

      private

      attr_writer :value

      def type
        self.class.name.split('::').last.downcase
      end
    end
  end
end
