# frozen_string_literal: true

require_relative 'config'

module GDK
  # Config subclass to generate gdk.example.yml
  class ConfigExample < Config
    # Module that stubs reading from the environment
    module Stubbed
      def cmd!(_cmd)
        nil
      end

      def find_executable!(_bin)
        nil
      end

      def rand(max = 0)
        return max.first if max.is_a?(Range)

        0
      end

      def settings_klass
        ::GDK::ConfigExample::Settings
      end

      private

      def load_yaml!
        {}
      end

      def sanitized_read!(_filename)
        raise Errno::ENOENT
      end
    end

    # Environment stubbed GDK::ConfigSettings subclass
    class Settings < ::GDK::ConfigSettings
      prepend Stubbed
    end

    prepend Stubbed

    GDK_ROOT = '/home/git/gdk'

    # Avoid messing up the superclass (i.e. `GDK::Config`)
    @attributes = superclass.attributes.dup

    string(:username) { 'git' }
    array(:git_repositories) { [] }
  end
end
