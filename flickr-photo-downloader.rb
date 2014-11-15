#!/usr/bin/env ruby
# Filename: flick-photo-downloader.rb
# Description: Easily download all the photos from a flickr: group pool,
#              photostream, photosets and favorites

require 'rubygems'
require 'bundler'
require 'fileutils'
require 'optparse'
Bundler.require

# Get your API Key: https://secure.flickr.com/services/apps/create/apply
FlickRaw.api_key       = "... Your API key ..."
FlickRaw.shared_secret = "... Your shared secret ..."

# Get your access_token & access_secret with flick_auth.rb
flickr.access_token    = "... Your access token ..."
flickr.access_secret   = "... Your access secret ..."

begin
  login = flickr.test.login
  puts "You are now authenticated as #{login.username}"
rescue FlickRaw::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end

options = { :input_file => nil, :output_file => nil,
            :url_list => [], :directory => ENV["HOME"] + "/Pictures"}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage:  #{File.basename(__FILE__)} [OPTIONS] OTHER_ARGS"

  opts.separator ""
  opts.separator "Specific Options:"

  opts.on("-i", "--input-file INPUT-FILE",
          "Import url list from file") do |ifile|
    options[:input_file] = ifile
  end

  opts.on("-o", "--output-file OUTPUT-FILE",
          "Export url list to file") do |ofile|
    options[:output_file] = ofile
  end

  opts.on("-d", "--directory DIRECTORY",
          "Directory to save pictures") do |dir|
    options[:directory] = dir
  end

  opts.separator "Common Options:"

  opts.on("-h", "--help",
          "Show this message." ) do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  options[:url_list] = ARGV
rescue
  puts optparse
  exit
end

$input_file  = options[:input_file]
$output_file = options[:output_file]
$url_list    = options[:url_list]
$directory   = options[:directory]

if $input_file
  input_text = File.open($input_file).read
  input_text.gsub!(/\r\n?/, "\n")
  input_text.each_line do |url|
    $url_list.push(url)
  end
end

if $output_file
  $f_urllist = File.open(File.expand_path($output_file), "a+")
end

def download(image_urls)
  concurrency = 8

  puts "Downloading #{image_urls.count} photos from flickr with concurrency=#{concurrency} ..."
  FileUtils.mkdir_p($directory)

  image_urls.each_slice(concurrency).each do |group|
    threads = []
    group.each do |url|
      threads << Thread.new {
        begin
          file = Mechanize.new.get(url)
          filename = File.basename(file.uri.to_s.split('?')[0])
          if File.exists?("#{$directory}/#{filename}") and Mechanize.new.head(url)["content-length"].to_i === File.stat("#{directory}/#{filename}").size.to_i
            puts "Already have #{url}"
          else
            puts "Saving photo #{url}"
            file.save_as("#{$directory}/#{filename}")
          end

        rescue Mechanize::ResponseCodeError
          puts "Error getting file, #{$!}"
        end
      }
    end
    threads.each{|t| t.join }
  end
end

def save_image(image_urls)
  if $output_file
    image_urls.each do |url|
      $f_urllist.write("#{url}\n")
    end
  else
    download(image_urls)
  end
end

# Web Page URLs
# https://secure.flickr.com/services/api/misc.urls.html
#
# http://www.flickr.com/people/{user-id}/ - profile
# http://www.flickr.com/photos/{user-id}/ - photostream
# http://www.flickr.com/photos/{user-id}/{photo-id} - individual photo
# http://www.flickr.com/photos/{user-id}/sets/ - all photosets
# http://www.flickr.com/photos/{user-id}/sets/{photoset-id} - single photoset

flickr_regex = /http[s]?:\/\/(?:www|secure).flickr.com\/(groups|photos)\/[\w@-]+(?:\/(\d{11}|sets|pool|favorites)[\/]?)?(\d{17})?(?:\/with\/(\d{11}))?[\/]?$/

# Photostream Regex
# photo_stream_regex  = /http[s]?:\/\/(?:www|secure).flickr.com\/photos\/([\w@]+)[\/]?$/
#
# Single photoset
# photo_sets_regex    = /http[s]?:\/\/(?:www|secure).flickr.com\/photos\/([\w@]+)\/sets\/(\d{17})[\/]?$/
#
# Individual photo
# photo_single_regex0 = /http[s]?:\/\/(?:www|secure).flickr.com\/photos\/([\w@]+)\/sets\/(\d{17})\/with\/(\d{10})[\/]?$/
# photo_single_regex1 = /http[s]?:\/\/(?:www|secure).flickr.com\/photos\/([\w@]+)\/(\d{10})[\/]?$/

image_urls = []

$url_list.each do |url|
  if match = url.match(flickr_regex)
    # match_group1: user photostream or group pool
    # match_group2: individual photo id, "sets", "pool" or "favorites"
    # match_group3: photoset id
    # match_group4: individual photo id
    match_group1, match_group2, match_group3, match_group4 = match.captures
  else
    puts "URL: #{url} don't match with supported flickr url"
    break
  end

  if match_group1.eql?("photos")
    ##### Get photolist of user #####
    if match_group2.nil?
      # flickr.people.lookUpUser(:url => url)
      f_user         = flickr.people.getInfo(:url => url)
      f_user_id      = f_user["id"]
      f_photo_count  = f_user["photos"]["count"]
      f_page_count   = (f_photo_count.to_i / 500.0).ceil
      f_current_page = 1

      while f_current_page <= f_page_count
        photo_list = flickr.people.getPhotos( :user_id => f_user_id,
                                              :safe_search => "3",
                                              :extras => "url_o",
                                              :page => f_current_page,
                                              :per_page => "500")
        photo_list.each do |photo|
          if !photo["url_o"].nil?
            image_urls.push(photo["url_o"])
          elsif !FlickRaw.url_b(photo).nil?
            image_urls.push(FlickRaw.url_b(photo))
          elsif !FlickRaw.url_c(photo).nil?
            image_urls.push(FlickRaw.url_c(photo))
          elsif !FlickRaw.url_z(photo).nil?
            image_urls.push(FlickRaw.url_z(photo))
          end
        end

        f_current_page += 1
        save_image(image_urls)
        image_urls.clear
      end

    ##### Get photo list of photoset #####
    elsif match_group2.eql?("sets") and match_group4.nil?
      f_photoset       = flickr.photosets.getInfo(:photoset_id => match_group3)
      f_photoset_id    = f_photoset["id"]
      f_photoset_count = f_photoset["photos"]
      f_page_count     = (f_photoset_count.to_i / 500.0).ceil
      f_current_page   = 1

      while f_current_page <= f_page_count
        photo_list = flickr.photosets.getPhotos(:photoset_id => f_photoset_id,
                                                :extras => "url_o",
                                                :page => f_current_page,
                                                :per_page => "500")
        photo_list = photo_list["photo"]

        photo_list.each do |photo|
          if !photo["url_o"].nil?
            image_urls.push(photo["url_o"])
          elsif !FlickRaw.url_b(photo).nil?
            image_urls.push(FlickRaw.url_b(photo))
          elsif !FlickRaw.url_c(photo).nil?
            image_urls.push(FlickRaw.url_c(photo))
          elsif !FlickRaw.url_z(photo).nil?
            image_urls.push(FlickRaw.url_z(photo))
          end
        end

        f_current_page += 1
        save_image(image_urls)
        image_urls.clear
      end

    ##### Get photo list of user favorites #####
    elsif match_group2.eql?("favorites")
      fav_user         = flickr.people.getInfo(:url => url)
      fav_user_id      = fav_user["id"]
      fav_photo_count  = flickr.favorites.getList(:user_id => fav_user_id,
                                                  :per_page => "1",
                                                  :page => "1")["total"]
      fav_page_count   = (fav_photo_count.to_i / 500.0).ceil
      fav_current_page = 1

      while fav_current_page <= fav_page_count
        photo_list = flickr.favorites.getList(:user_id => fav_user_id,
                                              :extras => "url_o",
                                              :page => f_current_page,
                                              :per_page => "500")
        photo_list.each do |photo|
          if !photo["url_o"].nil?
            image_urls.push(photo["url_o"])
          elsif !FlickRaw.url_b(photo).nil?
            image_urls.push(FlickRaw.url_b(photo))
          elsif !FlickRaw.url_c(photo).nil?
            image_urls.push(FlickRaw.url_c(photo))
          elsif !FlickRaw.url_z(photo).nil?
            image_urls.push(FlickRaw.url_z(photo))
          end
        end

        fav_current_page += 1
        save_image(image_urls)
        image_urls.clear
      end

    ##### Get individual photo url #####
    else
      if match_group4.nil?
        photo = flickr.photos.getInfo(:photo_id => match_group2)
      else
        photo = flickr.photos.getInfo(:photo_id => match_group4)
      end
      if !photo["url_o"].nil?
        image_urls.push(photo["url_o"])
      elsif !FlickRaw.url_b(photo).nil?
        image_urls.push(FlickRaw.url_b(photo))
      elsif !FlickRaw.url_c(photo).nil?
        image_urls.push(FlickRaw.url_c(photo))
      elsif !FlickRaw.url_z(photo).nil?
        image_urls.push(FlickRaw.url_z(photo))
      end
      save_image(image_urls)
      image_urls.clear
    end
  ##### Get individual photo url #####
  elsif match_group1.eql?("groups")
    g_group        = flickr.urls.lookupGroup(:url => url)
    g_group_id     = g_group["id"]
    g_group_name   = g_group["groupname"]
    g_photo_count  = flickr.groups.getInfo(:group_id => g_group_id)["pool_count"]
    g_page_count   = (g_photo_count.to_i / 500.0).ceil
    g_current_page = 1

    while g_current_page <= g_page_count
      photo_list = flickr.groups.pools.getPhotos( :group_id => g_group_id,
                                                  :extras => "url_o",
                                                  :page => g_current_page,
                                                  :per_page => "500")
      photo_list = photo_list["photo"]

      photo_list.each do |photo|
        if !photo["url_o"].nil?
          image_urls.push(photo["url_o"])
        elsif !FlickRaw.url_b(photo).nil?
          image_urls.push(FlickRaw.url_b(photo))
        elsif !FlickRaw.url_c(photo).nil?
          image_urls.push(FlickRaw.url_c(photo))
          elsif !FlickRaw.url_z(photo).nil?
            image_urls.push(FlickRaw.url_z(photo))
        end
      end

      g_current_page += 1
      save_image(image_urls)
      image_urls.clear
    end

  end
end

if $output_file
  $f_urllist.close
end

puts "Done."
