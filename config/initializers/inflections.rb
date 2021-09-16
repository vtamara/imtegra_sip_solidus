# Podria forzarse orden con:

#['sip', 'mr519_gen', 'heb412_gen', 'cor1440_gen', 'sal7711_gen', 'sal7711_web',
# 'sivel2_gen', 'sivel2_sjr'].each do |s| 
#  byebug
#  require_dependency File.join(Gem::Specification.find_by_name(s).gem_dir,
#                             '/config/initializers/inflections.rb')
#end

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular 'action', 'actions'
  inflect.irregular 'authorization', 'authorizations'
  inflect.irregular 'carton', 'cartons'
  inflect.irregular 'card', 'cards'
  inflect.irregular 'location', 'locations'
  inflect.irregular 'method', 'methods'
  inflect.irregular 'promotion', 'promotions'
  inflect.irregular 'reason', 'reasons'
  inflect.irregular 'refund', 'refunds'
  inflect.irregular 'return', 'returns'
  inflect.irregular 'rule', 'rules'
  inflect.irregular 'taxon', 'taxons'
  inflect.irregular 'zone', 'zones'
end
