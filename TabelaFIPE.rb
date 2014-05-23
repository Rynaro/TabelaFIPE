require 'open-uri'
require 'cgi'
require 'nokogiri'
require 'socket'

class Fipe

	FIPE = "http://www.fipe.org.br/web/indices/veiculos/default.aspx?"

	def getBrand page, t	
		page.css('select#ddlMarca').css('option').collect{ |i| [i["value"].to_i, i.text, t ] unless i["value"].to_i == 0 }.compact
	end

	def getModel page
		page.css('select#ddlModelo').css('option').collect{ |i| i.text unless i["value"].to_i == 0 }.compact
	end

	def getViewState page
		page.css('#__VIEWSTATE')[0]["value"]
	end

	def getEventValidation page
		page.css('#__EVENTVALIDATION')[0]["value"]
	end

	def get host, path, data
		f, str = "", ""
		data.each do |i|
			str += "#{CGI::escape(i[0])}=#{CGI::escape(i[1])}&"
		end
		str.chop!
		skt = TCPSocket.open host, 80
		skt.print "POST #{path} HTTP/1.1\r\n"
		skt.print "Host: #{host}\r\n"
		skt.print "Content-type: application/x-www-form-urlencoded\r\n"
		skt.print "Content-length: #{str.size}\r\n"
		skt.print "Connection: close\r\n\r\n" 
		skt.print "#{str}\r\n\r\n"
		while line = skt.gets 
			f += line.chomp
		end
		skt.close
		f
	end

	def writeBrand b, f
		f.puts "# Marcas\n # -----"
		f.puts b.map{ |i| "{ :id => #{i[0]}, :description => \"#{i[1]}\", :type => #{i[2]} }," }
		f.puts "\n"
	end

	def writeModel m, f
		f.puts "# Modelos\n # -----"
		f.puts m.map{ |i| "{ :description => \"#{i[0]}\", :vehicle_brand_id => #{i[1]} }," }
	end

	def extract f
		file = File.new f, "w"
		types = [ ['51', ''], ['52', 'v=m&'], ['53', 'v=c&'] ]
		storedBrand, storedModel = [], []
		types.each do |v|
			type = "#{v[1]}p=#{v[0]}"
			fipe = Nokogiri::HTML open "#{FIPE}#{type}"
			brands = getBrand fipe, v[0]
			st = getViewState fipe
			ev = getEventValidation fipe
	
			brands.each do |i|
				storedBrand.push i
				getModel(Nokogiri::HTML get "fipe.org.br", "/web/indices/veiculos/default.aspx?#{type}", [ ["ScriptManager1", "ScriptManager1|ddlMarca"], ["__EVENTTARGET", "ddlMarca"], ["__EVENTVALIDATION", ev], ["__VIEWSTATE", st], ["ddlMarca", "#{i[0]}"], ["ddlAnoValor", '0'], ["ddlModelo", '0'] ]).each{|x| storedModel.push [ x , i[0]] }
			end
		end	
		puts "Escrevendo marcas..."
		writeBrand storedBrand, file
		puts "Escrevendo modelos..."
		writeModel storedModel, file
		file.close
	end

end

start = Time.now
Fipe.new.extract("arquivo.txt")
puts "Tempo decorrido: #{(Time.now - start).round(2)} s"
