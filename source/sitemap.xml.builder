xml.instruct!
xml.urlset 'xmlns' => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  sitemap.resources.select { |page| page.path =~ /\.html$/ }.each do |page|
    if page.path == 'index.html'
      path = ''
  else
    path = page.url
    end
    xml.url do
      xml.loc "#{settings.url}#{path}"
      xml.lastmod Date.today.to_time.iso8601
      xml.changefreq page.data.changefreq || "daily"
      xml.priority page.data.priority || "0.5"
    end
  end
end