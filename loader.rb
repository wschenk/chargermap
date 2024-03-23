require 'csv'
require 'sqlite3'
require_relative './job'

class Loader
  def initialize
    @dir = ENV['DB_DIR'].blank? ? "." : ENV['DB_DIR']
  end

  def db; "#{@dir}/db"; end
  def csv; "#{@dir}/csv"; end
  
  def db_exists?; File.exist? db; end
  def csv_exists?; File.exist? csv; end

  def needs_reset
    j = Job.new

    if !j.is_active? && !j.is_current?
      j.start
      system( "mv #{csv} #{@dir}/bak.csv" )
      system( "mv #{db} #{@dir}/bak.db" )
      system( "ruby loader.rb&" )
    end

    j.reset_check
  end
  
  def ensure!
    if !db_exists?
      if !csv_exists?
        puts "Downloading csv"
        download_csv
      end
    end

    if !db_exists?
      create_db
    end
    
    j = Job.new
    j.done
  end
  
  def download_csv
    puts "Downloading csv"
    system( "node download.js" )
    system( "mv /tmp/*csv #{csv}" )
  end

  def create_db
    puts "Creating database"

    system( "sqlite-utils insert #{db} stations #{csv} --csv --detect-types" )

    system( "sqlite-utils transform #{db} stations \
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
    d = SQLite3::Database.open( db )
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
  puts "Running on command line"

  l = Loader.new
  puts "DB Exists? #{l.db_exists?}"
  puts "CSV Exists? #{l.csv_exists?}"

  l.ensure!

  puts "DB Exists? #{l.db_exists?}"
  puts "CSV Exists? #{l.csv_exists?}"
end
