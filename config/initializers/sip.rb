#require 'sivel2_gen/version'

Sip.setup do |config|
  config.ruta_anexos = ENV.fetch('SIP_RUTA_ANEXOS', 
                                 "#{Rails.root}/archivos/anexos/")
  config.ruta_volcados = ENV.fetch('SIP_RUTA_VOLCADOS',
                                   "#{Rails.root}/archivos/bd/")
  config.titulo = "SIVeL Explora 0.1".force_encoding('utf-8')

  config.paginador = :kamari
end
