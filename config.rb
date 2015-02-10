require 'lib/blog_categories'
require 'lib/uuid'
###
# Blog settings
###

Time.zone = 'UTC'

set :url, 'http://alexfu.it'
set :title, 'Alexfu'
set :author, 'Alessandro Tagliapietra'
set :email, 'tagliapietra.alessandro@gmail.com'
set :subtitle, ''
set :description, 'I\'m a developer and IT tech guy blogging about random things'
set :uuid, UUID.create_sha1(self.url, UUID::NameSpace_URL)

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'
set :helpers_dir, 'lib'
set :markdown_engine, :kramdown
set :markdown, fenced_code_blocks: true, smartypants: true, tables: true, autolink: true, disable_indented_code_blocks: true, input: 'GFM'
# Workaround for code blocks and haml layouts
set :haml, { ugly: true }

activate :syntax
activate :thumbnailer,
    dimensions: {
      small: '200x',
      medium: '400x',
      post: '800x',
      big: '1024x'
    }
activate :blog do |blog|
  blog.sources = 'posts/{year}-{month}-{day}-{title}.html'
  blog.layout = 'blog_post'
end
activate :directory_indexes
activate :asset_hash
# Fix for woff2 files, will be fixed in middleman 4
extensions.find{ |e| e[0] == :asset_hash }[1].options.setting(:exts).value.push '.woff2'
activate :gzip
activate :s3_sync do |s3|
  s3.bucket                     = ENV['S3_BUCKET']
  s3.region                     = ENV['S3_BUCKET_REGION']
  s3.aws_access_key_id          = ENV['AWS_ACCESS_KEY_ID']
  s3.aws_secret_access_key      = ENV['AWS_SECRET_ACCESS_KEY']
  s3.reduced_redundancy_storage = true
end
default_caching_policy max_age: 600

configure :development do
  activate :livereload
  set :debug_assets, true
end

# Build-specific configuration
configure :build do
  activate :minify_css
  activate :minify_javascript
end

ready do
  blog.articles.each do |a|
    proxy "#{a.url}atom.xml", "/atom.xml", :layout => false, :locals => { :articles => [a] }
    proxy "#{a.url}atom.json", "/atom.json", :layout => false, :locals => { :articles => [a] }
  end

  page "/atom.xml", :layout => false do
    @articles = blog.articles
  end

  page "/atom.json", :layout => false do
    @articles = blog.articles
  end

  page "/feed.rss", :layout => false

  page "/google*.html", :directory_index => false
  page "/pinterest*.html", :directory_index => false
  page "/404.html", :directory_index => false
  page '/feed.xml', layout: false
  page "sitemap.xml", layout: false
end