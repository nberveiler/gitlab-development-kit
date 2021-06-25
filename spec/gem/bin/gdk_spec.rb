# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gdk' do
  describe 'version' do
    let!(:gdk_bin_full_path) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'gem', 'bin', 'gdk')) }

    context 'within a GDK directory' do
      it 'returns version including git SHA' do
        git_sha = `git rev-parse --short HEAD`.chomp

        expect(`#{gdk_bin_full_path} version`).to eql("GitLab Development Kit 0.2.14 (#{git_sha})\n")
      end
    end

    context 'outside a GDK directory' do
      it 'returns version without git SHA' do
        output = Dir.chdir('/tmp') { `#{gdk_bin_full_path} version` }

        expect(output).to eql("GitLab Development Kit 0.2.14\n")
      end
    end
  end
end
