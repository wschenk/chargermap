require 'dotenv/load'
require 'sinatra/base'
require 'sqlite3'
require "sinatra/activerecord"
require 'net/http'
require 'uri'
require 'json'
require_relative './loader'
require_relative './job'

class Stations < ActiveRecord::Base
  def self.in_map( n, e, s, w, connectors, dc, l1, l2 )
    query = where( "Latitude > ? and Latitude < ? and Longitude > ? and Longitude < ?", s, n, w, e )
    if( !connectors.blank? && connectors != 'null' )
      sql = connectors.split( "," ).collect { |x| "#{x} = 1" }.join( " or ")
      query = query.where( sql )
    end

    if( dc == 'false' )
      query = query.where( '[EV DC Fast Count] = ""' )
    end

    if( l1 == 'false' )
      query = query.where( '[EV Level1 EVSE Num] = ""' )
    end

    if( l2 == 'false' )
      query = query.where( '[EV Level2 EVSE Num] = ""' )
    end

    puts query.to_sql

    query
  end
  
  def self.around( lat, lon, connectors = "", dc, l1, l2 )
    query = where( "Latitude > ? and Latitude < ? and Longitude > ? and Longitude < ?", lat - 1, lat + 1, lon - 1, lon + 1 )
    connectors.split( "," ).each do |c|
      query = query.where( "#{c} = ?", 1 )
    end

    if( dc == 'true' )
      query = query.where( "[EV DC Fast Count] != ?", 0 )
    else
      query = query.where( "[EV DC Fast Count] = ?", 0 )
    end

    if( l1 == 'true' )
      query = query.where( "[EV Level1 EVSE Num] != ?", 0 )
    else
      query = query.where( "[EV Level1 EVSE Num] = ?", 0 )
    end

    if( l1 == 'true' )
      query = query.where( "[EV Level2 EVSE Num] != ?", 0 )
    else
      query = query.where( "[EV Level2 EVSE Num] = ?", 0 )
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
  
  set :database, {adapter: "sqlite3", database: l.file}

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


    { db: l.file,
      source_file: l.source_file,
      source_valid: l.source_valid?,
      db_valid: l.valid?,
      data_valid: l.data_valid?,
      processing: j.is_active?
    }.to_json
  end

  get '/db' do
    send_file( l.file )
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

    Stations.in_map( params[:n],
                     params[:e],
                     params[:s],
                     params[:w],
                     params[:connectors],
                     params[:dc],
                     params[:level1],
                     params[:level2]
                   ).collect do |s|
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

  get '/food' do
    content_type :json

    puts params[:lat]
    puts params[:lng]

    # Build the URI with query parameters
uri = URI('https://serpapi.com/search.json')

# Define your query parameters as a hash
p = {

      engine: "google_maps",
      q: "food",
      ll: "@#{params[:lat]},#{params[:lng]},14z",
      google_domain: "google.com",
      hl: "en",
      type: "search",
      api_key: ENV['SERP_API_KEY'],
    }
  
# Append the query parameters to the URI
uri.query = URI.encode_www_form(p)

# Make the GET request
response = Net::HTTP.get_response(uri)

# Optionally, parse the JSON response
if response.is_a?(Net::HTTPSuccess)
  result = JSON.parse(response.body)
  return result.to_json
else
  return {error: "HTTP Error: #{response.code} #{response.message}"}.to_json
end
    # urlParams = {
    #   engine: "google_maps",
    #   q: "food",
    #   ll: `${lat},${lng},14z`,
    #   google_domain: "google.com",
    #   hl: "en",
    #   type: "search",
    #   api_key: serpApi,
    # });
  
    # const url = `https://serpapi.com/search.json?${urlParams}`;
  
  end
end
