# frozen_string_literal: true

require 'simplecov-cobertura'
require 'tzinfo'

# rubocop:disable Layout/FirstArrayElementIndentation
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::SimpleFormatter,
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CoberturaFormatter
])
# rubocop:enable Layout/FirstArrayElementIndentation

SimpleCov.start

require_relative '../lib/gdk'

RSpec.configure do |config|
  config.before do |example|
    allow(GDK::Output).to receive(:puts) if example.metadata[:hide_stdout]

    if example.metadata[:hide_output]
      allow(GDK::Output).to receive(:print)
      allow(GDK::Output).to receive(:puts)
      allow(GDK::Output).to receive(:info)
      allow(GDK::Output).to receive(:warn)
      allow(GDK::Output).to receive(:error)
      allow(GDK::Output).to receive(:abort)
      allow(GDK::Output).to receive(:success)
    end

    # isolate configs for the testing environment
    allow(GDK).to receive(:root) { Pathname.new(temp_path) }
    stub_const('GDK::Config::GDK_ROOT', '/home/git/gdk')
    stub_const('GDK::Config::FILE', 'gdk.example.yml')
  end

  config.disable_monkey_patching
end

def utc_now
  TZInfo::Timezone.get('UTC').now
end

def freeze_time(&blk)
  travel_to(&blk)
end

def travel_to(now = utc_now)
  # Copied from https://github.com/rails/rails/blob/v6.1.3/activesupport/lib/active_support/testing/time_helpers.rb#L163-L165
  #
  allow(Time).to receive(:now).and_return(now)
  allow(Date).to receive(:today).and_return(Date.jd(now.to_date.jd))
  allow(DateTime).to receive(:now).and_return(DateTime.jd(now.to_date.jd, now.hour, now.min, now.sec, Rational(now.utc_offset, 86400)))

  yield

  allow(Time).to receive(:now).and_call_original
  allow(Date).to receive(:today).and_call_original
  allow(DateTime).to receive(:now).and_call_original
end

def spec_path
  Pathname.new(__dir__).expand_path
end

def fixture_path
  spec_path.join('fixtures')
end

def temp_path
  spec_path.parent.join('tmp')
end

def stub_env_lookups
  allow(ENV).to receive(:fetch).and_call_original
  allow(ENV).to receive(:[]).and_call_original
end

def stub_env(var, value)
  allow(ENV).to receive(:fetch).with(var, '').and_return(value)
  allow(ENV).to receive(:[]).with(var).and_return(value)
end

def stub_gdk_yaml(yaml)
  allow(GDK).to receive(:config) { GDK::Config.new(yaml: yaml) }
end

def stub_pg_bindir
  fake_io = double('IO', read: '/usr/local/bin')
  allow(IO).to receive(:popen).and_call_original
  allow(IO).to receive(:popen).with(%w[support/pg_bindir], any_args).and_yield(fake_io)
end

def stub_tty(state)
  allow($stdout).to receive(:isatty).and_return(state)
end

def stub_no_color_env(res)
  stub_tty(true)

  # res needs to be of type String as we're simulating what's coming from
  # the shell command line.
  stub_env('NO_COLOR', res)
end
