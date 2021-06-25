# frozen_string_literal: true

# rubocop:todo Gitlab/NamespacedClass
class GitlabDanger
  CI_ONLY_RULES ||= %w[
    roulette
  ].freeze

  MESSAGE_PREFIX = '==>'

  attr_reader :gitlab_danger_helper

  def initialize(gitlab_danger_helper)
    @gitlab_danger_helper = gitlab_danger_helper
  end

  def self.success_message
    "#{MESSAGE_PREFIX} No Danger rule violations!"
  end

  def rule_names
    ci? ? CI_ONLY_RULES : []
  end

  def html_link(str)
    ci? ? gitlab_danger_helper.html_link(str) : str
  end

  def ci?
    !gitlab_danger_helper.nil?
  end
end
