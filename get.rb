# HTML取得用のライブラリ
require 'uri'
require 'open-uri'
# HTMLパーサ
require 'nokogiri'
# 文字コード変換
require 'kconv'

# URLからHTMLのオブジェクトを取得
# @param[string] url HTMLを取得する対象のURL
# @return HTMLのオブジェクト
def get_doc(url)
  charset = nil
  html = open(url) do |f|
    charset = f.charset
    f.read
  end

  doc = Nokogiri::HTML.parse(html, nil, charset)
end

# 価格情報へのURLを取得
# @param doc HTMLのオブジェクト
# @return[string] 価格情報へのURL
def find_price_link( doc )
  doc.css('p[@class="f9"]').each {|e|
    link = e.css('a')
    
    if (link && link.text.encode("UTF-8") == '【省略された価格情報を表示】')
      return link.attribute('href').to_s
    end
  }
  
  return nil
end

# 検索結果からカード名が完全一致するカードページのURLを取得
# @param[string] str  カード名
# @param doc HTMLのオブジェクト
# @return カードページのURL
def find_card_info(str, doc)
  doc.xpath('//td[@class="l w"]').each{|e|
    if e.text.to_s.encode("UTF-8") == str
      link = e.css('a')
      dst = get_doc('http://ocg.xpg.jp'+link.attribute('href').to_s)
      
      return dst
    end
  }
  return nil
end

# カードを扱うショップ、価格、レアリティを取得
# ToDo: もうちょっとコードを綺麗にしたい
# @param[string] str カード名
# @return[hash] 
# {
#  'card-name' : カード名,
#  'price-data'[array] : 価格データ
#  [
#   {'rarerity' : レアリティ, 'shop-name' ： ショップ名, 'price' : 価格}
#  ]
# }
def get_card_price_info(card)
  cond = URI.escape(card['card-name'].encode("Shift_JIS"))
  url = 'http://ocg.xpg.jp/search/search.fcgi?Name=' + cond + '&Mode=0&Code=%82%A0'

  # カード検索を実施
  doc = get_doc(url)

  return nil if (!doc)

  # カード名が複数ヒットした場合は、その中からカード名が完全一致するものを見つける
  if doc.xpath('//h1')[0].text.encode("Shift_JIS").include?( '検索結果'.encode("Shift_JIS", "UTF-8") )
    doc = find_card_info card['card-name'], doc
  end
  
  return nil if (!doc)
  
  # カード名の取得
  card_name = doc.xpath('//h1')[0].text.encode("Shift_JIS")

  # カードの価格情報のURLを取得
  price_info_url = find_price_link(doc);
  
  return nil if (!price_info_url)
  
  price_info_url = 'http://ocg.xpg.jp' + find_price_link(doc)
  
  # 価格情報のページを取得
  price_doc = get_doc(price_info_url)

  target = nil

  # 価格情報ページから価格が掲載されている<table>を取得
  price_doc.xpath('//table[@class="jHover f9"]').each {|e|
    if ( e.to_s.include?('情報取得日'.encode("Shift_JIS", "UTF-8")) ) then
      target = e
	  break
    end
  }

  # カードの情報、各ショップの価格情報を抽出
  dst = {'card-name' => card_name.encode("UTF-8", "Shift_JIS"), 'price-data' => []}

  if (!target.nil?)
    i = 0
    td = target.css('td')

    while (i < td.size - 4)
      rarerity = td[i + 1].text.to_s.encode("UTF-8", "Shift_JIS")

      if (card['rarerity'] == rarerity)
        dst['price-data'].push(
          {'rarerity' => rarerity,
           'shop-name' => td[i + 2].text.to_s.encode("UTF-8", "Shift_JIS"),
           'price' => td[i + 3].text.to_s.encode("UTF-8", "Shift_JIS")})
      end
      i += 4
    end
  end
  
  return dst
end

# 価格情報を整形して表示
# @param[hash] data 表示するカードデータ
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

card_names = [{'card-name' => 'ワイト', 'rarerity' => 'Normal'}, {'card-name' => 'Ｎｏ.３９ 希望皇ホープ', 'rarerity' => 'Ultra'}]

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
