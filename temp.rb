require 'mechanize'
require 'logger'

login_url = 'https://www.omahapermits.com/PermitInfo/Cap/CapHome.aspx?module=Permits&TabName=Permits'

class Mechanize::Page::Link
   def asp_click(action_arg = nil)
    etarget,earg = asp_link_args.values_at(0, 1)
    f = self.page.form_with(:name => 'aspnetForm')
    f.action = asp_link_args.values_at(action_arg) if action_arg
    f['__EVENTTARGET'] = etarget
    f['__EVENTARGUMENT'] = earg
    f.submit
  end
  def asp_link_args
    href = self.attributes['href']
    href =~ /\(([^()]+)\)/ && $1.split(/\W?\s*,\s*\W?/).map(&:strip).map {|i| i.gsub(/^['"]|['"]$/,'')}
  end
end

def scrape_permit_data(page_object)
  permits_recovered = Array.new
  rows = page_object.search('//*[@id="ctl00_PlaceHolderMain_dgvPermitList_gdvPermitList"]/tr')
  (2..11).each do |index|
    permit_row = Hash.new
    if(rows[index].search('td')[2].search('span').first)
      permit_row[:date] = rows[index].search('td')[2].search('span').first.text
    else
      # not a row!
      exit
    end
    if(rows[index].search('td')[3].search('span').first)
      permit_row[:number] = rows[index].search('td')[3].search('span').first.text
    else
      # the permit number is null
      exit
    end
    if(rows[index].search('td')[4].search('span').first)
      permit_row[:type] = rows[index].search('td')[4].search('span').first.text
    else
      # the permit type is null
      next
    end
    if(rows[index].search('td')[5].search('span').first)
      permit_row[:address] = rows[index].search('td')[5].search('span').first.text
    else
      # the permit address is null
      permit_row[:address] = ""
    end
    if(rows[index].search('td')[6].search('span').first)
      permit_row[:status] = rows[index].search('td')[6].search('span').first.text
    else
      # the permit status is null
      permit_row[:status] = ""
    end
    if(rows[index].search('td')[7].search('span').first)
      permit_row[:pending_actions] = rows[index].search('td')[7].search('span').first.text
    else
      # the permit number is null
      permit_row[:pending_actions] = ""
    end
    permits_recovered.push(permit_row)
  end
  return permits_recovered
end

agent = Mechanize.new do |a| 
#  a.log = Logger.new($stderr); 
#  a.log.level = 1 
  a.user_agent_alias = 'Mac Safari'
end

puts "Loading search form"
page = agent.get(login_url)
f = page.form_with(:name => 'aspnetForm')
f['ctl00$PlaceHolderMain$txtGSStartDate'] = '9/26/2012'
f['ctl00$PlaceHolderMain$txtGSEndDate'] = '9/26/2012'

puts "Loading first page of search results:"
p = page.link_with(:text => "Search").asp_click

permits = []

loop do
  puts "  Parsing page"
  tmp_result = scrape_permit_data(p)
  if(tmp_result.count > 0)
    puts "  Found " + tmp_result.count.to_s + " permits on this page"
    permits.push(*tmp_result)
  else
    exit
  end
  if(p.link_with(:text => "Next >"))
    puts "Loading next page:"
    p = p.link_with(:text => "Next >").asp_click
  else
    puts "Done: " + permits.count.to_s
    exit
  end
end
