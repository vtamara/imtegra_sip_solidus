source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.2'

gem 'bcrypt'

gem 'bootsnap', '>= 1.4.4', require: false

gem 'cancancan'

gem 'cocoon', git: 'https://github.com/vtamara/cocoon.git',
  branch: 'new_id_with_ajax'

gem 'coffee-rails'

gem 'devise'

gem 'devise-i18n'

gem 'dotenv-rails'

gem 'jbuilder', '~> 2.7'

gem 'kaminari'

gem 'kt-paperclip'

gem 'libxml-ruby'

gem 'nokogiri'

gem 'odf-report'

gem 'pg', '~> 1.1'

# Use Puma as the app server
gem 'puma', '~> 5.0'

gem 'rack'

gem 'rails', '~> 6.1.4', '>= 6.1.4.1'

gem 'rails-i18n'

gem 'redcarpet'

gem 'rubyzip', '>= 2.0'

gem 'rspreadsheet'

gem 'sassc-rails'

gem "solidus", "~> 3.1.0"

gem 'simple_form'

gem 'turbolinks', '~> 5'

gem 'twitter_cldr'

gem 'webpacker', '6.0.0.rc.1'

#gem 'will_paginate'


#####
# Motores que se sobrecargan vistas (deben ponerse en orden de apilamiento 
# lógico y no alfabetico como las gemas anteriores) 

gem 'sip', # Motor generico
  git: 'https://github.com/pasosdeJesus/sip.git', branch: :sinwillpaginate
  #path: '../sip'

gem 'mr519_gen', # Motor de gestion de formularios y encuestas
  git: 'https://github.com/pasosdeJesus/mr519_gen.git', branch: :main
  #path: '../mr519_gen'

gem 'heb412_gen',  # Motor de nube y llenado de plantillas
  git: 'https://github.com/pasosdeJesus/heb412_gen.git', branch: :main
  #path: '../heb412_gen'

gem 'sivel2_gen', # Motor para manejo de casos
  git: 'https://github.com/pasosdeJesus/sivel2_gen.git', branch: :main
  #path: '../sivel2_gen'



group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  #gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]

  gem 'code-scanning-rubocop'

  gem 'colorize'
end

group :development do
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
end

group :test do
  gem 'minitest' 

  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 3.26'

  gem 'selenium-webdriver'

  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
end


gem 'solidus_paypal_commerce_platform'
