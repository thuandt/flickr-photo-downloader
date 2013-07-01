Flickr Photo Downloader
=======================

Ruby script to download all the photos from a flickr: group pool, user's
photostream, photosets and favorites

Usage
-----

Checkout the code:

    git clone git://github.com/mrtuxhdb/flickr-photo-downloader.git
    cd flickr-photo-downloader

Install bundler:

    gem install bundler
    bundle install

Change `FlickRaw.api_key` and `FlickRaw.shared_secret` value with your
[API key and shared secret](https://secure.flickr.com/services/apps/create/apply)

    FlickRaw.api_key="... Your API key ..."
    FlickRaw.shared_secret="... Your shared secret ..."

Change `flickr.access_token` and `flickr.access_secret` value with your
`access_token` and `access_secret` (you can get it with
[flickr_auth.rb](flickr_auth.rb))

    # Get your access_token & access_secret with flick_auth.rb
    flickr.access_token    = "... Your access token ..."
    flickr.access_secret   = "... Your access secret ..."

Run the script, specifying your photostream, photoset or favorites URLs as the argument:

    ruby flickr-photo-downloader.rb http://www.flickr.com/groups/aodai/pool http://www.flickr.com/photos/jethuynh/sets/72157633130184165/

By default, images will be saved in folder `Pictures` on `user directory`
(eg /home/mrtux/Pictures). If you want them to be saved to a
different directory, you can pass its name as an optional `-d` argument:

    ruby flickr-photo-downloader.rb http://www.flickr.com/groups/aodai/pool -d ~/Pictures/AoDai

You can import link from `input-file` with `-i` argument and
export all photo links to `output-file` with `-o` argument

    ruby flickr-photo-downloader.rb -i input.txt -o urllist.txt

More help and options

    ruby flickr-photo-downloader.rb --help

Enjoy!



License
-------

Source code released under an [MIT license](http://en.wikipedia.org/wiki/MIT_License)

Pull requests welcome.


Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


Authors
-------

* **Dương Tiến Thuận** ([@mrtuxhdb](https://github.com/mrtuxhdb))

