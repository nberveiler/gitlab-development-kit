# frozen_string_literal: true

module GDK
  module ConfigType
    class Settings
      def self.new(parent:, builder:, **kwargs)
        yaml = parent.yaml.fetch(builder.key, {})

        Class.new(parent.settings_klass).tap do |k|
          k.class_eval(&builder.blk)
        end.new(key: builder.key, parent: parent, yaml: yaml)
      end
    end
  end
end
