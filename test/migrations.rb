class CreateWithNoParams < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids
  end
end

class CreateWithExplicitUidTrue < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids, :use_global_uid => true do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids, :use_global_uid => true
  end
end

class CreateWithNamedID < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids, :id => 'hello' do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids
  end
end

class CreateWithoutGlobalUIDs < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :without_global_uids, :use_global_uid => false do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :without_global_uids, :use_global_uid => false
  end
end
