#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'em-http-request'

p Time.now

year = 2015
baseurl = "https://developer.apple.com/videos/wwdc/#{year}/"
doc = Nokogiri::HTML(open(baseurl))

EM.run do
  urls = {}
  search_results = doc.search('section#all_videos//a')

  EM::Iterator.new(search_results, 10).each(proc do |link, iter|
    href = link.attr('href')
    session = href[/\d+$/]

    if File.exist?("#{session}.vtt")
      p "    - #{session} skipping existing session"
      iter.next
      next
    end

    p "    - #{session} downloading"
    sessionurl = baseurl + href

    req = EM::HttpRequest.new(sessionurl).get
    req.callback do
      page = Nokogiri::HTML(req.response)

      videolink = page.search('section.row//ul.text-right//a').first
      vhref = videolink.attr('href')
      uri = URI(vhref)
      uri.path = uri.path.split('/')[0...-1].join('/') + '/'
      uri.query = nil
      urls[session] = uri
      p "    - #{session} page downloaded"
      iter.next
    end
  end, proc do
    p "    - #{urls.count} sessions"

    EM::Iterator.new(urls.keys, 10).each(proc do |session, iter|
      original_uri = urls[session]
      uri = URI.join(original_uri, 'subtitles/eng/prog_index.m3u8')
      req = EM::HttpRequest.new(uri).get

      req.callback do
        p "    - #{session} downloaded playlist"
        multi = EM::MultiRequest.new
        metadata = req.response.split("\n").select { |x| /\.webvtt$/ === x }

        if metadata.count == 0
          iter.next
          p "    - #{req.response}"
        end

        EM::Iterator.new(metadata, 10).each do |x, sub_iter|
          uri = URI.join(original_uri, 'subtitles/eng/', x.strip)
          multi.add x.strip, EM::HttpRequest.new(uri).get
          sub_iter.next
        end

        multi.callback do
          if metadata - multi.responses[:callback].keys == []
            subdata = metadata.map do |x|
              multi.responses[:callback][x].response
            end.join("\n")

            File.open("#{session}.vtt", 'w') do |f|
              f.write(subdata)
            end
            p "    - #{session} saved subs"
          else
            multi.responses[:errback].each do |x|
              p "    - #{x.first}: #{x.last.error}"
            end
          end

          iter.next
        end
      end
    end, proc do
      EM.stop
    end)
  end)
end
