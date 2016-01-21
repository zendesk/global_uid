module GlobalUid
  module HasAndBelongsToManyBuilderExtension
    def self.included(base)
      base.class_eval do
        alias_method_chain :through_model, :inherit_global_uid_disabled_from_lhs
      end
    end

    def through_model_with_inherit_global_uid_disabled_from_lhs
      model = through_model_without_inherit_global_uid_disabled_from_lhs
      model.disable_global_uid if model.left_reflection.klass.global_uid_disabled
      model
    end
  end
end
