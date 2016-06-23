require 'open-uri'
require 'nokogiri'

p Time.now

baseurl = "https://developer.apple.com"
doc = Nokogiri::HTML(open(baseurl + "/videos/wwdc2016/"))

doc.search("//a[contains(@href,'videos/play/wwdc2016')]").each do |link|
	title = link.content.gsub(/$\s+/, '')
	if title.nil? || title.empty?
	    next
	end
	href = link.attr("href")
	session = href.split('/').last

	if File.exists?("#{session}.vtt")
		p "    - #{session} skipping existing session"
		next
	end

	sessionurl = baseurl + href
	count = 0
	begin
		page = Nokogiri::HTML(open(sessionurl))
	rescue => e
		count += 1
		if count <= 3
			p "    - retrying #{session}: #{e}"
			retry
		else
			p "    - #{session} failed: #{e}"
		end
	end

	videolink = page.search("section[class='col-85 center']/video/source").first
	if videolink.nil?
	    next
	end
	vhref = videolink.attr("src")
	uri = URI(vhref)
	uri.path = uri.path.split('/')[0...-1].join('/') + '/'
	uri.query = nil

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
		
		p "+++++ #{session} download complete"
	rescue => e
		p "    - #{session} #{e}"
	end
end

