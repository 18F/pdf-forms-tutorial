require 'bundler/setup'
require 'sinatra'
require 'json'
require 'tempfile'
require 'sinatra/cross_origin'
require_relative 'form_filler.rb'
require 'pry'

configure do
  enable :cross_origin
end

options '/sf2809' do
  halt 200
end

post '/sf2809' do
  begin
    json_params = JSON.parse(request.body.read)
    form = SF2809.new(fill_values: json_params)
    file = form.save('tmp')
    bytes = File.read(file)
    File.delete(file)
    tmpfile = Tempfile.new('response.pdf')
    tmpfile.write(bytes)
    send_file(tmpfile)
  rescue => e
    content_type :json
    return {
      error: e.to_s
    }
  end
end
