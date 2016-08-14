class Cms::Helper

  # returns cms snippet/page full object or json-parsed content if specified, caching results
  # @param [String] type 'snippet'/'page'
  # @param [String] id identifier (snippet) / slug (page)
  # @param [String] format json: json-parsed content field, nil: {whole model}
  # @return [Object]
  def get_content(type, id, format = nil)
    raise ArgumentError, "type '#{type}' is not supported, can be either: page, snippet" unless %w(page snippet).include?(type)

    Rails.cache.fetch("cms_content_helper_#{type}_#{id}#{format ? "_#{format}" : ''}", expires_in: 1.hour) do
      site_id = Rails.env.production? ? Cms::Site.find_by_identifier('worthy').id : 1
      site = Cms::Site.find(site_id)
      ## NOTE! there's nothing enforcing uniq slugs/ident in cms, we might pull wrong page with dup slugs/ident
      case type
        when 'page'
          page = site.pages.published.where(slug: id)
        when 'snippet'
          page = site.snippets.where(identifier: id)
        else
          return
      end

      # is slug/ident uniq? (we do not want to return random content)
      raise StandardError, "requested id '#{id}' is not uniq, not sure what to return.." if page.size > 1

      # content not found
      if page.size == 0
        Rails.logger.error "content not found for requested id '#{id}'.."
        return nil
      end

      format == 'json' ? JSON.parse(page.first.content) : page.first
    end

  rescue => e
    Rails.logger.error "CMS Error message: #{e.message}"
    Rails.logger.error 'Note: remember to clear cache after you have made changes to cms..'
    raise e
  end
end