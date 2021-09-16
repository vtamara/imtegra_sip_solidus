class AddSpreeFieldsToCustomUserTable < ActiveRecord::Migration[4.2]
  def up
    add_column "usuario", :spree_api_key, :string, :limit => 48
    add_column "usuario", :ship_address_id, :integer
    add_column "usuario", :bill_address_id, :integer
  end
end
