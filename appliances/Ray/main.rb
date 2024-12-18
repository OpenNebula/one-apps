module Service
  module Ray
    extend self

    DEPENDS_ON = %w[]

    def install
       msg :info, 'Ray::install'
       msg :info, 'Installation completed successfully'
    end

    def configure
         msg :info, 'Ray::configure'
         msg :info, 'Configuration completed successfully'
    end

    def bootstrap
      msg :info, 'Ray::bootstrap'
    end
  end
end