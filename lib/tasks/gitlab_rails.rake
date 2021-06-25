# frozen_string_literal: true

require_relative '../gdk/gitlab_rails/db'

namespace :gitlab_rails do
  namespace :db do
    desc 'Run GitLab migrations'
    task :migrate do
      GDK::GitlabRails::DB.new.migrate
    end
  end
end
