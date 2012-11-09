module ObjectMomma
  ACTUALIZE_STRATEGIES = [:create, :find, :find_or_create]

  class Child
    attr_accessor :child_id
    attr_reader :actualize_strategy, :builder
    alias_method :to_s, :child_id

    def initialize(object_type, hash, actualize_strategy)
      unless ACTUALIZE_STRATEGIES.include?(actualize_strategy)
        raise ArgumentError, "Invalid actualize strategy "\
          "`#{actualize_strategy}'; valid values are "\
          "#{ACTUALIZE_STRATEGIES.map(&:to_s).join(', ')}"
      end

      @actualize_strategy = actualize_strategy
      @builder            = ObjectMomma.builder_for(object_type).new(self)

      builder.build_child_from_hash(hash) do |sibling_object_type, sibling_id|
        self.class.new(sibling_object_type, sibling_id, @actualize_strategy)
      end
    end

    def child_object
      @child_object ||= actualize_child_object
    end

    class << self
      alias_method :original_new, :new

      def new(object_type, string_or_hash, *args)
        if string_or_hash.is_a?(String)
          hash = Builder.string_to_hash(object_type, string_or_hash)
        elsif string_or_hash.is_a?(Hash)
          hash = string_or_hash
        else
          raise ArgumentError, "Must instantiate a Child with a String or a "\
            "Hash, not a #{string_or_hash.class.name}"
        end

        original_new(object_type, hash, *args)
      end
    end

  private

    def actualize_child_object
      object = builder.first_or_initialize

      if object.respond_to?(:first_or_initialize)
        object = object.first_or_initialize
      end

      if builder.is_persisted?(object)
        if actualize_strategy == :create
          raise ObjectMomma::ObjectExists, "Child `#{child_id}' created by "\
            "`#{builder.class.name}' exists already"
        end
      else
        if actualize_strategy == :find
          raise ObjectMomma::ObjectNotFound, "Child `#{child_id}' created by "\
            "`#{builder.class.name}' does not yet exist"
        end
        builder.build!(object)

        unless builder.is_persisted?(object)
          raise ObjectMomma::NotPersisted, "Child `#{child_id}' was created "\
            "by `#{builder.class.name}' but wasn't persisted"
        end
      end

      if builder.respond_to?(:decorate!)
        builder.decorate!(object)
      end

      object
    end
  end
end
