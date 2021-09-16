conexion = ActiveRecord::Base.connection();

#Sip::carga_semillas_sql(conexion, 'sip', :datos)
#conexion.execute(
#  "INSERT INTO public.usuario
#     (nusuario, email, encrypted_password, password,
#      fechacreacion, created_at, updated_at, rol)
#   VALUES ('sip', 'sip@localhost',
#     '$2a$10$YQY.luWpKWwNWIlfAQ.dhupblCP23raR35oIfeX1Cnm9mCYzmQvqm',
#      '', '2014-08-14', '2014-08-14', '2014-08-14', 1);")
#
Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)


