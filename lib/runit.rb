# frozen_string_literal: true

require 'mkmf'
require 'pathname'

require_relative 'shellout'
require_relative 'runit/config'
require_relative 'gdk/output'

MakeMakefile::Logging.quiet = true
MakeMakefile::Logging.logfile(File::NULL)

module Runit
  SERVICE_SHORTCUTS = {
    'rails' => 'rails-*',
    'tunnel' => 'tunnel_*',
    'praefect' => 'praefect*',
    'gitaly' => '{gitaly,praefect*}',
    'db' => '{redis,postgresql,postgresql-geo}',
    'rails-migration-dependencies' => '{redis,postgresql,postgresql-geo,gitaly,praefect*}'
  }.freeze

  SERVICES_DIR = Pathname.new(__dir__).join("../services").expand_path

  STOP_RETRY_COUNT = 3

  def self.start_runsvdir
    Dir.chdir(GDK.root)

    runit_installed!

    runit_config = Runit::Config.new(GDK.root)
    runit_config.render

    # It is important that we use an absolute path with `runsvdir`: this
    # allows us to distinguish processes belonging to different GDK
    # installations on the same machine.
    args = runsvdir_base_args
    return if runsvdir_pid(args)

    dots = '.' * 395

    Process.fork do
      Dir.chdir('/')
      Process.setsid

      # Cargo-culting the use of 395 periods from omnibus-gitlab.
      # https://gitlab.com/gitlab-org/omnibus-gitlab/blob/5dfdcafa30ad6e203a04a917f180b630d5121cf6/config/templates/runit/runsvdir-start.erb#L42
      args << "log: #{dots}"

      spawn(cleaned_path_env, *args, in: '/dev/null', out: '/dev/null', err: '/dev/null')
    end
  end

  # Runit does not handle ENOTDIR from execve well, so let's try to
  # prevent that.
  # https://gitlab.com/gitlab-org/gitlab-development-kit/issues/666#note_241939982
  def self.cleaned_path_env
    valid_path_entries = ENV['PATH'].split(File::PATH_SEPARATOR).select do |dir|
      File.directory?(dir)
    end

    { 'PATH' => valid_path_entries.join(File::PATH_SEPARATOR) }
  end

  def self.runsvdir_base_args
    ['runsvdir', '-P', GDK.root.join('services').to_s]
  end

  def self.runsvdir_pid(args)
    pgrep = Shellout.new(%w[pgrep runsvdir]).run
    return if pgrep.empty?

    pids = pgrep.split("\n").map { |str| Integer(str) }
    runsvdir_ps = "#{args.join(' ')} "

    pids.find do |pid|
      Shellout.new(%W[ps -o args= -p #{pid}]).run.start_with?(runsvdir_ps)
    end
  end

  def self.runit_installed!
    return if MakeMakefile.find_executable('runsvdir')

    abort <<~MESSAGE

      ERROR: gitlab-development-kit requires Runit to be installed.
      You can install Runit with:

        #{runit_instructions}

    MESSAGE
  end

  def self.runit_instructions
    if File.executable?('/usr/local/bin/brew') # Homebrew
      'brew install runit'
    elsif File.executable?('/opt/local/bin/port') # MacPorts
      'sudo port install runit'
    elsif File.executable?('/usr/bin/apt') # Debian / Ubuntu
      'sudo apt install runit'
    else
      '(no copy-paste Runit installation snippet available for your OS)'
    end
  end

  def self.start(args)
    if args.empty?
      # Redis, PostgresSQL, etc should be started first.
      data_oriented_service_names.reverse_each { |service_name| sv('start', [service_name]) }
      sv('start', non_data_oriented_service_names)
    else
      sv('start', args)
    end
  end

  def self.stop
    # Redis, PostgresSQL, etc should be stopped last.
    stop_services(non_data_oriented_service_names)
    data_oriented_service_names.each { |service_name| stop_services([service_name]) }

    unload_runsvdir!

    GDK::Output.puts
    GDK::Output.success('All services have been stopped!')

    true
  end

  def self.stop_services(services)
    # The first stop attempt may fail; ignore its return value.
    stopped = false

    STOP_RETRY_COUNT.times do |i|
      # From http://smarden.org/runit/sv.8.html:
      #
      # down: If the service is running, send it the TERM signal, and the CONT signal. If ./run exits, start ./finish if it exists. After it stops, do not restart service.
      # force-stop: Same as down, but wait up to (default) 7 seconds for the service to become down. Then report the status, and on timeout send the service the kill command.
      #
      stopped = sv('force-stop', services)
      break if stopped

      GDK::Output.notice("Retrying stop (#{i + 1}/#{STOP_RETRY_COUNT})")
    end

    true
  end

  def self.unload_runsvdir!
    # Unload runsvdir: this is safe because we have just stopped all services.
    pid = runsvdir_pid(runsvdir_base_args)
    Process.kill('HUP', pid)
  end

  def self.sv(cmd, services)
    Dir.chdir(GDK.root)
    start_runsvdir
    services = service_args(services)
    services.each { |svc| wait_runsv!(svc) }

    system('sv', '-w', config.gdk.runit_wait_secs.to_s, cmd, *services)
  end

  def self.data_oriented_service_names
    %w[minio openldap gitaly praefect redis postgresql-geo postgresql].select do |x|
      Dir.exist?(File.join(SERVICES_DIR, x))
    end
  end

  def self.non_data_oriented_service_names
    all_service_names - data_oriented_service_names
  end

  def self.all_service_names
    # praefect-gitaly-* services are stopped/started automatically.
    Pathname.new(SERVICES_DIR).children.filter_map do |path|
      path.basename.to_s if path.directory? && !path.to_s.start_with?('praefect-gitaly-')
    end.sort
  end

  def self.service_args(services)
    return Dir["#{SERVICES_DIR}/*"].sort if services.empty?

    services.flat_map do |svc|
      service_shortcut(svc) || File.join(SERVICES_DIR, svc)
    end.uniq.sort
  end

  def self.service_shortcut(svc)
    glob = SERVICE_SHORTCUTS[svc]
    return unless glob

    if glob.include?('/')
      GDK::Output.error "invalid service shortcut: #{svc} -> #{glob}"

      abort
    end

    Dir[File.join(SERVICES_DIR, glob)]
  end

  def self.wait_runsv!(dir)
    unless File.directory?(dir)
      GDK::Output.error "unknown runit service: #{dir}"

      abort
    end

    50.times do
      begin
        File.open(File.join(dir, 'supervise/ok'), File::WRONLY | File::NONBLOCK).close
      rescue StandardError
        sleep 0.1
        next
      end
      return
    end

    GDK::Output.error "timeout waiting for runsv in #{dir}"

    abort
  end

  def self.tail(services)
    Dir.chdir(GDK.root)

    tails = log_files(services).map do |log|
      # It looks like 'tail -F' is a non-standard flag that exists in GNU tail
      # and on macOS/FreeBSD. We use it because we want to detect the log file
      # disappearing, and reopen the log file when that happens. If we ever
      # want to revisit this decision, we could make our own "file replacement
      # detector" as in
      # https://gitlab.com/gitlab-org/gitlab-development-kit/merge_requests/881/diffs
      # .
      spawn('tail', '-F', log)
    end

    %w[INT TERM].each do |sig|
      trap(sig) { kill_processes(tails) }
    end

    wait = Thread.new { sleep }
    tails.each do |tail|
      Thread.new do
        Process.wait(tail)
        wait.kill
      end
    end

    wait.join
    kill_processes(tails)
    exit
  end

  def self.log_files(services)
    return Dir['log/*/current'] if services.empty?

    services.flat_map do |svc|
      log_shortcut(svc) || File.join('log', svc, 'current')
    end.uniq
  end

  def self.log_shortcut(svc)
    glob = SERVICE_SHORTCUTS[svc]
    return unless glob

    if glob.include?('/')
      GDK::Output.error "invalid service shortcut: #{svc} -> #{glob}"

      abort
    end

    Dir[File.join('./log', glob, 'current')]
  end

  def self.kill_processes(pids)
    pids.each do |pid|
      Process.kill('TERM', pid)
    rescue Errno::ESRCH
    end
  end

  def self.config
    @config ||= GDK::Config.new
  end
end
