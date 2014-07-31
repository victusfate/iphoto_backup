require 'thor'
require 'nokogiri'
require 'fileutils'

module IphotoBackup
  class CLI < Thor
    IPHOTO_ALBUM_PATH = "~/Pictures/iPhoto Library/AlbumData.xml"
    DEFAULT_OUTPUT_DIRECTORY = "~/Desktop/GoogleDrive/pics"
    IPHOTO_EPOCH = Time.new(2001, 1, 1)

    desc "export [OPTIONS]", "exports iPhoto albums into target directory"
    option :filter, desc: 'filter to only include albums that match the given regex', aliases: '-e', default: '.*'
    option :output, desc: 'directory to export albums to', aliases: '-o', default: DEFAULT_OUTPUT_DIRECTORY
    option :config, desc: 'iPhoto AlbumData.xml file to process', aliases: '-c', default: IPHOTO_ALBUM_PATH
    option :'include-date-prefix', desc: 'automatically include ISO8601 date prefix to exported events', aliases: '-d', default: true, type: :boolean
    def export
      each_album do |folder_name, album_info|
        say "\n\nProcessing Roll: #{folder_name}..."

        each_image(album_info) do |image_info|
          source_path = value_for_dictionary_key('ImagePath', image_info).content

          target_path = File.join(File.expand_path(options[:output]), folder_name, File.basename(source_path))
          target_dir = File.dirname target_path
          FileUtils.mkdir_p(target_dir) unless Dir.exists?(target_dir)

          if FileUtils.uptodate?(source_path, [ target_path ])
            say "  copying #{source_path} to #{target_path}"
            FileUtils.copy source_path, target_path, preserve: true
          else
            print '.'
          end
        end
      end
    end
    default_command :export

    private

    def each_album(&block)
      albums = value_for_dictionary_key("List of Rolls").children.select {|n| n.name == 'dict' }
      albums.each do |album_info|
        folder_name = album_name album_info

        if folder_name.match(album_filter)
          yield folder_name, album_info
        else
          say "\n\n#{folder_name} does not match the filter: #{album_filter.inspect}"
        end
      end
    end

    def album_name(album_info)
      folder_name = value_for_dictionary_key('RollName', album_info).content;
      #  + value_for_dictionary_key('RollDateAsTimerInterval', album_info).content

      if options[:'include-date-prefix'] && folder_name !~ /^\d{4}-\d{2}-\d{2} /
        album_date = nil
        each_image album_info do |image_info|
          next if album_date
          photo_interval = value_for_dictionary_key('DateAsTimerInterval', image_info).content.to_i
          album_date = (IPHOTO_EPOCH + photo_interval).strftime('%Y-%m-%d')
        end
        say "Automatically adding #{album_date} prefix to folder: #{folder_name}"
        folder_name = "#{album_date} #{folder_name}"
      end
      folder_name
    end

    def each_image(album_info, &block)
      album_images = value_for_dictionary_key('KeyList', album_info).css('string').map(&:content)
      album_images.each do |image_id|
        image_info = info_for_image image_id
        yield image_info
      end
    end

    def info_for_image(image_id)
      value_for_dictionary_key image_id, master_images
    end

    def value_for_dictionary_key(key, dictionary = root_dictionary)
      key_node = dictionary.children.find {|n| n.name == 'key' && n.content == key }
      next_element key_node
    end

    # find next available sibling element
    def next_element(node)
      element_node = node
      while element_node != nil  do
        element_node = element_node.next_sibling
        break if element_node.element?
      end
      element_node
    end

    def album_filter
      @album_filter ||= Regexp.new(options[:filter])
    end

    def master_images
      @master_images ||= value_for_dictionary_key "Master Image List"
    end

    def root_dictionary
      @root_dictionary ||= begin
        file = File.expand_path options[:config]
        say "Loading AlbumData: #{file}"
        doc = Nokogiri.XML(File.read(file))
        doc.child.children.find {|n| n.name == 'dict' }
      end
    end
  end
end
