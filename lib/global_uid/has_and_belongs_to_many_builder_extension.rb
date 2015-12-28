module GlobalUid
  module HasAndBelongsToManyBuilderExtension
    def through_model
      model = super
      model.disable_global_uid if model.left_reflection.klass.global_uid_disabled
      model
    end
  end
end
