class ActionView::TestCase::TestController
  def default_url_options(_options = {})
    { locale: I18n.default_locale, host: "test.host" }
  end
end

class ActionDispatch::Routing::RouteSet
  def default_url_options(_options = {})
    { locale: I18n.default_locale, host: "test.host" }
  end
end
