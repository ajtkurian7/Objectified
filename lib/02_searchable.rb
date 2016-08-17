require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = []
    params.each do |k,v|
      where_line << "#{k} = ?"
    end

    results = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        (#{table_name})
      WHERE
        (#{where_line.join(" AND ")})
    SQL

    parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
