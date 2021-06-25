# frozen_string_literal: true

require_relative 'teammate'
require_relative 'title_linting'

module Tooling
  module Danger
    module Helper
      RELEASE_TOOLS_BOT = 'gitlab-release-tools-bot'

      # Returns a list of all files that have been added, modified or renamed.
      # `git.modified_files` might contain paths that already have been renamed,
      # so we need to remove them from the list.
      #
      # Considering these changes:
      #
      # - A new_file.rb
      # - D deleted_file.rb
      # - M modified_file.rb
      # - R renamed_file_before.rb -> renamed_file_after.rb
      #
      # it will return
      # ```
      # [ 'new_file.rb', 'modified_file.rb', 'renamed_file_after.rb' ]
      # ```
      #
      # @return [Array<String>]
      def all_changed_files
        Set.new
          .merge(git.added_files.to_a)
          .merge(git.modified_files.to_a)
          .merge(git.renamed_files.map { |x| x[:after] })
          .subtract(git.renamed_files.map { |x| x[:before] })
          .to_a
          .sort
      end

      # Returns a string containing changed lines as git diff
      #
      # Considering changing a line in lib/gitlab/usage_data.rb it will return:
      #
      # [ "--- a/lib/gitlab/usage_data.rb",
      #   "+++ b/lib/gitlab/usage_data.rb",
      #   "+      # Test change",
      #   "-      # Old change" ]
      def changed_lines(changed_file)
        diff = git.diff_for_file(changed_file)
        return [] unless diff

        diff.patch.split("\n").select { |line| %r{^[+-]}.match?(line) }
      end

      def gitlab_helper
        # Unfortunately the following does not work:
        # - respond_to?(:gitlab)
        # - respond_to?(:gitlab, true)
        gitlab
      rescue NameError
        nil
      end

      def release_automation?
        gitlab_helper&.mr_author == RELEASE_TOOLS_BOT
      end

      def project_name
        'gitlab-development-kit'
      end

      def markdown_list(items)
        list = items.map { |item| "* `#{item}`" }.join("\n")

        if items.size > 10
          "\n<details>\n\n#{list}\n\n</details>\n"
        else
          list
        end
      end

      # @return [Hash<String,Array<String>>]
      def changes_by_category
        all_changed_files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |file, hash|
          categories_for_file(file).each { |category| hash[category] << file }
        end
      end

      # Determines the categories a file is in, e.g., `[:default]`
      # using filename regex and specific change regex if given.
      #
      # @return Array<Symbol>
      def categories_for_file(file)
        _, categories = CATEGORIES.find do |key, _|
          filename_regex, changes_regex = Array(key)

          found = filename_regex.match?(file)
          found &&= changed_lines(file).any? { |changed_line| changes_regex.match?(changed_line) } if changes_regex

          found
        end

        Array(categories || :unknown)
      end

      # Returns the GFM for a category label, making its best guess if it's not
      # a category we know about.
      #
      # @return[String]
      def label_for_category(category)
        CATEGORY_LABELS.fetch(category, "~#{category}")
      end

      CATEGORY_LABELS = {
        docs: "~documentation", # Docs are reviewed along DevOps stages, so don't need roulette for now.
        none: "",
      }.freeze

      # First-match win, so be sure to put more specific regex at the top...
      CATEGORIES = {
        %r{\Adoc/.*(\.(md|png|gif|jpg))\z} => :docs,
        %r{\A(CONTRIBUTING|LICENSE|MAINTENANCE|PHILOSOPHY|PROCESS|README)(\.md)?\z} => :docs,

        %r{.*} => :default
      }.freeze

      def mr_title
        return '' unless gitlab_helper

        gitlab_helper.mr_json['title']
      end

      def labels_list(labels, sep: ', ')
        labels.map { |label| %Q{~"#{label}"} }.join(sep)
      end

      def changed_files(regex)
        all_changed_files.grep(regex)
      end
    end
  end
end
