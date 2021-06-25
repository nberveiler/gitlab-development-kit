# frozen_string_literal: true

module GDK
  module Output
    COLOR_CODE_RED = '31'
    COLOR_CODE_GREEN = '32'
    COLOR_CODE_YELLOW = '33'

    COLORS = {
      red: COLOR_CODE_RED,
      green: COLOR_CODE_GREEN,
      yellow: COLOR_CODE_YELLOW,
      blue: '34',
      magenta: '35',
      cyan: '36',
      bright_red: '31;1',
      bright_green: '32;1',
      bright_yellow: '33;1',
      bright_blue: '34;1',
      bright_magenta: '35;1',
      bright_cyan: '36;1'
    }.freeze

    ICONS = {
      info: "\u2139\ufe0f ",    # requires an extra space
      success: "\u2705\ufe0f",
      warning: "\u26A0\ufe0f ", # requires an extra space
      error: "\u274C\ufe0f"
    }.freeze

    def self.color(index)
      COLORS.values[index % COLORS.size]
    end

    def self.ansi(code)
      "\e[#{code}m"
    end

    def self.reset_color
      ansi(0)
    end

    def self.wrap_in_color(message, color_code)
      return message unless colorize?

      ansi(color_code) + message + reset_color
    end

    def self.print(message = nil, stderr: false)
      stderr ? $stderr.print(message) : $stdout.print(message)
    end

    def self.puts(message = nil, stderr: false)
      stderr ? Kernel.warn(message) : $stdout.puts(message)
    end

    def self.divider(symbol: '-', length: 80, stderr: false)
      puts(symbol * length, stderr: stderr)
    end

    def self.notice(message)
      puts(notice_format(message))
    end

    def self.notice_format(message)
      "=> #{message}"
    end

    def self.info(message)
      puts(icon(:info) + message)
    end

    def self.warn(message)
      puts(icon(:warning) + wrap_in_color('WARNING', COLOR_CODE_YELLOW) + ": #{message}", stderr: true)
    end

    def self.format_error(message)
      icon(:error) + wrap_in_color('ERROR', COLOR_CODE_RED) + ": #{message}"
    end

    def self.error(message)
      puts(format_error(message), stderr: true)
    end

    def self.abort(message)
      Kernel.abort(format_error(message))
    end

    def self.success(message)
      puts(icon(:success) + message)
    end

    def self.icon(code)
      return '' unless colorize?

      "#{ICONS[code]} "
    end

    def self.colorize?
      STDOUT.isatty && ENV.fetch('NO_COLOR', '').empty? # rubocop:disable Style/GlobalStdStream
    end

    def self.prompt(message)
      Kernel.print("#{message}: ")
      ARGF.gets.chomp
    end
  end
end
