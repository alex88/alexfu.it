module TemplateHelper
  def thumbnail_tag image, size, options = {}
    content = link_to options.fetch(:link_to, "/images/#{image}"), rel: 'lightbox' do
      thumbnail image, size, class: 'img-responsive'
    end
    "<p class='text-center'>#{content}</p>"
  end
end