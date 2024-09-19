require 'open-uri'

# ONE_URI provides compatibility interface for OpenURI module by
# using legacy Kernel.open or URI.open calls based on available version
module ONE_URI

    def self.open(*args)
        URI.open(*args)
    rescue NoMethodError
        Kernel.open(*args)
    end

end
