#!/usr/bin/ruby

require 'fileutils'

# Log writer to save test results to a log file
class LogFile

    # Renames logs if existing in order to avoid data loss
    def initialize(file)
        @file = file
        FileUtils.mv(@file, "#{@file}.#{File.mtime(@file).to_i}") if File.exist?(@file)
        FileUtils.mkdir_p(File.dirname(@file))
    end

    def write(info)
        File.open(@file, 'a') {|f| f.write("#{info}\n") }
    end

    # Standard log file name for the ruby script
    def self.name
        File.basename($PROGRAM_NAME).chomp('.rb') + '.log'
    end

end