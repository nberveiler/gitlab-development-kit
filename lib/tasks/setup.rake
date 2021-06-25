# frozen_string_literal: true

desc 'Preflight checks for dependencies'
task 'preflight-checks' do
  checker = GDK::Dependencies::Checker.new
  checker.check_all

  unless checker.error_messages.empty?
    warn checker.error_messages
    exit 1
  end
end

desc 'Preflight Update checks'
task 'preflight-update-checks' do
  postgresql = GDK::Postgresql.new
  if postgresql.installed? && postgresql.upgrade_needed?
    message = <<~MESSAGE
      PostgreSQL data directory is version #{postgresql.current_version} and must be upgraded to version #{postgresql.class::TARGET_VERSION} before GDK can be updated.

      Run 'support/upgrade-postgresql' to back up and upgrade the PostgreSQL data directory.

    MESSAGE

    GDK::Output.abort(message)
  end
end
