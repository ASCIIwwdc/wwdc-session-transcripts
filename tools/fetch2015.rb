require 'open-uri'
require 'nokogiri'

p Time.now

baseurl = "https://developer.apple.com/videos/wwdc/2015/"
doc = Nokogiri::HTML(open(baseurl))

doc.search("section#all_videos//a").each do |link|
	title = link.content
	href = link.attr("href")
	session = href[/\d+$/]

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

	videolink = page.search("section.row//ul.text-right//a").first
	vhref = videolink.attr("href")
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

