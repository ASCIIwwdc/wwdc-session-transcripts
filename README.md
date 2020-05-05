# WWDC Session Transcripts

As used by [ASCIIwwdc](https://asciiwwdc.com).

## Methodology

Transcripts for WWDC sessions are aggregated from subtitles included in session videos from 2010, 2013, 2014, 2015 and 2016.

The code used to automatically scrape and collect this information for 2014 sessions is as follows:

```ruby
require 'open-uri'
require 'nokogiri'

year = 2014
doc = Nokogiri::HTML(open("https://developer.apple.com/videos/wwdc/#{year}/"))

doc.search("p.download").each do |download|
  href = download.at("a").attr('href')
  uri = URI(href)
  uri.path = uri.path.split('/')[0...-1].join('/') + '/'
  uri.query = nil

  p session = uri.path.split('/').last.to_i

  begin
    subtitles = []
    m3u8 = open(URI.join(uri, "subtitles/eng/prog_index.m3u8"))
    m3u8.each_line do |line|
      next unless /\.webvtt$/ === line
      webvtt = open(URI.join(uri, "subtitles/eng/", line.strip))
      subtitles << webvtt.read
    end

    File.open("#{session}.vtt", "w") do |f|
      f.write subtitles.join("\n")
    end
  rescue => e
    p "! #{session} (#{e})"
    next
  end
end
```

Additional transcripts for 2012 WWDC content was graciously contributed by [Rev.com](http://www.rev.com/), and [community volunteers](https://github.com/mattt/wwdc-session-transcripts/graphs/contributors).

## Copyright

All content copyright © 2010–2014 Apple Inc. All rights reserved.
