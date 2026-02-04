# frozen_string_literal: true

require 'yard'

require_relative 'info'

class IS::YARD::Sequel::ModelHandler < YARD::Handlers::Ruby::ClassHandler
  handles :class

  def process
    # Проверяем, наследуется ли класс от Sequel::Model
    return unless sequel_model?

    # Добавляем тег к классу, что это Sequel модель
    namespace.add_tag(YARD::Tags::Tag.new(:sequel_model, ""))

    log.debug "[Sequel Plugin] Detected Sequel model: #{namespace}"
  end

  private

  def sequel_model?
    # Проверяем наследование от Sequel::Model
    superclass = statement.inheritance_superclass
    return false unless superclass

    # Разбираем возможные варианты:
    # class User < Sequel::Model
    # class User < Sequel::Model(:users)
    # class User < Sequel::Model(DB[:users])

    superclass_source = superclass.source

    # Проверяем разные варианты
    superclass_source =~ /Sequel::Model/ ||
      (superclass.type == :call && superclass.namespace.source == "Sequel::Model")
  end

end
