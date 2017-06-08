class Comfy::Cms::ContentController < Comfy::Cms::BaseController

  # Authentication module must have `authenticate` method
  include ComfortableMexicanSofa.config.public_auth.to_s.constantize

  # Authorization module must have `authorize` method
  include ComfortableMexicanSofa.config.public_authorization.to_s.constantize

  before_action :load_fixtures
  before_action :load_cms_page,
                :authenticate,
                :authorize,
                :only => :show

  rescue_from ActiveRecord::RecordNotFound, :with => :page_not_found

  def show
    @cms_page = @cms_site.pages.published.find_by_full_path!("/#{params[:cms_path]}")

    if @cms_page and @cms_page.layout and @cms_page.layout.identifier == 'redirect-layout' # custom redirect
      custom_redirect_code = @cms_page.blocks.find_by_identifier('custom_redirect_code').content.to_i
      if @cms_page.target_page.present?
        redirect_url = @cms_page.target_page.url
      else
        redirect_url = @cms_page.blocks.find_by_identifier('custom_redirect_url').content
      end
      if custom_redirect_code > 0
        redirect_to redirect_url, status: custom_redirect_code
      else
        redirect_to redirect_url
      end
    else
      if @cms_page.target_page.present?
        redirect_to @cms_page.target_page.url(:relative)
      else
        respond_to do |format|
          format.html { render_page }
          format.json { render :json => @cms_page }
        end
      end
    end
  end

  def render_sitemap
    render
  end

protected

  def render_page(status = 200)
    if @cms_layout = @cms_page.layout
      app_layout = (@cms_layout.app_layout.blank? || request.xhr?) ? false : @cms_layout.app_layout
      render  :inline       => @cms_page.content_cache,
              :layout       => app_layout,
              :status       => status,
              :content_type => mime_type
    else
      render :plain => I18n.t('comfy.cms.content.layout_not_found'), :status => 404
    end
  end

  # it's possible to control mimetype of a page by creating a `mime_type` field
  def mime_type
    mime_block = @cms_page.blocks.find_by_identifier(:mime_type)
    mime_block && mime_block.content || 'text/html'
  end

  def load_fixtures
    return unless ComfortableMexicanSofa.config.enable_fixtures
    ComfortableMexicanSofa::Fixture::Importer.new(@cms_site.identifier).import!
  end

  def load_cms_page
    @cms_page = @cms_site.pages.published.find_by_full_path!("/#{params[:cms_path]}")
  end

  def page_not_found
    full_path = request.fullpath.split('?')[0]
    block = Comfy::Cms::Block.joins(:page => [:site]).where('cms_sites.id = ?', @cms_site.id).where(identifier: 'alternate_urls').where('cms_blocks.content LIKE (?)', "%#{full_path}%").first
    if block.present?
      @cms_page = block.page
      respond_with @cms_page do |format|
        format.html { render_html(200) }
      end
    else
      @cms_page = @cms_site.pages.published.find_by_full_path!('/404')
      respond_with @cms_page do |format|
        format.html { render_html(404) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Page Not Found at: \"#{params[:cms_path]}\"")
  end
end
