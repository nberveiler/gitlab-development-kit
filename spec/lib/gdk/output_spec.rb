# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GDK::Output do
  describe '.print' do
    context 'by default' do
      it 'prints to stdout' do
        expect { described_class.print('test') }.to output('test').to_stdout
      end
    end

    context 'with stderr: true' do
      it 'prints to stderr' do
        expect { described_class.print('test', stderr: true) }.to output('test').to_stderr
      end
    end
  end

  describe '.puts' do
    context 'by default' do
      it 'puts to stdout' do
        expect { described_class.puts('test') }.to output("test\n").to_stdout
      end
    end

    context 'with stderr: true' do
      it 'puts to stdout' do
        expect { described_class.puts('test', stderr: true) }.to output("test\n").to_stderr
      end
    end
  end

  describe '.notice' do
    it 'puts formatted message to stdout' do
      stub_no_color_env('')

      expect { described_class.notice('test') }.to output("=> test\n").to_stdout
    end
  end

  describe '.notice_format' do
    it 'returns formatted message' do
      expect(described_class.notice_format('test')).to eq('=> test')
    end
  end

  describe '.info' do
    it 'puts to stdout' do
      stub_no_color_env('')

      expect { described_class.info('test') }.to output("\u2139\ufe0f  test\n").to_stdout
    end
  end

  describe '.success' do
    context "when we're not a tty" do
      it 'puts to stdout' do
        stub_tty(false)

        expect { described_class.success('test') }.to output("test\n").to_stdout
      end
    end

    context 'when we are a tty' do
      context 'when NO_COLOR=true is not defined' do
        it 'puts to stdout' do
          stub_tty(true)
          stub_no_color_env('')

          expect { described_class.success('test') }.to output("\u2705\ufe0f test\n").to_stdout
        end
      end

      context 'when NO_COLOR=true is defined' do
        it 'puts to stdout minus icon and colorization' do
          stub_no_color_env('true')

          expect { described_class.success('test') }.to output("test\n").to_stdout
        end
      end
    end
  end

  describe '.warn' do
    context "when we're not a tty" do
      it 'puts to stderr minus icon and colorization' do
        stub_tty(false)

        expect { described_class.warn('test') }.to output("WARNING: test\n").to_stderr
      end
    end

    context 'when we are a tty' do
      context 'when NO_COLOR=true is not defined' do
        it 'puts to stderr' do
          stub_no_color_env('')

          expect { described_class.warn('test') }.to output("\u26a0\ufe0f  \e[33mWARNING\e[0m: test\n").to_stderr
        end
      end

      context 'when NO_COLOR=true is defined' do
        it 'puts to stderr minus icon and colorization' do
          stub_no_color_env('true')

          expect { described_class.warn('test') }.to output("WARNING: test\n").to_stderr
        end
      end
    end
  end

  describe '.format_error' do
    context "when we're not a tty" do
      it 'puts to stderr minus icon and colorization' do
        stub_tty(false)

        expect(described_class.format_error('test')).to eq("ERROR: test")
      end
    end

    context 'when we are a tty' do
      context 'when NO_COLOR=true is not defined' do
        it 'puts to stderr' do
          stub_no_color_env('')

          expect(described_class.format_error('test')).to eq("\u274C\ufe0f \e[31mERROR\e[0m: test")
        end
      end

      context 'when NO_COLOR=true is defined' do
        it 'puts to stderr minus icon and colorization' do
          stub_no_color_env('true')

          expect(described_class.format_error('test')).to eq("ERROR: test")
        end
      end
    end
  end

  describe '.error' do
    context "when we're not a tty" do
      it 'puts to stderr minus icon and colorization' do
        stub_tty(false)

        expect { described_class.error('test') }.to output("ERROR: test\n").to_stderr
      end
    end

    context 'when we are a tty' do
      context 'when NO_COLOR=true is not defined' do
        it 'puts to stderr' do
          stub_no_color_env('')

          expect { described_class.error('test') }.to output("\u274C\ufe0f \e[31mERROR\e[0m: test\n").to_stderr
        end
      end

      context 'when NO_COLOR=true is defined' do
        it 'puts to stderr minus icon and colorization' do
          stub_no_color_env('true')

          expect { described_class.error('test') }.to output("ERROR: test\n").to_stderr
        end
      end
    end
  end

  describe '.abort' do
    context "when we're not a tty" do
      it 'puts to stderr minus icon and colorization' do
        stub_tty(false)

        expect { described_class.abort('test') }.to raise_error(/test/).and output("ERROR: test\n").to_stderr
      end
    end

    context 'when we are a tty' do
      context 'when NO_COLOR=true is not defined' do
        it 'puts to stderr' do
          stub_no_color_env('')

          expect { described_class.abort('test') }.to raise_error(/test/).and output("\u274C\ufe0f \e[31mERROR\e[0m: test\n").to_stderr
        end
      end

      context 'when NO_COLOR=true is defined' do
        it 'puts to stderr minus icon and colorization' do
          stub_no_color_env('true')

          expect { described_class.abort('test') }.to raise_error(/test/).and output("ERROR: test\n").to_stderr
        end
      end
    end
  end

  describe '.color' do
    it 'returns a color for index' do
      expect(described_class.color(0)).to eq("31")
    end
  end

  describe '.ansi' do
    it 'returns the ansi color code string' do
      expect(described_class.ansi('31')).to eq("\e[31m")
    end
  end

  describe '.reset_color' do
    it 'returns the ansi reset code string' do
      expect(described_class.reset_color).to eq("\e[0m")
    end
  end

  describe '.wrap_in_color' do
    it 'returns a message that is colorized' do
      stub_tty(true)

      msg = 'An error occurred'

      expect(described_class.wrap_in_color(msg, described_class::COLOR_CODE_RED)).to eq("\e[31m#{msg}\e[0m")
    end
  end

  describe '.icon' do
    context 'when NO_COLOR=true is not defined' do
      it 'returns the icon code with trailing space' do
        icon = described_class::ICONS[:success]

        stub_no_color_env('')

        expect(described_class.icon(:success)).to eq("#{icon} ")
      end
    end

    context 'when NO_COLOR=true is defined' do
      it 'returns an empty string' do
        stub_no_color_env('true')

        expect(described_class.icon('doesntmatter')).to be_empty
      end
    end
  end

  describe '.colorize?' do
    context 'when NO_COLOR=true is not defined' do
      it 'returns true' do
        stub_no_color_env('')

        expect(described_class.colorize?).to be(true)
      end
    end

    context 'when NO_COLOR=true is defined' do
      it 'returns false' do
        stub_no_color_env('true')

        expect(described_class.colorize?).to be(false)
      end
    end
  end

  describe '.prompt' do
    it 'returns user input' do
      response = 'n'
      message = 'Are you sure? [y/N]'

      expect(Kernel).to receive(:print).with("#{message}: ")
      expect(ARGF).to receive_message_chain(:gets, :chomp).and_return(response)

      expect(described_class.prompt(message)).to eq(response)
    end
  end
end
