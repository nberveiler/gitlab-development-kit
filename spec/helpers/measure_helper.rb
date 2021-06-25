# frozen_string_literal: true

module MeasureHelper
  shared_examples 'it checks if Docker and GDK are running' do |args|
    context "when Docker isn't installed or running " do
      let(:docker_running) { false }

      it 'aborts' do
        expected_error = 'ERROR: Docker is not installed or running!'

        expect { subject.run(args) }.to raise_error(expected_error).and output("#{expected_error}\n").to_stderr
      end
    end

    context "when GDK isn't running or ready" do
      let(:docker_running) { true }

      it 'aborts' do
        stub_gdk_check(is_running: false)

        expected_error = 'ERROR: GDK is not running locally on http://127.0.0.1:3000!'

        expect { subject.run(args) }.to raise_error(expected_error).and output("#{expected_error}\n").to_stderr
      end
    end
  end

  def stub_git_rev_parse(branch_name:)
    shellout_double = instance_double(Shellout, run: branch_name)
    allow(Shellout).to receive(:new).with('git rev-parse --abbrev-ref HEAD', chdir: GDK.config.gitlab.dir).and_return(shellout_double)
  end

  def stub_docker_check(is_running:)
    shellout_double = instance_double(Shellout, run: true, success?: is_running)
    allow(Shellout).to receive(:new).with('docker info').and_return(shellout_double)
  end

  def stub_gdk_check(is_running:)
    http_helper_double = instance_double(GDK::HTTPHelper, up?: is_running)
    allow(GDK::HTTPHelper).to receive(:new).with(GDK.config.__uri).and_return(http_helper_double)
  end
end
