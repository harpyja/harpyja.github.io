module Jekyll
  class FolderPage < Page
    def initialize(site, base, slug, dir)
      @site = site
      @base = base
      @dir  = slug
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'folder.html')
      self.data['dir'] = dir
      self.data['dir_slug'] = slug
      self.data['title'] = dir.capitalize
    end
  end

  class FolderGenerator < Generator
    safe true
    priority :low

    def generate(site)
      # collect folder names from posts path (first directory under _posts)
      folders = {}
      site.posts.docs.each do |post|
        segments = post.path.split('/')
        if segments.size > 2
          dir = segments[1]
          slug = Utils.slugify(dir)
          folders[slug] = dir
        end
      end

      folders.each do |slug, dir|
        site.pages << FolderPage.new(site, site.source, slug, dir)
      end
    end
  end
end
