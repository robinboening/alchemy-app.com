class ApplicationController < ActionController::Base
  
  include FastGettext::Translation
  include Alchemy
  include Userstamp
  
  protect_from_forgery
  filter_parameter_logging :login, :password, :password_confirmation
  
  before_filter :set_gettext_locale
  
  helper_method :get_server, :configuration, :multi_language?, :current_user
  helper :errors, :layout
  
  def render_errors_or_redirect object, redicrect_url, flash_notice
    if object.errors.empty?
      flash[:notice] = _(flash_notice)
      render :update do |page| page.redirect_to redicrect_url end
    else
      render :update do |page|
        page.replace_html 'errors', "<ul>" + object.errors.sum{|a, b| "<li>" + _(b) + "</li>"} + "</ul>"
        page.show "errors"
        page << "alchemy_window.updateHeight()"
      end
    end
  end
  
  # returns the request.env[HTTP_HOST] for local or for live webservers. important for mod_rewrite proxy based webs
  def get_server
    # for local servers
    if request.env["HTTP_X_FORWARDED_HOST"].nil?
      adress = request.env["HTTP_HOST"]
    #for remote servers
    else
      adress = request.env["HTTP_X_FORWARDED_HOST"]
    end
    "http://#{adress}"
  end
  
  def configuration(name)
    return Alchemy::Configuration.parameter(name)
  end
  
  def set_language(lang = nil)
    session[:language] = detect_language_in_config(params[:lang] || lang)
    Alchemy::Controller.current_language = session[:language]
  end
  
  def multi_language?
    configuration(:languages).size > 1
  end
  
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end
  
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end
  
  def logged_in?
    !current_user.blank?
  end
  
private
  
  def last_request_update_allowed?
    true #action_name =! "update_session_time_left"
  end
  
  def detect_language_in_config(lang)
    detected_lang = configuration(:languages).detect{ |language|
      language[:language_code] == lang
    }
    if detected_lang.blank?
      return configuration(:default_language)
    else
      return detected_lang[:language_code]
    end
  end
  
  def exception_handler(e)
    logger.error %(
      +++++++++ #{e} +++++++++++++
      object: #{e.record.class}, id: #{e.record.id}, name: #{e.record.name}
      #{e.record.errors.full_messages}
    )
  end
  
  def set_language_from_client
    unless logged_in?
      if params[:lang].blank?
        unless request.env['HTTP_ACCEPT_LANGUAGE'].blank?
          lang = request.env['HTTP_ACCEPT_LANGUAGE'][0..1]
        end
        language = detect_language_in_config(lang)
      else
        language = detect_language_in_config(params[:lang])
      end
      session[:language] = language
      Alchemy::Controller.current_language = session[:language]
      I18n.locale = session[:language]
    end
  end
  
  def set_translation
    FastGettext.locale = current_user.language unless current_user == :false || current_user.blank?
  end
  
  def store_location
    session[:redirect_url] = request.url
  end
  
  def set_stamper
    FastGettext.text_domain = 'alchemy'
    User.stamper = self.current_user
  end
  
  def reset_stamper
    User.reset_stamper
  end
  
protected
  
  def set_gettext_locale
    FastGettext.text_domain = 'alchemy'
    FastGettext.available_locales = ['de','en'] #all you want to allow
    super
    session[:language] ||= configuration(:default_language)
    Alchemy::Controller.current_language = session[:language]
  end
  
  def permission_denied
    if current_user
      flash[:error] = _('You are not authorized')
      if current_user.role == 'registered'
        redirect_to root_path
      else
        redirect_to admin_path
      end
    else
      flash[:info] = _('Please log in')
      if request.xhr?
        render :update do |page|
          page.redirect_to login_path
        end
      else
        store_location
        redirect_to login_path
      end
    end
  end
  
  def redirect_back_or_to_default(default_path = admin_path)
    if request.env["HTTP_REFERER"].blank?
      redirect_to default_path
    else
      redirect_to :back
    end
  end
  
end
