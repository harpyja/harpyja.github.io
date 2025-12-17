module Jekyll
  class TagPage < Page
    def initialize(site, base, dir, tag)
      @site = site
      @base = base
      # use slugified tag as directory name
      slug = Utils.slugify(tag)
      @dir  = File.join(dir, slug)
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'tag.html')
      self.data['tag'] = tag
      self.data['title'] = "Tag: #{tag}"
    end
  end

  class TagGenerator < Generator
    safe true
    priority :low

    def generate(site)
      return unless site.layouts.key? 'tag'

      dir = 'tag'
      site.tags.keys.each do |tag|
        site.pages << TagPage.new(site, site.source, dir, tag)
      end
    end
  end
end
