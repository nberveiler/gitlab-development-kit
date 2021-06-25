# frozen_string_literal: true

require 'spec_helper'
require 'helpers/measure_helper'

RSpec.describe GDK::Command::MeasureWorkflow do
  include MeasureHelper

  let(:docker_running) { nil }

  before do
    stub_tty(false)
  end

  describe '#run' do
    before do
      stub_docker_check(is_running: docker_running)
    end

    context 'when an empty workflow array is provided' do
      it 'aborts' do
        expected_error = 'ERROR: Please add a valid workflow(s) as an argument (e.g. repo_browser)'
        workflows = []

        expect { subject.run(workflows) }.to raise_error(expected_error).and output("#{expected_error}\n").to_stderr
      end
    end

    include_examples 'it checks if Docker and GDK are running', %w[repo_browser]

    context 'when Docker and GDK are running' do
      let(:docker_running) { true }
      let(:branch_name) { 'some-branch-name' }

      before do
        stub_gdk_check(is_running: true)
        stub_git_rev_parse(branch_name: branch_name)
      end

      it 'runs sitespeed via Docker for the given workflow(s)', :hide_stdout do
        freeze_time do
          report_file_path = "sitespeed-result/#{branch_name}_#{Time.now.strftime('%F-%H-%M-%S')}"
          workflows = %w[repo_browser]
          shellout_docker_run_double = double('Shellout', stream: '', success?: true)
          expect(Shellout).to receive(:new).with(%(docker run --cap-add=NET_ADMIN --shm-size 2g --rm -v "$(pwd):/sitespeed.io" sitespeedio/sitespeed.io:16.8.1 -b chrome -n 4 -c cable --cookie perf_bar_enabled=false --cpu --outputFolder #{report_file_path} --multi --spa support/measure_scripts/repo_browser.js)).and_return(shellout_docker_run_double)

          shellout_open_double = double('Shellout', run: true, success?: true)
          expect(Shellout).to receive(:new).with("open ./#{report_file_path}/index.html").and_return(shellout_open_double)

          subject.run(workflows)
        end
      end
    end
  end
end
