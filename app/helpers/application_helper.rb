module ApplicationHelper
  # SECURITY: Safely renders a website URL as a link
  # Only creates clickable links for http/https URLs
  # Prevents XSS from javascript: or data: URLs
  # @param url [String] The website URL to render
  # @param css_class [String] CSS class for the link
  # @return [String] Safe HTML for the website link or plain text
  def safe_website_link(url, css_class: "text-blue-600 hover:text-blue-900")
    return "-" if url.blank?

    # Validate URL format and scheme
    uri = URI.parse(url)
    if %w[http https].include?(uri.scheme)
      link_to url, url, target: "_blank", rel: "noopener noreferrer", class: css_class
    else
      # Invalid scheme - render as plain text (not clickable)
      content_tag(:span, url, class: "text-gray-600")
    end
  rescue URI::InvalidURIError
    # Invalid URL format - render as plain text
    content_tag(:span, url, class: "text-gray-600")
  end
end
