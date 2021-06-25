# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Command::Trust do
  it 'warns with a deprecation message' do
    stub_no_color_env('true')

    expect { subject.run }.to output("'gdk trust' is deprecated and no longer required.\n").to_stdout
  end
end
