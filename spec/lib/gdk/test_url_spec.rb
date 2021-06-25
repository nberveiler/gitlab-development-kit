# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::TestURL do
  let(:default_url) { 'http://127.0.0.1:3000/users/sign_in' }
  let(:quiet) { nil }

  before do
    stub_const('GDK::TestURL::MAX_ATTEMPTS', 2)
  end

  subject { described_class.new(default_url, quiet: quiet) }

  describe '.default_url' do
    it 'returns http://127.0.0.1:3000/users/sign_in' do
      expect(described_class.default_url).to eq(default_url)
    end
  end

  describe 'initialize' do
    it 'raises UrlAppearsInvalid exception if URL invalid' do
      expect { described_class.new('invalid-url') }.to raise_error(GDK::TestURL::UrlAppearsInvalid)
    end

    it "doesn't raise UrlAppearsInvalid exception when URL is valid" do
      expect(described_class.new(default_url)).to be_instance_of(described_class)
    end
  end

  describe '#wait' do
    shared_examples "a URL that's down" do
      it 'checks if the URL is up but returns false' do
        allow(http_helper_double).to receive(:up?).and_return(false)

        freeze_time do
          result = nil

          expected_message = Regexp.escape("#{default_url} does not appear to be up. Waited 0.0 second(s).")
          expect { result = subject.wait }.to output(/#{expected_message}/).to_stdout
          expect(result).to be(false)
        end
      end
    end

    shared_examples "a URL that's up" do
      it 'checks if the URL is up but returns true' do
        allow(http_helper_double).to receive(:up?).and_return(true)

        freeze_time do
          result = nil

          expected_message = Regexp.escape("#{default_url} is up (#{last_response_reason}). Took 0.0 second(s).")
          expect { result = subject.wait }.to output(/#{expected_message}/).to_stdout
          expect(result).to be(true)
        end
      end
    end

    context 'quiet is enabled' do
      let(:quiet) { true }

      context 'when URL is down' do
        it_behaves_like "a URL that's down" do
          let(:http_helper_double) { stub_quiet_test_url_http_helper(success: false) }
        end
      end

      context 'when URL is up' do
        it_behaves_like "a URL that's up" do
          let(:last_response_reason) { '200 OK' }
          let(:http_helper_double) { stub_quiet_test_url_http_helper(last_response_reason, success: true) }
        end
      end
    end

    context 'quiet is disabled' do
      let(:quiet) { false }

      context 'when URL is down' do
        it_behaves_like "a URL that's down" do
          let(:http_helper_double) { stub_noisy_test_url_http_helper(success: false) }
        end
      end

      context 'when URL is up' do
        it_behaves_like "a URL that's up" do
          let(:last_response_reason) { '302 OK' }
          let(:http_helper_double) { stub_noisy_test_url_http_helper(last_response_reason, success: true) }
        end
      end
    end
  end

  def stub_noisy_test_url_http_helper(last_response_reason = '', success: true)
    http_helper_double = stub_test_url_http_helper(last_response_reason)

    expect(subject).to receive(:sleep).with(1).twice unless success

    http_helper_double
  end

  def stub_quiet_test_url_http_helper(last_response_reason = '', success: true)
    http_helper_double = stub_test_url_http_helper(last_response_reason)

    expect(subject).to receive(:sleep).with(5).twice unless success

    http_helper_double
  end

  def stub_test_url_http_helper(last_response_reason = '')
    expect(GDK::Output).to receive(:print).with("=> Waiting until #{default_url} is ready..")
    allow(GDK::Output).to receive(:print).and_call_original

    uri = URI.parse(default_url)
    http_helper_double = instance_double(GDK::HTTPHelper, last_response_reason: last_response_reason)
    allow(GDK::HTTPHelper).to receive(:new).with(uri, cache_response: false).and_return(http_helper_double)

    allow(URI).to receive(:parse).with(default_url).and_return(uri)

    http_helper_double
  end
end
