# frozen_string_literal: true

module GDK
  module Hooks
    def self.with_hooks(hooks, name)
      execute_hooks(hooks[:before], "#{name}: before")
      result = block_given? ? yield : true
      execute_hooks(hooks[:after], "#{name}: after")

      result
    end

    def self.execute_hooks(hooks, description)
      hooks.each do |cmd|
        execute_hook_cmd(cmd, description)
      end

      true
    end

    def self.execute_hook_cmd(cmd, description)
      GDK::Output.abort("Cannot execute '#{description}' hook '#{cmd}' as it's invalid") unless cmd.is_a?(String)

      GDK::Output.info("#{description} hook -> #{cmd}")

      sh = Shellout.new(cmd, chdir: GDK.root)
      sh.stream

      raise HookCommandError, "'#{cmd}' has exited with code #{sh.exit_code}." unless sh.success?

      true
    rescue HookCommandError, Errno::ENOENT => e
      GDK::Output.abort(e.message)
    end
  end
end
