require 'sinatra/base'
require 'sqlite3'
require "sinatra/activerecord"
require_relative './loader'
require_relative './job'

class Stations < ActiveRecord::Base
end

class App < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  l = Loader.new
  
  set :database, {adapter: "sqlite3", database: l.db}
  
  get '/' do
    l = Loader.new
    j = Job.new
    content_type :json

    { db: l.db,
      csv: l.csv,
      csv_exists: l.csv_exists?,
      db_exists: l.db_exists?,
      current: j.is_current?,
      processing: j.is_active?
    }.to_json
  end

  get '/stats' do
    if l.needs_reset
      Stations.connection.reconnect!
    end
    
    content_type :json
    {
      count: Stations.count,
      ct: Stations.where( "State = ?", "CT" ).count,
      ny: Stations.where( "State = ?", "NY" ).count
    }.to_json
  end

  get '/status' do 
    if l.needs_reset
      Stations.connection.reconnect!
    end
    
    content_type :json
    {
      count: Stations.count,
      date_last_confirmed: Stations.maximum( :date_last_confirmed ),
      tesla: Stations.where( tesla: 1 ).count,
      j1772: Stations.where( j1772: 1 ).count,
      j1772combo: Stations.where( j1772combo: 1 ).count,
      nema1450: Stations.where( nema1450: 1 ).count,
      nema515: Stations.where( nema515: 1 ).count,
      nema520: Stations.where( nema520: 1 ).count
    }.to_json
  end
end
