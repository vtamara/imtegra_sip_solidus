require 'sip/application_controller'

class ApplicationController < Sip::ApplicationController
  protect_from_forgery with: :exception

  helper_method :spree_current_user

  def spree_current_user
    current_usuario
  end

  helper_method :spree_login_path
  helper_method :spree_signup_path
  helper_method :spree_logout_path

  def spree_login_path
    login_path
  end

  def spree_signup_path
    signup_path
  end

  def spree_logout_path
    logout_path
  end
end
