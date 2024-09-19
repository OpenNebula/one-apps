#!/bin/ruby

require 'sinatra'

# Testing application for External Scheduler
# Returns valid response for the POST request
before do
    content_type 'application/json'
end

# get '/' do
#     'Hello get!'
# end

post '/' do
    body = request.body.read
    data = JSON.parse body

    # puts data

    vms = []
    response = { :VMS => vms }

    # Go through all Virtual Machines
    data['VMS'].each do |vm|
        vms << { :ID => vm['ID'], :HOST_ID => vm['ID'].to_i % 3 }
    end

    # puts response.to_json
    response.to_json
end
