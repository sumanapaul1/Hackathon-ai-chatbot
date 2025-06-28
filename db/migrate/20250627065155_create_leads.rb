class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.jsonb :payload
      t.string :email

      t.timestamps
    end
  end
end
