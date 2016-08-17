require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

class SQLObject

  def self.columns
    return @columns if @columns
    results = DBConnection.execute2(<<-SQL)
      SELECT * FROM #{self.table_name};
    SQL

    # execute2 provides the column list array as the first element
    # of the return array.
    @columns = results.first.map(&:to_sym)
  end

  # create getter and setter methods for columns in the model
  def self.finalize!
    columns.each do |col|
      define_method(col.to_s + '=') do |val|
        attributes[col] = val
      end

      define_method(col) do
        attributes[col]
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    if @table_name.nil?
      class_name = self.to_s
      class_name_arr = class_name.split(/(?<=[a-z])(?=[A-Z])/).map(&:downcase)
      class_name_arr[-1] = class_name_arr[-1]+'s'
      table_name=(class_name_arr.join('_'))
    else
      @table_name
    end
  end

  def self.all
    return @all if @all
    query = DBConnection.execute(<<-SQL)
      SELECT * FROM #{self.table_name}
    SQL
    parse_all(query)
  end

  # converts the query into an array
  def self.parse_all(results)
    arr = []
    results.each do |hash|
      arr << self.new(hash)
    end
    arr
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        (#{self.table_name})
      WHERE
        id = ?
    SQL

    ans = parse_all(results)
    ans.empty? ? nil : ans.first
  end


  # Sets params to each of the model's attributes and raises error if
  # not attribute is found
  def initialize(params = {})
    params.each do |k,v|
      k = k.to_sym
      if self.class.columns.include?(k)
        self.send(k.to_s+'=', v)
      else
        raise "unknown attribute '#{k}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end

  def insert
    col_names = self.class.columns.drop(1)
    col_names_s = col_names.join(", ")
    question_marks = ["?"] * (col_names.length)
    question_marks_s = question_marks.join(', ')
    results = DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
        #{self.class.table_name} (#{col_names_s})
      VALUES
        (#{question_marks_s})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.drop(1).map{ |col| "#{col} = ?"}
    attr_vals = attribute_values
    id = attr_vals.shift
    attr_vals << id
    results = DBConnection.execute(<<-SQL, *attr_vals)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_names.join(', ')}
      WHERE
        id = ?
    SQL


  end

  def save
    id.nil? ? insert : update
  end
end
