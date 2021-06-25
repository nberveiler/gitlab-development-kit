# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::RedisCLI do
  context 'with no extra arguments' do
    it 'uses the development database by default' do
      expect_exec %w[redis-cli],
                  ['redis-cli', '-s', GDK.config.redis.__socket_file.to_s, { chdir: GDK.root }]
    end
  end

  context 'with extra arguments' do
    it 'uses custom arguments if present' do
      expect_exec %w[redis-cli --verbose],
                  ['redis-cli', '-s', GDK.config.redis.__socket_file.to_s, '--verbose', { chdir: GDK.root }]
    end
  end

  def expect_exec(input, cmdline)
    expect(subject).to receive(:exec).with(*cmdline)

    input.shift

    subject.run(input)
  end
end
