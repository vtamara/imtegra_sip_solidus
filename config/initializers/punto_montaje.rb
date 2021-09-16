Sivel2Explora::Application.config.relative_url_root = ENV.fetch(
  'RUTA_RELATIVA', '/sivel2exp')
Sivel2Explora::Application.config.assets.prefix = ENV.fetch(
  'RUTA_RELATIVA', '/sivel2exp') == '/' ? 
 '/assets' : (ENV.fetch('RUTA_RELATIVA', '/sivel2exp') + '/assets')
