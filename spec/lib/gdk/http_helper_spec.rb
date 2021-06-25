# frozen_string_literal: true

require 'rack'
require 'spec_helper'

RSpec.describe GDK::HTTPHelper do
  let(:uri) { GDK.config.__uri }
  let(:path) { uri.path.empty? ? '/' : uri.path }

  describe '.new' do
    context 'when provided URI is not an instance of URI class' do
      it 'raises error' do
        expect { described_class.new('http://localhost:3000') }.to raise_error(/uri needs to be an instance of URI/)
      end
    end
  end

  subject { described_class.new(uri) }

  describe '#up?' do
    context 'when URI is down because its not running' do
      it 'returns false' do
        http_client_double = stub_http_get
        allow(http_client_double).to receive(:get).with(path).and_raise(Errno::ECONNREFUSED)

        expect(subject.up?).to be(false)
        expect(subject.last_response_reason).to eq('Connection refused')
      end
    end

    context 'when URI is times out' do
      it 'returns false' do
        http_client_double = stub_http_get
        allow(http_client_double).to receive(:get).with(path).and_raise(Net::ReadTimeout)

        expect(subject.up?).to be(false)
        expect(subject.last_response_reason).to eq('Request timed out')
      end
    end

    context 'when URI is down because it returns a non successful HTTP code' do
      it 'returns false' do
        stub_http_get_with_code(502)

        expect(subject.up?).to be(false)
        expect(subject.last_response_reason).to eq('502 Bad Gateway')
      end
    end

    context 'when URI is down initially, but then comes up' do
      subject(:helper) { described_class.new(uri, cache_response: false) }

      it 'returns true' do
        stub_http_get_with_code(502)
        expect(helper.up?).to be(false)
        expect(helper.last_response_reason).to eq('502 Bad Gateway')

        stub_http_get_with_code(200)
        expect(helper.up?).to be(true)
        expect(helper.last_response_reason).to eq('200 OK')
      end
    end

    context 'when URI is up' do
      it 'returns true' do
        stub_http_get_with_code(200)

        expect(subject.up?).to be(true)
        expect(subject.last_response_reason).to eq('200 OK')
      end
    end
  end

  def stub_http_get
    http_client_double = Net::HTTP.new(uri.host, uri.port)
    allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http_client_double)
    allow(http_client_double).to receive(:start).and_yield(http_client_double)

    http_client_double
  end

  def stub_http_get_with_code(http_code)
    http_client_double = stub_http_get

    http_response_double = double('Net::HTTPResponse', code: http_code.to_s, message: Rack::Utils::HTTP_STATUS_CODES[http_code])
    allow(http_client_double).to receive(:get).with(path).and_return(http_response_double)
  end
end
