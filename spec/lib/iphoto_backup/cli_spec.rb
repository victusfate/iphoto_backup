require 'spec_helper'

describe IphotoBackup::CLI do
  TMP_OUTPUT_DIRECTORY = 'tmp/backup'
  PROJECT_DIR = File.expand_path(File.join(File.expand_path(__dir__), '../../../'))

  let(:args) { [] }
  let(:options) {
    {
      config: 'tmp/AlbumData.xml',
      output: TMP_OUTPUT_DIRECTORY,
      filter: '.*'
    }
  }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { IphotoBackup::CLI.new(args, options, config) }

  before do
    template = File.read('spec/fixtures/AlbumData.xml.erb')
    erb = ERB.new(template)
    FileUtils.mkdir('tmp') unless File.exists?('tmp')
    File.open('tmp/AlbumData.xml', 'w+') do |f|
      f << erb.result(binding)
    end
  end
  after do
    FileUtils.rm_rf TMP_OUTPUT_DIRECTORY
  end

  describe '#export' do
    before do
      cli.export
    end
    context 'with basic options' do
      it 'creates folder for first event' do
        expect(File.exists?('tmp/backup/Summer Party')).to be_true
      end
      it 'creates folder for second event' do
        expect(File.exists?('tmp/backup/2013-10-10 Fall Supper')).to be_true
      end
      it 'copies images for first event' do
        expect(Dir.glob('tmp/backup/Summer Party/*.jpg').length).to eq 2
      end
      it 'copies images for second event' do
        expect(Dir.glob('tmp/backup/2013-10-10 Fall Supper/*.jpg').length).to eq 2
      end
    end
    context 'when filter only matches first event' do
      let(:options) {
        {
          config: 'tmp/AlbumData.xml',
          output: TMP_OUTPUT_DIRECTORY,
          filter: 'Summer'
        }
      }
      it 'creates folder for first event' do
        expect(File.exists?('tmp/backup/Summer Party')).to be_true
      end
      it 'does not createfolder for second event' do
        expect(File.exists?('tmp/backup/2013-10-10 Fall Supper')).to be_false
      end
    end
    context 'with --include-date-prefix option', focus: true do
      let(:options) {
        {
          config: 'tmp/AlbumData.xml',
          output: TMP_OUTPUT_DIRECTORY,
          filter: '.*',
          :'include-date-prefix' => true
        }
      }
      it 'creates folder for first event and adds date prefix' do
        expect(File.exists?('tmp/backup/2013-10-02 Summer Party')).to be_true
      end
      it 'creates folder for second event and uses existing date prefix' do
        expect(File.exists?('tmp/backup/2013-10-10 Fall Supper')).to be_true
      end
    end
  end
end
