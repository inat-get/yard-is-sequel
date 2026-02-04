# frozen_string_literal: true

require_relative "yard-is-sequel/info"

module IS::YARD::Sequel
  def self.init
    # Регистрируем теги
    register_tags
  end

  def self.register_tags
    YARD::Tags::Library.define_tag "Sequel Model", :sequel_model
    YARD::Tags::Library.define_tag "Sequel Association", :sequel_association
    YARD::Tags::Library.define_tag "Sequel Association Setter", :sequel_association_setter
  end
end

require_relative "yard-is-sequel/associations"
require_relative "yard-is-sequel/models"

# Регистрируем обработчики в пространстве имен :sequel
YARD::Handlers::Processor.register_handler_namespace(:sequel, IS::YARD::Sequel)

# Регистрируем конкретные обработчики
# YARD::Handlers::Processor.register_handler_for_namespace(
#   :sequel,
#   IS::YARD::Sequel::AssociationsHandler
# )
# YARD::Handlers::Processor.register_handler_for_namespace(
#   :sequel,
#   IS::YARD::Sequel::ModelHandler
# )

# Инициализируем плагин
IS::YARD::Sequel.init

# YARD::Handlers::Processor.register_handler_namespace :sequel, IS::YARD::Sequel
# YARD::Handlers::Processor.register_handler_for_namespace :sequel, IS::YARD::Sequel::AssociationsHandler
