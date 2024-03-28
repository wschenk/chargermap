require 'active_support/all'
require 'sqlite3'
require_relative './job.rb'

class Loader
  def initialize
    @dir = ENV['DB_DIR'].blank? ? "." : ENV['DB_DIR']
  end

  def needs_reset
    j = Job.new

    if !j.is_active?
      if !data_valid?
        system( "ruby loader.rb&" )
      end
    end

    j.reset_check
  end

  def file; "#{@dir}/db"; end
  def working_db; "#{@dir}/working_db"; end
  def source_file; "#{@dir}/csv"; end

  def data_valid?
    valid? && source_valid?
  end
    
  def valid?
    return false unless File.exists?( file )

    return check_table
  end

  def check_table
    sql = SQLite3::Database.open( file )
    begin
      sql.execute( "select count(*) from stations;" );
    rescue
      return false
    ensure
      sql.close
    end
    
    return true
  end

  def source_valid?
    return false unless File.exists?( source_file )

    File.mtime( source_file ) > 12.hours.ago
  end

  def load_database
    j = Job.new
    j.start

    if !source_valid?
      download_sourcefile
    end

    if File.exists? working_db
      system( "rm #{working_db}" )
    end
    
    create_db

    if File.exists? file
      system( "mv #{file} #{file}.bak" )
    end
    
    system( "mv #{working_db} #{file}" )

    j.done
  end

  def download_sourcefile
    system( "node download.js" )
    system( "mv /tmp/*csv #{source_file}" )
  end

  def create_db
    puts "Creating database"

    system( "sqlite-utils insert #{working_db} stations #{source_file} --csv --detect-types" )

    system( "sqlite-utils transform #{working_db} stations \
               --rename 'Date Last Confirmed' date_last_confirmed \
               --rename 'EV Connector Types' ev_connector_types \
               --rename 'Fuel Type Code' fuel_type_code \
               --rename ID id \
               --rename City city \
               --rename State state \
               --rename ZIP zip \
               --rename Latitude latitude \
               --rename Longitude longitude")

    massage_data
  end

  def massage_data
    d = SQLite3::Database.open( working_db )

    d.busy_timeout = 1000
      
    results = d.query( "select distinct ev_connector_types from stations
                        where ev_connector_types != ''" )
      
    fields = {}
      
    results.each do |r|
      r[0].split(' ' ).collect { |x| fields[x] = true }
    end
    
    
    fields.keys.each do |key|
      puts "Adding column #{key.downcase}"
      d.execute "alter table stations add column #{key.downcase} integer;"
    end

    results = d.query( "select distinct ev_connector_types from stations
                        where ev_connector_types != ''" )

    results.each do |r|
      fields = r[0].split(' ' ).collect { |x| "#{x.downcase} = 1"}.join(", ")
      cmd =  "update stations set #{fields} where ev_connector_types = '#{r[0]}';"
      puts cmd
      c = d.execute cmd
    end
  end

end

if __FILE__ == $0
  db = Loader.new
  j = Job.new

  s = "%15s: %s\n"
  printf s, "job active", j.is_active?
  printf s, "db file", db.file
  printf s, "source file", db.source_file
  printf s, "data valid", db.data_valid?
  printf s, "db valid", db.valid?
  printf s, "source valid", db.source_valid?

  db.load_database if !db.data_valid? && !j.is_active?

end

