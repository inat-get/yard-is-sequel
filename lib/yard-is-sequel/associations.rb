# frozen_string_literal: true

# require "yard"

require_relative "info"

class IS::YARD::Sequel::AssociationsHandler < YARD::Handlers::Ruby::Base
  handles method_call(:many_to_one)
  handles method_call(:one_to_many)
  handles method_call(:many_to_many)
  namespace_only

  def process
    # Получаем имя ассоциации
    first_param = statement.parameters.first
    assoc_name = first_param.jump(:ident, :string_content).source.to_sym

    # Определяем тип ассоциации
    assoc_type = statement.method_name.source.to_sym

    # Извлекаем опции
    options = extract_options

    # Определяем класс ассоциации
    assoc_class = determine_association_class(assoc_name, options)

    # Определяем возвращаемый тип
    return_type = determine_return_type(assoc_type, assoc_class)

    # Создаем метод в документации
    register_method(assoc_name, assoc_type, return_type, options)

    # Для many_to_one также создаем сеттер
    register_setter(assoc_name, assoc_class, options) if assoc_type == :many_to_one
  end

  private

  def extract_options
    options = {}

    # Ищем хэш опций в параметрах
    statement.parameters.each do |param|
      # Пропускаем, если param false или nil
      next unless param && param.respond_to?(:type)

      if param.type == :hash || param.type == :assoclist || param.type == :list
        process_hash_node(param, options)
      elsif param.type == :bare_assoc_hash
        # Обработка синтаксиса без фигурных скобок: key: value
        process_bare_assoc_hash(param, options)
      end
    end

    options
  end

  def process_hash_node(hash_node, options)
    # В зависимости от типа узла обрабатываем по-разному
    if hash_node.type == :hash
      # Старый формат: {:key => value}
      hash_node.children.each do |child|
        next unless child.respond_to?(:type) && child.type == :assoc

        key_node, value_node = child.children
        process_assoc_pair(key_node, value_node, options) if key_node && value_node
      end
    elsif hash_node.type == :assoclist || hash_node.type == :list
      # Новый формат: key: value (Ruby 1.9+ syntax) или список ассоциаций
      hash_node.children.each do |child|
        if child.respond_to?(:type) && child.type == :assoc && child.children.size >= 2
          process_assoc_pair(child.children[0], child.children[1], options)
        end
      end
    end
  end

  def process_bare_assoc_hash(hash_node, options)
    # Обработка синтаксиса без фигурных скобок: many_to_one :observation, class: :'INatGet::Models::Observation'
    hash_node.children.each do |child|
      if child.respond_to?(:type) && child.type == :assoc && child.children.size >= 2
        key_node, value_node = child.children
        process_assoc_pair(key_node, value_node, options)
      end
    end
  end

  def process_assoc_pair(key_node, value_node, options)
    return unless key_node && value_node

    # Получаем ключ
    key_name = extract_key_name(key_node)
    return unless key_name

    # Парсим значение
    options[key_name] = parse_option_value(value_node)
  end

  def extract_key_name(key_node)
    return unless key_node.respond_to?(:source)

    # Получаем исходный код ключа и преобразуем в символ
    # Убираем возможные кавычки и двоеточия
    key_source = key_node.source

    # Обрабатываем разные форматы:
    # :key -> key
    # "key" -> key
    # key: -> key
    key_source = key_source.to_s
      .gsub(/^:/, "") # Убираем начальное двоеточие
      .gsub(/:$/, "") # Убираем конечное двоеточие
      .gsub(/^["']|["']$/, "") # Убираем кавычки

    key_source.to_sym
  end

  def parse_option_value(value_node)
    return nil unless value_node && value_node.respond_to?(:source)

    # Возвращаем исходный код значения
    source = value_node.source

    # Обрабатываем специальные случаи:
    case value_node.type
    when :symbol_literal, :symbol
      # Убираем начальное двоеточие
      source = source.to_s.sub(/^:/, "")
    when :string_literal
      # Убираем кавычки вокруг строки
      source = source.gsub(/^['"]|['"]$/, "")
    when :dyna_symbol
      # Динамический символ :"something"
      source = source.to_s.sub(/^:/, "").gsub(/^["']|["']$/, "")
    end

    source
  end

  def determine_association_class(assoc_name, options)
    # Порядок приоритета для определения класса:
    # 1. Явная опция :class
    # 2. Опция :class_name
    # 3. Преобразование имени ассоциации (например, :user -> User)
    # 4. По умолчанию - Object

    class_name = options[:class] || options[:class_name]

    if class_name
      # Если class_name задан как символ (:'INatGet::Models::Observation')
      # или как строка, возвращаем его
      # Убираем лишнее из строки
      class_name = class_name.to_s

      # Если это символ с кавычками (например, :'INatGet::Models::Observation')
      # нужно убрать лишние символы
      class_name = class_name.gsub(/^['"]|['"]$/, "")

      return class_name
    end

    # Преобразуем имя ассоциации в имя класса
    # Например: :user_accounts -> UserAccount, :posts -> Post
    class_name = assoc_name.to_s
      .sub(/s$/, "") # Убираем множество чисел
      .split("_")
      .map(&:capitalize)
      .join

    class_name
  end

  def determine_return_type(assoc_type, assoc_class)
    case assoc_type
    when :many_to_one
      # Может возвращать nil, поэтому указываем optional
      "#{assoc_class}, nil"
    when :one_to_many, :many_to_many
      # Возвращает Dataset или Array, в зависимости от использования
      # Sequel::Dataset (с методами) или Array<#{assoc_class}>
      "Sequel::Dataset, Array<#{assoc_class}>"
    end
  end

  def register_method(name, assoc_type, return_type, options)
    method_obj = YARD::CodeObjects::MethodObject.new(
      namespace,
      name,
      :instance
    )

    # Формируем документацию с правильным форматированием YARD
    docstring_parts = []

    # Основное описание
    docstring_parts << "Sequel #{assoc_type} association."

    # Опции (если есть)
    if options.any?
      docstring_parts << ""
      docstring_parts << generate_options_doc(options)
    end

    # Примеры - в правильном формате YARD
    example_content = generate_example(name, assoc_type, options)
    if example_content && !example_content.empty?
      docstring_parts << ""
      docstring_parts << "@example"
      # Добавляем отступ в 2 пробела для каждой строки примера
      example_content.lines.each do |line|
        docstring_parts << "  #{line.chomp}"
      end
    end

    # Возвращаемое значение
    docstring_parts << ""
    docstring_parts << "@return [#{return_type}] #{assoc_type_description(assoc_type)}"

    # Собираем все части
    method_obj.docstring = docstring_parts.join("\n")

    # Добавляем только специальный тег
    method_obj.add_tag(YARD::Tags::Tag.new(:sequel_association, assoc_type.to_s))

    # Регистрируем в YARD
    register(method_obj)

    log.debug "[Sequel Plugin] Added association: #{namespace}##{name} (#{assoc_type})"
  end

  def register_setter(name, assoc_class, options)
    setter_name = "#{name}="

    method_obj = YARD::CodeObjects::MethodObject.new(
      namespace,
      setter_name,
      :instance
    )

    # Правильное форматирование документации для сеттера
    docstring_parts = []
    docstring_parts << "Setter for #{name} association."
    docstring_parts << ""
    docstring_parts << "@param value [#{assoc_class}, nil] The associated object to set"
    docstring_parts << "@return [#{assoc_class}] The set value"

    method_obj.docstring = docstring_parts.join("\n")

    # Устанавливаем параметры метода
    method_obj.parameters = [["value", nil]]

    method_obj.add_tag(YARD::Tags::Tag.new(:sequel_association_setter, ""))

    register(method_obj)
  end

  def generate_options_doc(options)
    return "" if options.empty?

    lines = ["Options:"]
    options.each do |key, value|
      lines << "  :#{key} => #{value.inspect}"
    end
    lines.join("\n")
  end

  def generate_example(name, assoc_type, options)
    class_name = determine_association_class(name, options)

    # Получаем имя модели из namespace
    namespace_name = namespace.name.to_s
    model_name = namespace_name.split("::").last.downcase

    # Форматируем пример
    case assoc_type
    when :many_to_one
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => #{class_name} instance or nil
        #{model_name}.#{name} = #{class_name}.first
      EXAMPLE
    when :one_to_many
      singular_name = name.to_s.chomp("s")
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => Dataset of #{class_name} objects
        #{model_name}.add_#{singular_name}(#{class_name}.new)
      EXAMPLE
    when :many_to_many
      singular_name = name.to_s.chomp("s")
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => Dataset of #{class_name} objects
        #{model_name}.add_#{singular_name}(#{class_name}.first)
        #{model_name}.#{name}_dataset  # Many-to-many through join table
      EXAMPLE
    end
  end

  def assoc_type_description(type)
    case type
    when :many_to_one
      "associated object or nil if not set"
    when :one_to_many
      "dataset or array of associated objects"
    when :many_to_many
      "dataset or array of associated objects through join table"
    end
  end
end
