Rails.application.routes.draw do
  # This line mounts Solidus's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the :at option to something different.
  #
  # We ask that you don't use the :as option here, as Solidus relies on it being the default of "spree"
  mount Spree::Core::Engine, at: '/'

mount SolidusPaypalCommercePlatform::Engine, at: '/solidus_paypal_commerce_platform'

  rutarel = ENV.fetch('RUTA_RELATIVA', 'sivel2_explora/')
  scope rutarel do 

    devise_scope :usuario do
      get 'sign_out' => 'devise/sessions#destroy'

      # El siguiente para superar mala generación del action en el formulario
      # cuando se monta en sitio diferente a / y se autentica mal (genera 
      # /puntomontaje/puntomontaje/usuarios/sign_in )
      if (Rails.configuration.relative_url_root != '/') 
        ruta = File.join(Rails.configuration.relative_url_root, 
                         'usuarios/sign_in')
        post ruta, to: 'devise/sessions#create'
        get  ruta, to: 'devise/sessions#new'
      end
    end

    devise_for :usuarios, :skip => [:registrations], module: :devise
    as :usuario do
      get 'usuarios/edit' => 'devise/registrations#edit', 
        :as => 'editar_registro_usuario'    
      put 'usuarios/:id' => 'devise/registrations#update', 
        :as => 'registro_usuario'            
    end
    resources :usuarios, path_names: { new: 'nuevo', edit: 'edita' } 

    #get '/casos/mapaosm' => 'sivel2_gen/casos#mapaosm'

    root 'sip/hogar#index'
  end # scope

  mount Sip::Engine, at: rutarel, as: 'sip'

end
