require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sivel2Explora
  class Application < Rails::Application
    # Load application's model / class decorators
    initializer 'spree.decorators' do |app|
      config.to_prepare do
        Dir.glob(Rails.root.join('app/**/*_decorator*.rb')) do |path|
          require_dependency(path)
        end
      end
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    config.time_zone = 'America/Bogota'
    
    config.i18n.default_locale = :es

    config.active_record.schema_format = :sql

    config.x.formato_fecha = ENV.fetch('SIP_FORMATO_FECHA', 'dd/M/yyyy')

    config.hosts.concat(
      ENV.fetch('CONFIG_HOSTS', 'cifrasdelconflicto.org').downcase.split(',')
    )
  end
end
