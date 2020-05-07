# frozen_string_literal: true
class WithGlobalUID < ActiveRecord::Base
end

class WithoutGlobalUID < ActiveRecord::Base
  disable_global_uid
end

class WithGlobalUIDAndCustomStart < ActiveRecord::Base
  self.table_name = 'with_global_uid_and_custom_start'
end

class Parent < ActiveRecord::Base
  def self.reset
    @global_uid_disabled = nil
  end
end

class ParentSubclass < Parent
end

class ParentSubclassSubclass < ParentSubclass
end

class Account < ActiveRecord::Base
  disable_global_uid
  has_and_belongs_to_many :people
end

class Person < ActiveRecord::Base
  has_and_belongs_to_many :account
end
