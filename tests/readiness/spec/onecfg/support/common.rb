def one_file_fixture(name, component = 'onescape')
    "#{RSPEC_ROOT}/fixtures/files/#{component}/#{name}"
end

def one_file_fixtures(dir_name, min_size = 3)
    base = one_file_fixture(dir_name)

    unless File.directory?(base)
        raise Exception, "Not a directory #{base}"
    end

    # list only files in the directory
    files = Dir.glob("#{base}/*").sort.select { |f| File.file?(f) }

    if files.size < min_size
        raise Exception, "Not enough files in fixtures #{base}"
    end

    files
end

def sort_non_strict!(data)
    if data.is_a? Array
        #TODO: we can have nested structures!
        data.sort_by { |i| i.to_s }
    elsif data.is_a? Hash
        data.each do |k, v|
            if v.is_a?(Array) || v.is_a?(Hash)
                data[k] = sort_non_strict!(v)
            end
        end
    else
        data
    end
end

def match_onecfg_status(text, one_version, cfg_version)
    expect(text).to match(/OpenNebula:\s*#{one_version ? one_version : 'unknown'}/i)
    expect(text).to match(/Config:\s*#{cfg_version ? cfg_version : 'unknown'}/i)
end
