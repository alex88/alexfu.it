module Middleman::Cli
  class BuildAction < ::Thor::Actions::EmptyDirectory
    protected

    # Actually build the app
    # @return [void]
    def execute!
      # Sort order, images, fonts, js/css and finally everything else.
      sort_order = %w(.png .jpeg .jpg .gif .bmp .svg .svgz .ico .webp .woff .woff2 .otf .ttf .eot .js .css)

      # Pre-request CSS to give Compass a chance to build sprites
      logger.debug '== Prerendering CSS'

      @app.sitemap.resources.select do |resource|
        resource.ext == '.css'
      end.each(&method(:build_resource))

      logger.debug '== Checking for Compass sprites'

      # Double-check for compass sprites
      @app.files.find_new_files((@source_dir + @app.images_dir).relative_path_from(@app.root_path))
      @app.sitemap.ensure_resource_list_updated!

      # Sort paths to be built by the above order. This is primarily so Compass can
      # find files in the build folder when it needs to generate sprites for the
      # css files

      logger.debug '== Building files'

      resources = @app.sitemap.resources.sort_by do |r|
        sort_order.index(r.ext) || 100
      end

      if @build_dir.expand_path.relative_path_from(@source_dir).to_s =~ /\A[.\/]+\Z/
        raise ":build_dir (#{@build_dir}) cannot be a parent of :source_dir (#{@source_dir})"
      end

      # Loop over all the paths and build them.
      resources.reject do |resource|
        resource.ext == '.css'
      end.each(&method(:build_resource))

      ::Middleman::Profiling.report('build')
    end
  end
end