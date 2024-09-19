class TempTemplate
    attr_accessor :f, :body

    def initialize(body)
        @f = Tempfile.new('temptemplate')
        @f.write(body)
        @f.close
        @body = body
    end

    def path
        @f.path
    end

    def unlink
        @f.unlink
    end
end
