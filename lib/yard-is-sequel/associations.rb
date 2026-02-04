# frozen_string_literal: true

require 'yard'

require_relative 'info'

class IS::YARD::Sequel::AssociationsHandler < YARD::Handlers::Ruby::Base
  handles method_call(:many_to_one)
  handles method_call(:one_to_many)
  handles method_call(:many_to_many)
  namespace_only

  def process
    # Получаем имя ассоциации
    assoc_name = statement.parameters.first.jump(:ident, :string_content).source.to_sym

    # Определяем тип ассоциации
    assoc_type = statement.method_name(true)

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
      if param.type == :hash
        param.children.each_slice(2) do |key, value|
          key_name = key.jump(:ident, :symbol).source.to_sym
          options[key_name] = parse_option_value(value)
        end
      end
    end

    options
  end

  def parse_option_value(value_node)
    case value_node.type
    when :symbol, :string_literal
      value_node.jump(:ident, :string_content).source
    when :const, :const_path_ref
      # Для констант вроде User или Models::User
      value_node.source
    when :array
      value_node.children.map { |v| parse_option_value(v) }
    else
      value_node.source
    end
  end

  def determine_association_class(assoc_name, options)
    # Порядок приоритета для определения класса:
    # 1. Явная опция :class
    # 2. Опция :class_name
    # 3. Преобразование имени ассоциации (например, :user -> User)
    # 4. По умолчанию - Object

    return options[:class] if options[:class]
    return options[:class_name] if options[:class_name]

    # Преобразуем имя ассоциации в имя класса
    # Например: :user_accounts -> UserAccount, :posts -> Post
    class_name = assoc_name.to_s
      .sub(/s$/, "") # Убираем множественное число
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

    # Формируем документацию
    docstring = <<~DOC
      Sequel #{assoc_type} association.
      
      #{generate_options_doc(options)}
      
      @example
        #{generate_example(name, assoc_type, options)}
      
      @return [#{return_type}] #{assoc_type_description(assoc_type)}
    DOC

    method_obj.docstring = docstring

    # Добавляем теги для фильтрации
    method_obj.add_tag(YARD::Tags::Tag.new(:sequel_association, assoc_type.to_s))
    method_obj.add_tag(YARD::Tags::Tag.new(:return, "", return_type))

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

    docstring = <<~DOC
      Setter for #{name} association.
      
      @param value [#{assoc_class}, nil] The associated object to set
      @return [#{assoc_class}] The set value
    DOC

    method_obj.docstring = docstring
    method_obj.add_tag(YARD::Tags::Tag.new(:sequel_association_setter, ""))
    method_obj.parameters = [["value", nil]]

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

    case assoc_type
    when :many_to_one
      <<~EXAMPLE
        # Getting the associated object
        #{namespace.name.split("::").last.downcase}.#{name}
        # => #{class_name} instance or nil
        
        # Setting the association
        #{namespace.name.split("::").last.downcase}.#{name} = #{class_name}.first
      EXAMPLE
    when :one_to_many
      <<~EXAMPLE
        # Getting the collection
        #{namespace.name.split("::").last.downcase}.#{name}
        # => Dataset of #{class_name} objects
        
        # Adding to the collection
        #{namespace.name.split("::").last.downcase}.add_#{name.to_s.singularize}(#{class_name}.new)
      EXAMPLE
    when :many_to_many
      <<~EXAMPLE
        # Getting the collection
        #{namespace.name.split("::").last.downcase}.#{name}
        # => Dataset of #{class_name} objects
        
        # Adding to the collection
        #{namespace.name.split("::").last.downcase}.add_#{name.to_s.singularize}(#{class_name}.first)
        
        # Many-to-many through join table
        #{namespace.name.split("::").last.downcase}.#{name}_dataset
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
