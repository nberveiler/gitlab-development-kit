# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Help do
  let(:gdk_root) { Pathname.new('/home/git/gdk') }
  let(:args) { [] }

  before do
    allow(GDK).to receive(:root).and_return(gdk_root)
  end

  describe '#run' do
    it 'displays help and returns true' do
      help_file = gdk_root.join('HELP')
      help_file_contents = 'help contents'

      allow(GDK::Logo).to receive(:print)
      allow(File).to receive(:read).with(help_file).and_return(help_file_contents)

      expect(GDK::Output).to receive(:puts).with(help_file_contents)
      expect(subject.run(args)).to be(true)
    end
  end
end
