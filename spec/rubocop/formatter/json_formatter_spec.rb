# encoding: utf-8

require 'spec_helper'
require 'stringio'

module Rubocop
  describe Formatter::JSONFormatter do
    subject(:formatter) { described_class.new(output) }
    let(:output) { StringIO.new }
    let(:files) { %w(/path/to/file1 /path/to/file2) }
    let(:location) do
      source_buffer = Parser::Source::Buffer.new('test', 1)
      source_buffer.source = %w(a b cdefghi).join("\n")
      Parser::Source::Range.new(source_buffer, 9, 10)
    end
    let(:offence) do
      Cop::Offence.new(:convention, location,
                       'This is message', 'CopName', true)
    end

    describe '#started' do
      let(:summary) { formatter.output_hash[:summary] }

      it 'sets target file count in summary' do
        expect(summary[:target_file_count]).to be_nil
        formatter.started(%w(/path/to/file1 /path/to/file2))
        expect(summary[:target_file_count]).to eq(2)
      end
    end

    describe '#file_finished' do
      before do
        count = 0
        formatter.stub(:hash_for_file) do
          count += 1
        end
      end

      let(:summary) { formatter.output_hash[:summary] }

      it 'adds detected offence count in summary' do
        expect(summary[:offence_count]).to eq(0)

        formatter.file_started(files[0], {})
        expect(summary[:offence_count]).to eq(0)
        formatter.file_finished(files[0], [
          double('offence1'), double('offence2')
        ])
        expect(summary[:offence_count]).to eq(2)
      end

      it 'adds value of #hash_for_file to #output_hash[:files]' do
        expect(formatter.output_hash[:files]).to be_empty

        formatter.file_started(files[0], {})
        expect(formatter.output_hash[:files]).to be_empty
        formatter.file_finished(files[0], [])
        expect(formatter.output_hash[:files]).to eq([1])

        formatter.file_started(files[1], {})
        expect(formatter.output_hash[:files]).to eq([1])
        formatter.file_finished(files[1], [])
        expect(formatter.output_hash[:files]).to eq([1, 2])
      end
    end

    describe '#finished' do
      let(:summary) { formatter.output_hash[:summary] }

      it 'sets inspected file count in summary' do
        expect(summary[:inspected_file_count]).to be_nil
        formatter.finished(%w(/path/to/file1 /path/to/file2))
        expect(summary[:inspected_file_count]).to eq(2)
      end

      it 'outputs #output_hash as JSON' do
        formatter.finished(files)
        json = output.string
        restored_hash = JSON.parse(json, symbolize_names: true)
        expect(restored_hash).to eq(formatter.output_hash)
      end
    end

    describe '#hash_for_file' do
      subject(:hash) { formatter.hash_for_file(file, offences) }
      let(:file) { File.expand_path('spec/spec_helper.rb') }
      let(:offences) { [double('offence1'), double('offence2')] }

      it 'sets relative file path for :path key' do
        expect(hash[:path]).to eq('spec/spec_helper.rb')
      end

      before do
        count = 0
        formatter.stub(:hash_for_offence) do
          count += 1
        end
      end

      it 'sets an array of #hash_for_offence values for :offences key' do
        expect(hash[:offences]).to eq([1, 2])
      end
    end

    describe '#hash_for_offence' do
      subject(:hash) { formatter.hash_for_offence(offence) }

      it 'sets Offence#severity value for :severity key' do
        expect(hash[:severity]).to eq(:convention)
      end

      it 'sets Offence#message value for :message key' do
        expect(hash[:message]).to eq('This is message')
      end

      it 'sets Offence#cop_name value for :cop_name key' do
        expect(hash[:cop_name]).to eq('CopName')
      end

      it 'sets Offence#corrected? value for :corrected key' do
        expect(hash[:corrected]).to be_true
      end

      before do
        formatter.stub(:hash_for_location).and_return(location_hash)
      end

      let(:location_hash) { { line: 1, column: 2 } }

      it 'sets value of #hash_for_location for :location key' do
        expect(hash[:location]).to eq(location_hash)
      end
    end

    describe '#hash_for_location' do
      subject(:hash) { formatter.hash_for_location(offence) }

      it 'sets line value for :line key' do
        expect(hash[:line]).to eq(3)
      end

      it 'sets column value for :column key' do
        expect(hash[:column]).to eq(6)
      end
    end
  end
end
