# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Start do
  let(:hooks) { %w[date] }
  let(:default_url) { 'http://127.0.0.1:3000/users/sign_in' }

  before do
    allow_any_instance_of(GDK::Config).to receive_message_chain('gdk.start_hooks').and_return(hooks)
  end

  describe '#run' do
    context 'asking for help' do
      it 'prints help and exits' do
        expect { subject.run(%w[--help]) }.to output(/--help            Display help/).to_stdout
      end
    end

    context 'with no extra arguments' do
      context 'without progress' do
        it 'executes hooks and starts all enabled services' do
          stub_gdk_start

          expect_runit_start_to_execute([])

          expect { subject.run }.to output(/GitLab will be available at/).to_stdout
        end
      end

      context 'with progress' do
        it 'executes hooks, starts all enabled services and waits until up' do
          stub_gdk_start

          expect_runit_start_to_execute([])

          test_url_double = instance_double(GDK::TestURL, wait: true)
          expect(GDK::TestURL).to receive(:new).with(default_url).and_return(test_url_double)

          expect { subject.run(%w[--show-progress]) }.to output(/GitLab will be available at/).to_stdout
        end
      end
    end

    context 'with extra arguments' do
      context 'without progress' do
        it 'executes hooks and starts specified services' do
          services = %w[rails-web]

          stub_gdk_start
          expect_runit_start_to_execute(services)

          subject.run(services)
        end
      end

      context 'with progress' do
        it 'executes hooks and starts specified services and ignores --show-progress' do
          services = %w[rails-web]

          stub_gdk_start
          expect_runit_start_to_execute(services)
          expect(GDK::TestURL).not_to receive(:new).with(default_url)

          subject.run(services + %w[--show-progress])
        end
      end
    end
  end

  def expect_runit_start_to_execute(args = [])
    expect(Runit).to receive(:start).with(args).and_return(true)
  end

  def stub_gdk_start
    allow(GDK::Hooks).to receive(:with_hooks).with(hooks, 'gdk start').and_yield
  end
end
