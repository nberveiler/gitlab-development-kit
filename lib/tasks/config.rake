# frozen_string_literal: true

CONFIGS = FileList['Procfile', 'nginx/conf/nginx.conf', 'gitlab/config/gitlab.yml', 'prometheus/prometheus.yml']
CLOBBER.include(*CONFIGS, 'gdk.example.yml')

def config
  @config ||= GDK::Config.new
end

desc 'Dump the configured settings'
task 'dump_config' do
  puts GDK::Config.new.dump_as_yaml
end

desc 'Generate an example config file with all the defaults'
file 'gdk.example.yml' => 'clobber:gdk.example.yml' do |t|
  require 'gdk/config_example'

  begin
    yaml = GDK::ConfigExample.new.dump_as_yaml
    File.open(t.name, File::CREAT | File::TRUNC | File::WRONLY).write(yaml)
  rescue TypeError => e
    GDK::Output.abort(e)
  end
end

desc 'Regenerate all config files from scratch'
task reconfigure: [:clobber, :all]

desc 'Generate all config files'
task all: CONFIGS

task 'clobber:gdk.example.yml' do |t|
  Rake::Cleaner.cleanup_files([t.name])
end

file GDK::Config::FILE do |t|
  FileUtils.touch(t.name)
end

desc 'Generate Procfile that defines the list of services to start'
file 'Procfile' => ['support/templates/Procfile.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).render!
end

# Define as a task instead of a file, so it's built unconditionally
task 'gdk-config.mk' => 'support/templates/gdk-config.mk.erb' do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).render!
  puts t.name # Print the filename, so make can include it
end

desc 'Generate nginx configuration'
file 'nginx/conf/nginx.conf' => ['support/templates/nginx/conf/nginx.conf.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate sshd configuration'
file 'openssh/sshd_config' => ['support/templates/openssh/sshd_config.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate redis configuration'
file 'redis/redis.conf' => ['support/templates/redis.conf.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the database.yml config file'
file 'gitlab/config/database.yml' => ['support/templates/database.yml.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the cable.yml config file'
file 'gitlab/config/cable.yml' => ['support/templates/cable.yml.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the resque.yml config file'
file 'gitlab/config/resque.yml' => ['support/templates/resque.yml.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the database_geo.yml config file'
file 'gitlab/config/database_geo.yml' => ['support/templates/database_geo.yml.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the gitlab.yml config file'
file 'gitlab/config/gitlab.yml' => ['support/templates/gitlab.yml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the puma.rb config file'
file 'gitlab/config/puma.rb' => ['support/templates/puma.rb.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the gitlab-shell config.yml file'
file 'gitlab-shell/config.yml' => ['support/templates/gitlab-shell.config.yml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the gitlab-workhorse config file'
file 'gitlab/workhorse/config.toml' => ['support/templates/gitlab-workhorse.config.toml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the gitlab-pages config file'
file 'gitlab-pages/gitlab-pages.conf' => ['support/templates/gitlab-pages.conf.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate the gitlab-pages secret file'
file 'gitlab-pages-secret' => ['support/templates/gitlab-pages-secret.erb', GDK::Config::FILE] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

desc 'Generate gitaly config toml'
file 'gitaly/gitaly.config.toml' => ['support/templates/gitaly.config.toml.erb'] do |t|
  GDK::ErbRenderer.new(
    t.source,
    t.name,
    config: config,
    node: config.gitaly
  ).safe_render!
  config.gitaly.__storages.each do |storage|
    FileUtils.mkdir_p(storage.path)
  end
  FileUtils.mkdir_p(config.gitaly.log_dir)
end

file 'gitaly/praefect.config.toml' => ['support/templates/praefect.config.toml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).render!

  config.praefect.__nodes.each_with_index do |node, index|
    Rake::Task[node['config_file']].invoke
  end

  FileUtils.mkdir_p(config.praefect.internal_socket_dir)
end

config.praefect.__nodes.each do |node|
  desc "Generate gitaly config for #{node['storage']}"
  file node['config_file'] => ['support/templates/gitaly.config.toml.erb'] do |t|
    GDK::ErbRenderer.new(
      t.source,
      t.name,
      config: config,
      node: node
    ).safe_render!
    node.__storages.each do |storage|
      FileUtils.mkdir_p(storage.path)
    end
    FileUtils.mkdir_p(node['log_dir'])
    FileUtils.mkdir_p(node['internal_socket_dir'])
  end
end

file 'registry/config.yml' => ['support/templates/registry.config.yml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

file 'gitlab-runner-config.toml' => ['support/templates/gitlab-runner-config.toml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

file 'prometheus/prometheus.yml' => ['support/templates/prometheus.yml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
  chmod('+r', t.name)
end

file 'gitlab-k8s-agent-config.yml' => ['support/templates/gitlab-k8s-agent-config.yml.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end

file 'grafana/grafana.ini' => ['support/templates/grafana.ini.erb'] do |t|
  GDK::ErbRenderer.new(t.source, t.name, config: config).safe_render!
end
