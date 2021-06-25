# frozen_string_literal: true

require 'yaml'
require 'mkmf'
require 'forwardable'
require_relative 'config_type/builder'
require_relative 'config_type/anything'
require_relative 'config_type/array'
require_relative 'config_type/bool'
require_relative 'config_type/hash'
require_relative 'config_type/integer'
require_relative 'config_type/path'
require_relative 'config_type/settings'
require_relative 'config_type/settings_array'
require_relative 'config_type/string'

MakeMakefile::Logging.quiet = true
MakeMakefile::Logging.logfile(File::NULL)

module GDK
  class ConfigSettings
    extend ::Forwardable

    SettingUndefined = Class.new(StandardError)
    UnsupportedConfiguration = Class.new(StandardError)

    attr_reader :parent, :yaml, :key

    def_delegators :'self.class', :attributes

    class << self
      attr_accessor :attributes

      def anything(key, &blk)
        def_attribute(key, ConfigType::Anything, &blk)
      end

      def array(key, merge: false, &blk)
        def_attribute(key, ConfigType::Array, merge: merge, &blk)
      end

      def hash_setting(key, merge: false, &blk)
        def_attribute(key, ConfigType::Hash, merge: merge, &blk)
      end

      def bool(key, &blk)
        def_attribute(key, ConfigType::Bool, &blk)
        alias_method "#{key}?", key
      end

      def integer(key, &blk)
        def_attribute(key, ConfigType::Integer, &blk)
      end

      def path(key, &blk)
        def_attribute(key, ConfigType::Path, &blk)
      end

      def string(key, &blk)
        def_attribute(key, ConfigType::String, &blk)
      end

      def settings(key, &blk)
        def_attribute(key, ConfigType::Settings, &blk)
      end

      def settings_array(key, size:, &blk)
        def_attribute(key, ConfigType::SettingsArray, size: size, &blk)
      end

      private

      def def_attribute(key, klass, **kwargs, &blk)
        key = key.to_s
        self.attributes ||= {} # Using a hash to ensure uniqueness on key
        self.attributes[key] = ConfigType::Builder.new(key: key, klass: klass, **kwargs, &blk)

        define_method(key) do
          build(key).value
        end
      end
    end

    def initialize(key: nil, parent: nil, yaml: nil)
      @key = key
      @parent = parent
      @yaml = yaml || load_yaml!
    end

    def validate!
      attributes.each_value do |attribute|
        next if attribute.ignore?

        attribute.build(parent: self).validate!
      end

      nil
    end

    def dump!(user_only: false)
      attributes.values.sort_by(&:key).each_with_object({}) do |attribute, result|
        # We don't dump a config if it:
        #  - starts with a double underscore (intended for internal use)
        #  - is a ? method (always has a non-? counterpart)
        next if attribute.ignore?

        attr_value = attribute.build(parent: self)
        next if user_only && !attr_value.user_defined?

        result[attribute.key] = attr_value.dump!(user_only: user_only)
      end
    end

    def dump_as_yaml
      dump!.to_yaml
    end

    def cmd!(cmd)
      # Passing an array to IO.popen guards against sh -c.
      # https://gitlab.com/gitlab-org/gitlab/blob/master/doc/development/shell_commands.md#bypass-the-shell-by-splitting-commands-into-separate-tokens
      raise ::ArgumentError, 'Command must be an array' unless cmd.is_a?(Array)

      IO.popen(cmd, chdir: GDK.root, &:read).chomp
    end

    def find_executable!(bin)
      MakeMakefile.find_executable(bin)
    end

    def read!(filename)
      sanitized_read!(filename)
    rescue Errno::ENOENT
      nil
    end

    def read_or_write!(filename, value)
      sanitized_read!(filename)
    rescue Errno::ENOENT
      File.write(GDK.root.join(filename), value)
      value
    end

    def user_defined?
      yaml&.any?
    end

    def fetch(slug, *args)
      raise ::ArgumentError, %[Wrong number of arguments (#{args.count + 1} for 1..2)] if args.count > 1

      return public_send(slug) if respond_to?(slug) # rubocop:disable GitlabSecurity/PublicSend

      raise SettingUndefined, %(Could not fetch the setting '#{slug}' in '#{self.slug || '<root>'}') if args.empty?

      args.first
    end

    def [](slug)
      fetch(slug, nil)
    end

    def dig(*slugs)
      slugs = slugs.first.to_s.split('.') if slugs.one?

      value = fetch(slugs.shift)

      return value if slugs.empty?

      value.dig(*slugs)
    end

    def config_file_protected?(target)
      return false if gdk.overwrite_changes

      gdk.protected_config_files&.any? { |pattern| File.fnmatch(pattern, target) }
    end

    def slug
      return nil unless parent

      [parent.slug, key].compact.join('.')
    end

    def root
      parent&.root || self
    end
    alias_method :config, :root

    def inspect
      return "#<#{self.class.name}>" if self.class.name

      "#<GDK::ConfigSettings slug:#{slug}>"
    end

    def to_s
      dump!.to_yaml
    end

    alias_method :value, :itself

    # Provide a shorter form for `config.setting.enabled` as `config.setting?`
    def method_missing(method_name, *args, &blk)
      enabled = enabled_value(method_name)

      return super if enabled.nil?

      enabled
    end

    def respond_to_missing?(method_name, include_private = false)
      !enabled_value(method_name).nil? || super
    end

    def settings_klass
      ::GDK::ConfigSettings
    end

    private

    def attribute(key)
      attributes[key]
    end

    def build(key)
      attribute(key).build(parent: self)
    end

    def enabled_value(method_name)
      return nil unless method_name.to_s.end_with?('?')

      chopped_name = method_name.to_s.chop.to_sym
      fetch(chopped_name, nil)&.fetch(:enabled, nil)
    end

    def load_yaml!
      return {} unless defined?(self.class::FILE) && File.exist?(self.class::FILE)

      raw_yaml = File.read(self.class::FILE)
      YAML.safe_load(raw_yaml) || {}
    end

    def from_yaml(slug, default: nil)
      yaml.has_slug?(slug) ? yaml[slug] : default
    end

    def sanitized_read!(filename)
      File.read(GDK.root.join(filename)).chomp
    end
  end
end
