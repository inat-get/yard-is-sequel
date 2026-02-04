# frozen_string_literal: true

require 'sequel'

class IS::YARD::Sequel::FieldsHandler < YARD::Handlers::Ruby::Base

  handles method_call(:set_dataset)
  handles method_call(:dataset=)

  def process
    table_name = statement.parameters.first.jump(:symbol, :string).source.delete(':"\'')
    database = self.class.database
    return unless database
    table_schema = database.schema(table_name)
    return unless table_schema

    table_schema.each do |column_name, info|
      type = [ map_type(info[:db_type]) ]
      type << 'nil' unless info[:allow_null] == false

      object = YARD::CodeObjects::MethodObject.new(namespace, column_name) do |o|
        o.source = statement.source
        o.parameters = []
        o.docstring = 'Sequel data field'
        o.docstring.add_tag YARD::Tags::Tag::new(:return, '', type)
        o.docstring.add_tag YARD::Tags::Tag::new(:sequel_field, '')
        o.is_attribute = true
        o.group = 'Sequel Fields'
      end
      register object
      namespace.attributes[:instance][column_name] = {
        read: object,
        write: object
      }
    end
  end

  private

  def map_type source
    case source.to_s.downcase
    when 'integer'
      'Integer'
    when 'float', 'double precision'
      'Float'
    when /^char/, /^varchar/, 'text'
      'String'
    when 'timestamp', 'datetime', 'time'
      'Time'
    when 'boolean'
      'Boolean'
    else
      source
    end
  end

  class << self

    def database
      @database ||= setup_database
    end

    private

    def setup_database
      # return unless defined?($SEQUEL_MIGRATIONS_DIR) && $SEQUEL_MIGRATIONS_DIR
      begin
        Sequel.extension :migration
        db = Sequel.sqlite
        Sequel::Migrator::run db, ENV['SEQUEL_MIGRATIONS_DIR']
        db
      rescue
        nil
      end
    end

  end

end
