require 'sinatra/base'
require 'sqlite3'
require "sinatra/activerecord"
require_relative './loader'
require_relative './job'

class Stations < ActiveRecord::Base
  def self.in_map( n, e, s, w, connectors )
    query = where( "Latitude > ? and Latitude < ? and Longitude > ? and Longitude < ?", s, n, w, e )
    if( !connectors.blank? && connectors != 'null' )
      sql = connectors.split( "," ).collect { |x| "#{x} = 1" }.join( " or ")
      query = query.where( sql )
    end

    puts query.to_sql

    query
  end
  
  def self.around( lat, lon, connectors = "" )
    query = where( "Latitude > ? and Latitude < ? and Longitude > ? and Longitude < ?", lat - 1, lat + 1, lon - 1, lon + 1 )
    connectors.split( "," ).each do |c|
      query = query.where( "#{c} = ?", 1 )
    end

    query
  end

  def to_serialize
    { id: id,
      latitude: latitude,
      longitude: longitude,
      name: attributes['Station Name'],
      address: attributes['Street Address'],
      city: city,
      state: state,
      zip: zip,
      country: attributes['Country'],
      facility: attributes['Facility Type'],
      level1: attributes['EV Level1 EVSE Num'],
      level2: attributes['EV Level2 EVSE Num'],
      dcfast: attributes['EV DC Fast Count'],
      network: attributes['EV Network'],
      date_last_confirmed: date_last_confirmed,
      workplace: attributes['EV Workplace Charging'],
      chademo: chademo,
      j1772: j1772,
      j1772combo: j1772combo,
      nema1450: nema1450,
      nema515: nema515,
      tesla: tesla
    }
  end
end

class App < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  l = Loader.new
  
  set :database, {adapter: "sqlite3", database: l.db}

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    if l.needs_reset
      Stations.connection.disconnect!
    end
  end

  get '/' do
    l = Loader.new
    j = Job.new
    content_type :json

    if params[:id]
      return Stations.find(id).to_serialize.to_json
    end


    { db: l.db,
      csv: l.csv,
      csv_exists: l.csv_exists?,
      db_exists: l.db_exists?,
      current: j.is_current?,
      processing: j.is_active?
    }.to_json
  end

  get '/stats' do
    content_type :json
    {
      count: Stations.count,
      ct: Stations.where( "State = ?", "CT" ).count,
      ny: Stations.where( "State = ?", "NY" ).count
    }.to_json
  end

  get '/facility_types' do
    content_type :json
    Stations.group( "Facility Type" ).count.to_json
  end
    
  get '/networks' do
    content_type :json
    Stations.group( "EV Network" ).count.to_json
  end

  get '/around' do
    content_type :json
    if params[:lat].blank? || params[:lon].blank?
      return {error: "lat and lon must be set"}.to_json
    end
    
    Stations.around( params[:lat].to_f, params[:lon].to_f, params[:connectors] ).collect do |s|
      s.to_serialize
    end.to_json
  end

  get '/in_map' do
    content_type :json

    Stations.in_map( params[:n], params[:e], params[:s], params[:w], params[:connectors] ).collect do |s|
      s.to_serialize
    end.to_json
  end

  get '/status' do 
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
