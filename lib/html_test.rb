%w(validator assertions url_selector url_checker link_validator validate_filter).each do |file|
  require File.join(File.dirname(__FILE__), file)
end

class Test::Unit::TestCase
  include Html::Test::Assertions

  def self.skip_html_validation=( value )
    setup ->{ @_skip_html_validation = value }
  end
end

module ActionController
  module Integration #:nodoc:
    class Session
      include Html::Test::Assertions
    end
  end
end

ActionController::Base
class ActionController::Base
  @@validate_all = false
  cattr_accessor :validate_all

  @@validators = [:tidy]
  cattr_accessor :validators

  @@check_urls = false
  cattr_accessor :check_urls

  @@check_redirects = false
  cattr_accessor :check_redirects

  after_filter :validate_page
  after_filter :check_urls_resolve
  after_filter :check_redirects_resolve

  private
  def validate_page
    return if !validate_all
    Html::Test::ValidateFilter.new(self).validate_page
  end

  def check_urls_resolve
    return if !check_urls
    Html::Test::UrlChecker.new(self).check_urls_resolve
  end

  def check_redirects_resolve
    return if !check_redirects
    Html::Test::UrlChecker.new(self).check_redirects_resolve
  end
end

module Html::Test::AutoValidate
  def self.included(base)
    base.class_eval do
      define_method :validate_page do
        url = @request.fullpath
        if ( !@_skip_html_validation &&
             !Html::Test::ValidateFilter.already_validated?(url) &&
             @response.success? &&
             @response.content_type.to_s =~ %r{\b text/html \b}xi )
          assert_validates( ApplicationController.validators, @response.body.strip, @request.fullpath )
          Html::Test::ValidateFilter.mark_url_validated( url )
        end
      end

      define_method :process_with_validation do |*args|
        ret = process_without_validation( *args )
        validate_page
        return ret
      end

      alias_method_chain :process, :validation
    end
  end
end
