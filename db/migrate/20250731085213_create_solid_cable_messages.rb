class CreateSolidCableMessages < ActiveRecord::Migration[7.1]
  def up
    ActiveRecord::Base.establish_connection(:cable)
    create_table :solid_cable_messages, force: :cascade do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false
      t.index [ :channel ], name: "index_solid_cable_messages_on_channel"
      t.index [ :channel_hash ], name: "index_solid_cable_messages_on_channel_hash"
      t.index [ :created_at ], name: "index_solid_cable_messages_on_created_at"
    end
    ActiveRecord::Base.establish_connection(:primary)
  end

  def down
    ActiveRecord::Base.establish_connection(:cable)
    drop_table :solid_cable_messages
    ActiveRecord::Base.establish_connection(:primary)
  end
end
