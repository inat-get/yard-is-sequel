# frozen_string_literal: true

# require "yard"

require_relative "info"

class IS::YARD::Sequel::ModelHandler < YARD::Handlers::Ruby::ClassHandler
  handles :class

  def process
    # Проверяем, наследуется ли класс от Sequel::Model
    return unless sequel_model?

    # Добавляем тег к классу, что это Sequel модель
    # Используем пустое значение для тега
    namespace.add_tag(YARD::Tags::Tag.new(:sequel_model, ""))

    log.debug "[Sequel Plugin] Detected Sequel model: #{namespace}"
  end

  private

  def sequel_model?
    # Проверяем наличие суперкласса
    superclass = statement.superclass
    return false unless superclass

    # Получаем исходный код суперкласса как строку
    superclass_source = superclass.source

    # Проверяем разные варианты записи Sequel::Model:
    # 1. class User < Sequel::Model
    # 2. class User < Sequel::Model(:users)
    # 3. class User < Sequel::Model(DB[:users])

    # Простая проверка по подстроке
    superclass_source =~ /Sequel::Model/
  end

end
