#!/bin/bash/ruby

require "json"

hostname = JSON.parse(ENV["VCAP_APPLICATION"])["uris"][0]
file = "config/settings.yml"

text = File.read(file)
text.gsub!("localhost:3000", hostname)
text.gsub!("hostname", hostname)

File.open(file, "w") {|file| file.puts text}
