# encoding : UTF-8

require "nokogiri"
require "open-uri"
require "haml"

puts Encoding.default_internal

legis_num = 13 # id of the parliementary session
# url of the publication list
base_url = "http://www.assemblee-nationale.fr"
doc = nil
if File.exist?("dump.html")
  doc = Nokogiri::HTML(IO.read("dump.html"))
else
  url = "#{base_url}/#{legis_num}/documents/index-depots.asp"
  # open the file (loooonnnggg time)
  begin
    doc = Nokogiri::HTML(open(url))
  rescue OpenURI::HTTPError
    puts "offline"
  rescue Timeout::Error
    puts "time out"
  end
end

# getting close to the interesting tables
int_tables = doc.css('table table')

# getting the table we want
blop = nil
int_tables.each { |tab| blop = tab if tab.css('tr').count > 2 }

# extracting stuff
texts = Hash.new
# blop.css('tr').each { |tab_r| puts tab_r.css('td').first.css('b font a').attr("href") }
# blop.css('tr').each { |tab_r| puts tab_r.css('td').first.css('b font a').inner_html().gsub(/^n.+ /,'') }
first = true
blop.css('tr').each do |text|
  number, changed = text.css('td').first.css('b font a').inner_html().gsub(/^n. /,'').split(' ')
  if number == nil
    number, changed = text.css('td').first.css('b font').inner_html().gsub(/^n. /,'').split(' ')
    desc = text.css('td')[1].css('font').first.content.to_s
    texts[number] = {"number" => number, "link" => '', "desc" => desc, "changed" => (changed != nil), "supplements" => []}
  else
    number, sup = number.split('-')
    desc = text.css('td')[1].css('font').first.content.to_s.gsub(/\s/,' ')
    link = ""
    begin
    if (text.css('td').first.css('b font a').size > 0)
      link = base_url + text.css('td').first.css('b font a').attr("href")
    end
    rescue
      puts "text #{number} didn't pass\n#{text.css('td').first.css('b font a')}"
      puts "text : #{text.css('td').count} big"
      text.css('td').each { |td_s| puts "\t#{td_s}" }
    end
    if sup == nil
      texts[number] = {"number" => number, "link" => link, "desc" => desc, "changed" => (changed != nil), "supplements" => []}
    else
     texts[number]['supplements'] << {"title" => sup, "link" => link, "desc" => desc}
    end
  end
end

output_file = File.open("test.haml", "w:UTF-8")
output_file.puts "!!! XML\n!!! 1.1\n%html(xmlns=\"http://www.w3.org/1999/xhtml\")\n\t%head\n\t\t%meta(http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\")\n\t%body\n"

texts.keys.each do |num|
  d = texts[num]
  begin
    if d["supplements"].count > 0
      output_file.puts "\t\t%p\n\t\t\t%a{:href => \"#{d['link']}\"} #{d['number']}\n\t\t\t#{d['desc']}" + "\n"
      d['supplements'].each do |sup_t|
        output_file.puts "\t\t\t%a{:href => \"#{sup_t['link']}\"} #{sup_t['title']}\n\t\t\t#{sup_t['desc']}" + "\n"
      end
    else
      output_file.puts "\t\t%p\n\t\t\t%a{:href => \"#{d['link']}\"} #{d['number']}\n\t\t\t#{d['desc']}" + "\n"
    end
  rescue Encoding::CompatibilityError
    puts "#{d['number']} has encoding problem"
  end
end
output_file.close
haml_string = IO.read("test.haml")
engine = Haml::Engine.new(haml_string, :encoding => "utf-8")

puts Encoding.default_internal
File.open("test.html", "w") { |d| d.puts engine.render }

