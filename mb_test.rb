#!/usr/bin/env ruby

# This is a simple adaptation of Sam Saffron's Postgres bloat
# demonstration for Ruby.  I changed it from Postgres to MySQL to see
# if the same problems with external allocators were present.

# Most code here is originally Sam's, some of it lightly adapted.  Any
# problems in the MySQL-specific code are mine, of course.

# Post URL: https://samsaffron.com/archive/2018/06/13/ruby-x27-s-external-malloc-problem

def count_malloc(desc)
  start = GC.stat[:malloc_increase_bytes]
  yield
  delta = GC.stat[:malloc_increase_bytes] - start
  puts "#{desc} allocated #{delta} bytes"
end

def process_rss
  puts 'RSS is: ' + `ps -o rss -p #{$$}`.chomp.split("\n").last
end

def malloc_limits
  s = GC.stat
  puts "malloc limit #{s[:malloc_increase_bytes_limit]}, old object malloc limit #{s[:oldmalloc_increase_bytes_limit]}"
end

require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem 'mysql2'
end

require 'mysql2'

conn = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "benchdb")
sql = "select repeat('x', ?)"
statement = conn.prepare(sql)

# simulate a Rails app by long-term retaining 400_000 objects
#$long_term = []
#400_000.times do
#  $long_term << +""
#end

puts "start RSS/limits"
process_rss
malloc_limits

count_malloc("100,000 bytes MySQL") do
  #conn.exec(sql, [100_000])
  statement.execute(100_000)
end

x = []
10_000.times do |i|
  r = x[i%10] = statement.execute(100_000)
  #r = x[i%10] = statement.execute(100_000, :as => :array)
  #r.clear
end

puts "RSS/limits after allocating 10k 100,000 byte strings in mysql2 (with no #clear or equivalent)"
malloc_limits
process_rss

#10_000.times do |i|
#  #x[i%10] = conn.exec(sql, [100_000])
#  x[i%10] = statement.execute(100_000)
#  #x[i%10] = statement.execute(100_000, :as => :array)
#end
#
#puts "RSS/limits after allocating 10k 100,000 byte strings in libpq (and NOT clearing)"
#malloc_limits
#process_rss
