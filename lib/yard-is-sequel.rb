# frozen_string_literal: true

require_relative 'yard-is-sequel/info'

module IS::YARD::Sequel

  def self.init
    # Регистрируем теги
    register_tags
  end

  def self.register_tags
    YARD::Tags::Library.define_tag 'Sequel Model', :sequel_model
    YARD::Tags::Library.define_tag 'Sequel Association', :sequel_association
    YARD::Tags::Library.define_tag 'Sequel Association Setter', :sequel_association_setter
  end

end

require_relative 'yard-is-sequel/associations'
require_relative 'yard-is-sequel/models'

YARD::Handlers::Processor.register_handler_namespace(:sequel, IS::YARD::Sequel)
