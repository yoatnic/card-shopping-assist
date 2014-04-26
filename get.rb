require 'uri'
require 'open-uri'
require 'nokogiri'
require 'kconv'

# URLからHTMLを取得
def get_doc(url)
  charset = nil
  html = open(url) do |f|
    charset = f.charset
    f.read
  end

  doc = Nokogiri::HTML.parse(html, nil, charset)
end

#価格情報を取得
def find_price_link( doc )
  doc.css('p[@class="f9"]').each {|e|
    link = e.css('a')
    
    if (link && link.text.encode("UTF-8") == '【省略された価格情報を表示】')
        return link.attribute('href').to_s
    end
  }
  
  return nil
end

def find_card_info(str, doc)
  doc.xpath('//td[@class="l w"]').each{|e|
    if e.text.to_s.encode("UTF-8") == str
      link = e.css('a')
      dst = nil
      if (link)
        dst = get_doc('http://ocg.xpg.jp'+link.attribute('href').to_s)
      end
      
      return dst
    end
  }
end

def get_card_price_info(str)
  cond = URI.escape(str.encode("Shift_JIS"))
  url = 'http://ocg.xpg.jp/search/search.fcgi?Name=' + cond + '&Mode=0&Code=%82%A0'

  doc = get_doc(url)

  if doc.xpath('//h1')[0].text.encode("Shift_JIS").include?( '検索結果'.encode("Shift_JIS", "UTF-8") )
    doc = find_card_info str, doc
  end
  
  card_name = doc.xpath('//h1')[0].text.encode("Shift_JIS")

  price_info_url = find_price_link(doc);
  
  if (!price_info_url)
    return nil
  end
  
  price_info_url = 'http://ocg.xpg.jp' + find_price_link(doc)
  
  price_doc = get_doc(price_info_url)

  target = nil

  price_doc.xpath('//table[@class="jHover f9"]').each {|e|
    if ( e.to_s.include?('情報取得日'.encode("Shift_JIS", "UTF-8")) ) then
      target = e
	  break
    end
  }

  dst = {'card-name' => card_name.encode("UTF-8", "Shift_JIS"), 'price-data' => []}

  if (!target.nil?) then
    i = 0
    td = target.css('td')

    while (i < td.size - 4) 
  	  dst['price-data'].push(
        {'rarerity' => td[i + 1].to_s.encode("UTF-8", "Shift_JIS"),
         'shop-name' => td[i + 2].to_s.encode("UTF-8", "Shift_JIS"),
         'price' => td[i + 3].to_s.encode("UTF-8", "Shift_JIS")})
      i += 4
    end
  end
  
  return dst
end

def disp_card_name( data )
  data.each{|card|
    puts '<div>'
    puts '<p>'
    puts card['card-name']
    puts '</p>'
    
    puts '<table>'
    card['price-data'].each{|e|
      puts '<tr>'
      puts '<td>'
      puts e['rarerity']
      puts '</td>'
      puts '<td>'
      puts e['shop-name']
      puts '</td>'
      puts '<td>'
      puts e['price']
      puts '</td>'
      puts '</tr>'
    }
    puts '</table>'
    puts '</div>'
  }
end

card_names = ['ワイト', 'Ｎｏ.３９ 希望皇ホープ']

price_data =[]
card_names.each {|e|
  price_data.push get_card_price_info(e)
}

f = open(ARGV[0])
f.each {|line| print line}
f.close

disp_card_name price_data

f = open(ARGV[1])
f.each {|line| print line}
f.close
