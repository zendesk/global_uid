# frozen_string_literal: true
MigrationClass = if ActiveRecord::Migration.respond_to?(:[])
  current_version = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}".to_f
  ActiveRecord::Migration[current_version]
else
  ActiveRecord::Migration
end

class CreateWithNoParams < MigrationClass
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

class CreateWithExplicitUidTrue < MigrationClass
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

class CreateWithoutGlobalUIDs < MigrationClass
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

class CreateWithGlobalUIDAndCustomStart < MigrationClass
  group :change if self.respond_to?(:group)

  def self.up
    create_table(:with_global_uid_and_custom_start, start_id: 10_000) { }
  end

  def self.down
    drop_table :with_global_uid_and_custom_start
  end
end
