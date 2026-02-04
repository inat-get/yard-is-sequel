# frozen_string_literal: true

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

    # Создаем атрибут в документации
    register_attribute(assoc_name, assoc_type, assoc_class)
  end

  private

  def extract_options
    options = {}

    # Ищем хэш опций в параметрах
    statement.parameters.each do |param|
      next unless param && param.respond_to?(:type)

      if param.type == :hash || param.type == :assoclist || param.type == :list
        process_hash_node(param, options)
      elsif param.type == :bare_assoc_hash
        process_bare_assoc_hash(param, options)
      end
    end

    options
  end

  def process_hash_node(hash_node, options)
    if hash_node.type == :hash
      hash_node.children.each do |child|
        next unless child.respond_to?(:type) && child.type == :assoc

        key_node, value_node = child.children
        process_assoc_pair(key_node, value_node, options) if key_node && value_node
      end
    elsif hash_node.type == :assoclist || hash_node.type == :list
      hash_node.children.each do |child|
        if child.respond_to?(:type) && child.type == :assoc && child.children.size >= 2
          process_assoc_pair(child.children[0], child.children[1], options)
        end
      end
    end
  end

  def process_bare_assoc_hash(hash_node, options)
    hash_node.children.each do |child|
      if child.respond_to?(:type) && child.type == :assoc && child.children.size >= 2
        key_node, value_node = child.children
        process_assoc_pair(key_node, value_node, options)
      end
    end
  end

  def process_assoc_pair(key_node, value_node, options)
    return unless key_node && value_node

    key_name = extract_key_name(key_node)
    return unless key_name

    options[key_name] = parse_option_value(value_node)
  end

  def extract_key_name(key_node)
    return unless key_node.respond_to?(:source)

    key_source = key_node.source
    key_source = key_source.to_s
      .gsub(/^:/, "")
      .gsub(/:$/, "")
      .gsub(/^["']|["']$/, "")

    key_source.to_sym
  end

  def parse_option_value(value_node)
    return nil unless value_node && value_node.respond_to?(:source)

    source = value_node.source

    case value_node.type
    when :symbol_literal, :symbol
      source = source.to_s.sub(/^:/, "")
    when :string_literal
      source = source.gsub(/^['"]|['"]$/, "")
    when :dyna_symbol
      source = source.to_s.sub(/^:/, "").gsub(/^["']|["']$/, "")
    end

    source
  end

  def determine_association_class(assoc_name, options)
    class_name = options[:class] || options[:class_name]

    if class_name
      class_name = class_name.to_s
      class_name = class_name.gsub(/^['"]|['"]$/, "")
      return class_name
    end

    class_name = assoc_name.to_s
      .sub(/s$/, "")
      .split("_")
      .map(&:capitalize)
      .join

    class_name
  end

  def register_attribute(name, assoc_type, assoc_class)
    # Определяем тип атрибута: rw для many_to_one (read/write), r для остальных (read only)
    # attr_type = (assoc_type == :many_to_one) ? "rw" : "r"

    # Определяем возвращаемый тип
    return_type = case assoc_type
      when :many_to_one
        "#{assoc_class}, nil"
      when :one_to_many, :many_to_many
        "Sequel::Dataset, Array<#{assoc_class}>"
      end

    # Создаем объект метода с директивой @!attribute
    method_obj = YARD::CodeObjects::MethodObject.new(
      namespace,
      name,
      :instance
    )
    method_obj.is_attribute = true
    method_obj.group = 'Sequel Associations'
    namespace.attributes[:instance][name] = {
      read: method_obj,
      write: method_obj
    }

    # Формируем документацию с директивой @!attribute
    docstring_parts = []

    # Директива @!attribute должна быть первой
    # docstring_parts << "@!attribute [#{attr_type}]"
    docstring_parts << "@return [#{return_type}]"

    # Описание
    docstring_parts << "Sequel #{assoc_type.to_s.gsub('_', '-')} association."

    # Примеры
    # example_content = generate_example(name, assoc_type, assoc_class)
    # if example_content && !example_content.empty?
    #   docstring_parts << ""
    #   docstring_parts << "@example"
    #   example_content.lines.each do |line|
    #     docstring_parts << "  #{line.chomp}"
    #   end
    # end

    method_obj.docstring = docstring_parts.join("\n")

    # Добавляем тег для фильтрации
    method_obj.add_tag(YARD::Tags::Tag.new(:sequel_association, assoc_type.to_s))

    # Регистрируем в YARD
    register(method_obj)

    log.debug "[Sequel Plugin] Added association attribute: #{namespace}##{name} (#{assoc_type})"
  end

  def generate_example(name, assoc_type, assoc_class)
    namespace_name = namespace.name.to_s
    model_name = namespace_name.split("::").last.downcase

    case assoc_type
    when :many_to_one
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => #{assoc_class} instance or nil
        #{model_name}.#{name} = #{assoc_class}.first
      EXAMPLE
    when :one_to_many
      singular_name = name.to_s.chomp("s")
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => Dataset of #{assoc_class} objects
        #{model_name}.add_#{singular_name}(#{assoc_class}.new)
      EXAMPLE
    when :many_to_many
      singular_name = name.to_s.chomp("s")
      <<~EXAMPLE.chomp
        #{model_name}.#{name}          # => Dataset of #{assoc_class} objects
        #{model_name}.add_#{singular_name}(#{assoc_class}.first)
        #{model_name}.#{name}_dataset  # Many-to-many through join table
      EXAMPLE
    end
  end
end
