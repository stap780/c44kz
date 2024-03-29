class Product < ApplicationRecord
  require 'open-uri'
  scope :product_all_size, -> { order(:id).size }
  scope :product_qt_not_null, -> { where('quantity > 0') }
  scope :product_qt_not_null_size, -> { where('quantity > 0').size }
  scope :product_cat, -> { order('cattitle ASC').select(:cattitle).uniq }
  scope :product_barcode_nil, -> { where(barcode: [nil, '']).order(:id) }
  scope :product_image_nil, -> { where(image: [nil, '']).order(:id) }
  scope :product_api_update, -> { where(barcode: [nil, ''], image: [nil, '']).order(:id)}
  scope :product_for_insales, -> { where('quantity > 0').where.not(price: [nil, 0]).pluck(:id) }
  before_save :normalize_data_white_space
  # before_save :vstrade_url_normalize
  before_save :update_quantity
  before_save :update_pricepr
  before_save :update_pricepropt
  validates :sku, uniqueness: true

  # Product.select(:cattitle).uniq.order('cattitle ASC')

  def self.quantity_search(v)
		default_v = Product.pluck(:quantity).uniq.sort.last
		value = Array(0..default_v) if v == 'all'
		value = 0 if v.to_i == 0
		value = Array(1..default_v) if v != 'all' && v.to_i != 0
	end

  def self.get_file
    puts 'загружаем файл с остатками - ' + Time.now.in_time_zone('Moscow').to_s

    url = 'https://b2bportal.al-style.kz/export/Al-Style_price.xlsx'

    download = RestClient::Request.execute(method: :get, url: url, raw_response: true)
    if download.code == 200
      download_path = Rails.public_path.to_s + '/ost.xlsx'
      IO.copy_stream(download.file.path, download_path)
      Product.open_file(download_path)
    else
      sleep 0.5
      puts 'sleep 0.5'
    end

    puts 'закончили загружаем файл с остатками - ' + Time.now.in_time_zone('Moscow').to_s
  end

  def self.get_file_vstrade
    puts 'загружаем файл vstrade с остатками - ' + Time.now.in_time_zone('Moscow').to_s
    file = Rails.public_path.to_s + '/vstrade_full.html'
    check = File.file?(file)
    File.delete(file) if check.present?

    a = Mechanize.new
    a.get('https://www.vstrade.kz/')
    form = a.page.form_with(action: '/index.php?login=yes')
    form['LoginForm[username]'] = 'info@c44.kz'
    form['LoginForm[password]'] = '87654321'
    form.submit
    page = a.get('https://www.vstrade.kz/')
    url = 'https://vstrade.kz/t/spec-price.php'

    download = RestClient::Request.execute(method: :get, url: url, raw_response: true)
    if download.code == 200
      download_path = Rails.public_path.to_s + '/vstrade_full.html'
      IO.copy_stream(download.file.path, download_path)
      Product.update_all(quantity2: 0)
      Product.open_file_vstrade
    else
      sleep 0.5
      puts 'sleep 0.5'
    end

    puts 'закончили загружаем файл vstrade с остатками - ' + Time.now.in_time_zone('Moscow').to_s
  end

  def self.open_file(file)
    puts 'обновляем из файла - ' + Time.now.in_time_zone('Moscow').to_s
    spreadsheet = open_spreadsheet(file)
    header = spreadsheet.row(1)
    last_number = Rails.env.development? ? 120 : spreadsheet.last_row.to_i

    (5..last_number).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      sku = row['Код']
      skubrand = row['Артикул']
      title = row['Наименование']
      sdesc = row['Полное наименование']
      costprice = row['Цена дил.']
      price = row['Цена роз.']
      quantity1 = row['Остаток'].to_s.gsub('>', '') unless row['Остаток'].nil?
      next unless title.present?

      product_data = { sku: sku, skubrand: skubrand, title: title, sdesc: sdesc, costprice: costprice, price: price,
                     quantity1: quantity1 }
      product = Product.find_by_sku(product_data[:sku])
      product.present? ? product.update(product_data) : Product.create(product_data)
    end

    puts 'конец обновляем из файла - ' + Time.now.in_time_zone('Moscow').to_s
    Product.price_updates
  end

  def self.open_file_vstrade
    puts 'обновляем из файла vstrade - ' + Time.now.in_time_zone('Moscow').to_s
    file_url = Rails.public_path.to_s + '/vstrade_full.html'
    doc = Nokogiri::HTML(open(file_url, read_timeout: 50))
    table = doc.css('table')[1]
    products_file = table.css('tr')
    products_file.each_with_index do |prf, index|
      if !prf.css('td')[1].nil? && (prf.css('td')[1] != 'Наименование')
        sku2 = prf.css('td')[0].text
        sku = sku2 + '-2'
        skubrand = prf.css('td')[2].text
        title_file = prf.css('td')[1]
        title = title_file.text
        url = title_file.css('a')[0]['href']#.gsub('http://vstrade.kz', 'https://wwww.vstrade.kz')
        costprice2 = prf.css('td')[3].text
        quantity2 = prf.css('td')[4].text
        if sku.present?
          product = Product.find_by_sku2(sku2)
          if product.present?
            costprice = product.costprice.present? && product.sku != sku ? product.costprice : costprice2

            product.update_attributes(costprice: costprice, costprice2: costprice2, quantity2: quantity2)
          else
            Product.create(sku: sku, sku2: sku2, skubrand: skubrand, title: title, costprice: costprice2,
                           costprice2: costprice2, quantity2: quantity2, url: url)
          end
        end
      end

      break if (index == 30) && Rails.env.development?
    end

    puts 'конец обновляем из файла vstrade - ' + Time.now.in_time_zone('Moscow').to_s
    Product.vstrade_get_image_desc
    Product.update_quantity
    Product.price_updates
  end

  def self.vstrade_get_image_desc
    puts 'обновляем vstrade_get_image_desc - ' + Time.now.in_time_zone('Moscow').to_s

    products = Product.ransack(sku2_present: true, image_present: false).result #Product.where.not(sku2: [nil, '']).where(image: [nil, '']).order(:id)
    products.each do |pr|
      puts 'pr id - ' + pr.id.to_s
      url = 'https://www.vstrade.kz/'+ pr.url.split('kz/').last
      # puts 'url - ' + url.to_s
      pr_url = Addressable::URI.parse(url).normalize.to_s
      RestClient.get(pr_url) do |response, _request, _result, &block|
        case response.code
        when 200
          Product.vstrade_get_image_desc_by_product(pr, response)
        when 422
          puts 'error 422 - обновляем vstrade_get_image_desc'
          puts response
          break
        when 403
          puts 'error 403 - обновляем vstrade_get_image_desc'
          break
        when 404
          puts 'error 404 - обновляем vstrade_get_image_desc'
          break
        when 503
          sleep 1
          puts 'sleep 1 error 503'
        else
          response.return!(&block)
        end
      end
    end
    puts 'конец обновляем vstrade_get_image_desc - ' + Time.now.in_time_zone('Moscow').to_s
  end

  def self.vstrade_get_image_desc_by_product(pr, response)

    pr_doc = Nokogiri::HTML(response, nil, Encoding::UTF_8.to_s)
    # pr_doc = Nokogiri::HTML(open(Addressable::URI.parse(url).normalize  , :read_timeout => 50), nil, Encoding::UTF_8.to_s)
    weight = pr_doc.css('.weight').text.gsub('Вес товара: ', '').gsub('г', '')
    pict_thumbs = pr_doc.css('.thumbnails-slidee .thumb img')
    picts = []
    if pict_thumbs.size > 0
      pict_thumbs.each do |p|
        unless p['data-big-src'].include?('gif')
          pl = 'https://www.vstrade.kz' + p['data-big-src'].to_s.gsub('resizer2/1', 'resizer2/15')
          picts.push(pl)
        end
      end
    else
      if pr_doc.css('.product-photo img').present? && !pr_doc.css('.product-photo img')[0]['data-big-src'].include?('gif')
        pl = 'https://www.vstrade.kz' + pr_doc.css('.product-photo img')[0]['data-big-src'].to_s.gsub('resizer2/1',
                                                                                                      'resizer2/15')
      else
        pl = ''
      end
      picts.push(pl)
    end
    pict_file = picts.uniq.join(' ')
    proper = []
    proper_file = pr_doc.css('.tech-info-block .expand-content').inner_html.gsub('</dt>', ':').gsub('</dd>', ' --- ').gsub('<dt>', '').gsub('<dd>', '')
    clear_proper = Nokogiri::HTML(proper_file)
    properties = clear_proper.text
    properties.split('---').each do |prop|
      # @desc = prop.gsub('Полное описание:', '').squish if prop.include?(':') && prop.include?('Полное описание')
      @barcode = prop.gsub('Штрих код:', '').squish if prop.include?(':') && prop.include?('Штрих код')
      if prop.include?(':') && !prop.include?('Полное описание') && !prop.include?('Бренд') && !prop.include?('Штрих код')
        proper.push(prop.squish)
      end
    end
    charact_file = proper.join(' --- ')

    cat_array = []
    pr_doc.css('.breadcrumbs-content a span').each do |c|
      c.text == 'Каталог' ? cat_array.push('Vstrade') : cat_array.push(c.text)
    end

    cattitle_file = cat_array.join('/')
    desc = pr_doc.css('div.desc').inner_html

    brand_file = pr_doc.css('meta[itemprop=brand]')[0]['content'] if pr_doc.css('meta[itemprop=brand]').present?
    brand = !pr.brand.present? ? brand_file : pr.brand

    image = !pr.image.present? ? pict_file : pr.image

    cattitle = !pr.cattitle.present? ? cattitle_file : pr.cattitle

    charact = !pr.charact.present? ? charact_file : pr.charact

    barcode = !pr.barcode.present? ? @barcode : pr.barcode

    pr.update_attributes(desc: desc, charact: charact, image: image, brand: brand, cattitle: cattitle, barcode: barcode)
  end

  def self.open_spreadsheet(file)
    if file.is_a? String
      fyle_type = file.split('.').last
      if fyle_type == 'csv'
        Roo::CSV.new(file)
      else
        Roo::Excelx.new(file, file_warning: :ignore)
      end
    else
      case File.extname(file.original_filename)
      when '.csv' then Roo::CSV.new(file.path) # csv_options: {col_sep: ";",encoding: "windows-1251:utf-8"})
      when '.xls' then Roo::Excel.new(file.path)
      when '.xlsx' then Roo::Excelx.new(file.path)
      when '.XLS' then Roo::Excel.new(file.path)
      else raise "Unknown file type: #{file.original_filename}"
      end
    end
  end

  def self.load_by_api
    puts 'загружаем данные api al-style.kz - ' + Time.now.in_time_zone('Moscow').to_s

    articles = Product.product_api_update.nil? ? [] : Product.product_api_update.pluck(:sku).reject(&:blank?)
    count = articles.size
    offset = 0
    while count > 0
      puts 'offset - ' + offset.to_s
      search_articles = articles.slice(offset, 50).join(',')
      if search_articles.present?
        url = 'https://api.al-style.kz/api/element-info?access-token=Py8UvH0yDeHgN0KQ3KTLP2jDEtCR5ijm&article=' + search_articles + '&additional_fields=barcode,description,brand,properties,detailtext,images,weight,url'
        puts url
        RestClient.get(url) do |response, _request, _result, &block|
          case response.code
          when 200
            datas = JSON.parse(response)
            if datas.is_a?Array
              datas.each do |data|
                Product.api_update_product(data)
              end
            end
          when 422
            puts 'error 422 - не добавили клиента - '+response.to_s
            break
          when 404
            puts 'error 404 - '+response.to_s
            break
          when 503
            sleep 1
            puts 'sleep 1 error 503 - '+response.to_s
          else
            response.return!(&block)
          end
        end

        count -= 50
        offset += 50
      else
        break
      end
    end

    puts 'закончили загружаем данные api - ' + Time.now.in_time_zone('Moscow').to_s
    Product.set_cattitle
  end

  def self.api_update_product(data)
    characts_array = []
    not_use_keys = ["Не включать в прайс-лист","Дата последнего прихода","Штрихкод","Код","Базовая единица","Короткое наименование","Бренд","Полное наименование","Вес","Артикул-PartNumber","Анонс"]
    data['properties'].each do |k, v|
      characts_array.push(k + ' : ' + v.to_s) if !not_use_keys.include?(k)
    end
    characts = characts_array.join('---')
    images = data['images'].join(' ')
    api_data = {
      skubrand: data['article_pn'], 
      barcode: data['barcode'], 
      brand: data['brand'],
      desc: data['detailtext'],
      cat: data['category'],
      charact: characts,
      image: images,
      weight: data['weight'],
      url: data['url']
    }
    product = Product.find_by_sku(data['article'])
    product.update_attributes(api_data)
  end

  def self.csv_param
    puts 'Файл инсалес c параметрами на лету - ' + Time.now.in_time_zone('Moscow').to_s
    file = Rails.public_path.to_s + '/c44kz.csv'
    check = File.file?(file)
    File.delete(file) if check.present?
    file_ins = Rails.public_path.to_s + '/ins_c44kz.csv'
    check = File.file?(file_ins)
    File.delete(file_ins) if check.present?

    # создаём файл со статичными данными
    @tovs = Product.where(id: product_for_insales) # .limit(1) #where('title like ?', '%Bellelli B-bip%')
    file = "#{Rails.root}/public/c44kz.csv"
    CSV.open(file, 'w') do |writer|
      headers = ['fid', 'Артикул', 'Штрих-код', 'Название товара', 'Краткое описание', 'Полное описание', 'Цена продажи',
                 'Остаток', 'Изображения', 'Параметр: Брэнд', 'Параметр: Артикул Производителя', 'Подкатегория 1', 'Подкатегория 2', 'Подкатегория 3', 'Подкатегория 4', 'Вес', 'Цена оптовая']

      writer << headers
      @tovs.each do |pr|
        next if pr.title.nil?

        fid = pr.id
        sku = pr.sku
        barcode = pr.barcode
        title = pr.title
        sdesc = pr.sdesc
        desc = pr.desc
        price = pr.price
        optprice = pr.optprice
        quantity = pr.quantity
        image = pr.image
        brand = pr.brand
        skubrand = pr.skubrand
        cat = pr.cattitle.split('/')[0] || '' unless pr.cattitle.nil?
        cat1 = pr.cattitle.split('/')[1] || '' unless pr.cattitle.nil?
        cat2 = pr.cattitle.split('/')[2] || '' unless pr.cattitle.nil?
        cat3 = pr.cattitle.split('/')[3] || '' unless pr.cattitle.nil?
        weight = pr.weight
        writer << [fid, sku, barcode, title, sdesc, desc, price, quantity, image, brand, skubrand, cat, cat1, cat2, cat3,
                   weight, optprice]
      end
    end

    # параметры в таблице записаны в виде - "Состояние: новый --- Вид: квадратный --- Объём: 3л --- Радиус: 10м"
    # дополняем header файла названиями параметров

    vparamHeader = []
    p = @tovs.select(:charact)
    p.each do |p|
      next if p.charact.nil?

      p.charact.split('---').each do |pa|
        vparamHeader << pa.split(':')[0].strip unless pa.nil?
      end
    end
    addHeaders = vparamHeader.uniq
    # puts 'addHeaders ' + addHeaders.to_s
    # Load the original CSV file
    rows = CSV.read(file, headers: true).collect do |row|
      row.to_hash
    end

    check_property_use = Property.property_status_true.pluck(:title)
    # puts check_property_use.to_s

    # Original CSV column headers
    column_names = rows.first.keys
    # Array of the new column headers
    addHeaders.each do |addH|
      next unless check_property_use.include?(addH)

      # puts 'параметр -' + addH
      additional_column_names = ['Параметр: ' + addH]
      # Append new column name(s)
      column_names += additional_column_names
      s = CSV.generate do |csv|
        csv << column_names
        rows.each do |row|
          # Original CSV values
          values = row.values
          # Array of the new column(s) of data to be appended to row
          # 				additional_values_for_row = ['1']
          # 				values += additional_values_for_row
          csv << values
        end
      end
      File.open(file, 'w') { |file| file.write(s) }
    end
    # Overwrite csv file

    # заполняем параметры по каждому товару в файле
    new_file = Rails.public_path.to_s + '/ins_c44kz.csv'
    CSV.open(new_file, 'w') do |csv_out|
      rows = CSV.read(file, headers: true).collect do |row|
        row.to_hash
      end
      column_names = rows.first.keys
      csv_out << column_names
      CSV.foreach(file, headers: true) do |row|
        fid = row[0]
        # puts fid
        vel = Product.find_by_id(fid)
        if !vel.nil? && vel.charact.present? # Вид записи должен быть типа - "Длина рамы: 20 --- Ширина рамы: 30"
          vel.charact.split('---').each do |vp|
            key_val = vp.split(':')[0].strip unless vp.nil?
            next unless check_property_use.include?(key_val)

            key = 'Параметр: ' + key_val
            next unless key.present?

            value = vp.split(':')[1].remove('.') unless vp.split(':')[1].nil?
            row[key] = value
            # puts "здесь key -'"+key+"'-здесь value-'"+value+"'"
          end
        end
        csv_out << row
      end
    end
    puts 'Finish Файл инсалес с параметрами на лету - ' + Time.now.in_time_zone('Moscow').to_s

    # current_process = "создаём файл csv_param"
    # CaseMailer.notifier_process(current_process).deliver_now
  end

  def self.csv_param_selected(products)
    file = Rails.public_path.to_s + '/c44kz_selected.csv'
    check = File.file?(file)
    File.delete(file) if check.present?
    file_ins = Rails.public_path.to_s + '/ins_c44kz_selected.csv'
    check = File.file?(file_ins)
    File.delete(file_ins) if check.present?

    # создаём файл со статичными данными
    @tovs = Product.where(id: products).where.not(price: [nil, 0]).order(:id) # .limit(10) #where('title like ?', '%Bellelli B-bip%')
    file = "#{Rails.root}/public/c44kz_selected.csv"
    CSV.open(file, 'w') do |writer|
      headers = ['fid', 'Артикул', 'Штрихкод', 'Название товара', 'Краткое описание', 'Полное описание', 'Цена продажи',
                 'Остаток', 'Изображения', 'Параметр: Брэнд', 'Параметр: Артикул Производителя', 'Подкатегория 1', 'Подкатегория 2', 'Подкатегория 3', 'Подкатегория 4', 'Вес', 'Цена оптовая']

      writer << headers
      @tovs.each do |pr|
        next if pr.title.nil?

        fid = pr.id
        sku = pr.sku
        barcode = pr.barcode
        title = pr.title
        sdesc = pr.sdesc
        desc = pr.desc
        price = pr.price
        optprice = pr.optprice
        quantity = pr.quantity
        image = pr.image
        brand = pr.brand
        skubrand = pr.skubrand
        cat = pr.cattitle.split('/')[0] || '' unless pr.cattitle.nil?
        cat1 = pr.cattitle.split('/')[1] || '' unless pr.cattitle.nil?
        cat2 = pr.cattitle.split('/')[2] || '' unless pr.cattitle.nil?
        cat3 = pr.cattitle.split('/')[3] || '' unless pr.cattitle.nil?
        weight = pr.weight
        writer << [fid, sku, barcode, title, sdesc, desc, price, quantity, image, brand, skubrand, cat, cat1, cat2, cat3,
                   weight, optprice]
      end
    end

    # параметры в таблице записаны в виде - "Состояние: новый --- Вид: квадратный --- Объём: 3л --- Радиус: 10м"
    # дополняем header файла названиями параметров

    vparamHeader = []
    p = @tovs.select(:charact)
    p.each do |p|
      next if p.charact.nil?

      p.charact.split('---').each do |pa|
        vparamHeader << pa.split(':')[0].strip unless pa.nil?
      end
    end
    addHeaders = vparamHeader.uniq

    # Load the original CSV file
    rows = CSV.read(file, headers: true).collect do |row|
      row.to_hash
    end
    check_property_use = Property.property_status_true.pluck(:title)
    # puts check_property_use.to_s

    # Original CSV column headers
    column_names = rows.first.keys
    # Array of the new column headers
    addHeaders.each do |addH|
      next unless check_property_use.include?(addH)

      additional_column_names = ['Параметр: ' + addH]
      # Append new column name(s)
      column_names += additional_column_names
      s = CSV.generate do |csv|
        csv << column_names
        rows.each do |row|
          # Original CSV values
          values = row.values
          # Array of the new column(s) of data to be appended to row
          # 				additional_values_for_row = ['1']
          # 				values += additional_values_for_row
          csv << values
        end
      end
      File.open(file, 'w') { |file| file.write(s) }
    end
    # Overwrite csv file

    # заполняем параметры по каждому товару в файле
    new_file = Rails.public_path.to_s + '/ins_c44kz_selected.csv'
    CSV.open(new_file, 'w') do |csv_out|
      rows = CSV.read(file, headers: true).collect do |row|
        row.to_hash
      end
      column_names = rows.first.keys
      csv_out << column_names
      CSV.foreach(file, headers: true) do |row|
        fid = row[0]
        # puts fid
        vel = Product.find_by_id(fid)
        if !vel.nil? && vel.charact.present? # Вид записи должен быть типа - "Длина рамы: 20 --- Ширина рамы: 30"
          vel.charact.split('---').each do |vp|
            next unless check_property_use.include?(vp.split(':')[0].strip)

            key = 'Параметр: ' + vp.split(':')[0].strip
            value = vp.split(':')[1].remove('.') unless vp.split(':')[1].nil?
            row[key] = value
          end
        end
        csv_out << row
      end
    end
    # current_process = "создаём файл csv_param"
    # CaseMailer.notifier_process(current_process).deliver_now
  end

  def self.set_cattitle
    puts "проставляем названия категорий - #{Time.now.in_time_zone('Moscow').to_s}"
    url = 'https://api.al-style.kz/api/categories?access-token=Py8UvH0yDeHgN0KQ3KTLP2jDEtCR5ijm'
    resp = RestClient.get(url, accept: :json, content_type: 'application/json')
    cats = JSON.parse(resp)
    products = Product.ransack(cattitle_present: false, cat_present: true).result #Product.where(cattitle: [nil, ''])
    products.each do |product|

      search_cat = cats.select { |k, v| k['id'] == product.cat.to_i }
      puts search_cat.to_s
      next unless search_cat.present?

      new_name = []
      if search_cat[0]['level'] - 1 > 0
        new_name.unshift(search_cat[0]['name'])
        @level = search_cat[0]['level'] - 1
        @left = search_cat[0]['left']
        while @left > 0 && @level > 0
          # puts "left - "+@left.to_s
          a = cats.select { |k, v| k['level'] == @level && k['left'] == @left }
          if a.present?
            # puts a.to_s
            new_name.unshift(a[0]['name'])
            # добавляем название вышестоящей категории к названию этой категории
            if a[0]['level'] == 1
              break 
            else
              @level -= 1
              @left = a[0]['left'] - 1
            end
          else
            @left -= 1
          end
        end
      end
      # puts new_name.join('/')
      product.update_attributes(cattitle: new_name.join('/'))
    end
    puts "конец проставляем названия категорий - #{Time.now.in_time_zone('Moscow').to_s}"
  end

  def self.price_updates
    puts 'обновляем цены по процентам по категориям - ' + Time.now.in_time_zone('Moscow').to_s
    products = Product.all.order(:id)
    products.each do |product|
      product.update_pricepr
      product.update_pricepropt
    end
    puts 'конец обновляем цены по процентам по категориям - ' + Time.now.in_time_zone('Moscow').to_s
  end

  def self.insales_param
    puts 'start insales_param'
    vparamHeader = []
    # p = Product.all.select(:charact)
    # p.each do |p|
    #   if p.charact != nil
    #     p.charact.split('---').each do |pa|
    #       vparamHeader << pa.split(':')[0].strip if pa != nil
    #     end
    #   end
    # end
    check_property_use = Property.property_status_true.pluck(:title)
    check_property_use.each do |cpu|
      vparamHeader << cpu
    end

    values = vparamHeader.uniq
    values.each do |value|
      puts 'параметр - ' + value.to_s
      url = 'http://' + Rails.application.secrets.insales_login + ':' + Rails.application.secrets.insales_pass + '@' + Rails.application.secrets.insales_domain + '/admin/properties.json'
      data =	{
        "property":
                {
                  "title": value.to_s
                }
      }

      RestClient.post(url, data.to_json,
                      { content_type: 'application/json', accept: :json }) do |response, _request, _result, &block|
        puts response.code
        case response.code
        when 201
          sleep 0.2
          puts 'sleep 0.2-201 - сохранили'
        # 									puts response
        when 422
          puts '422'
        else
          response.return!(&block)
        end
      end
    end
    puts 'finish insales_param'
  end

  def self.kaspi_xml
    puts "Формируем kaspi_xml "+"#{Time.zone.now}"
    api_key = Rails.application.secrets.insales_login
		domain = Rails.application.secrets.insales_domain
		password = Rails.application.secrets.insales_pass
    count_url = "http://"+"#{api_key}"+":"+"#{password}"+"@"+"#{domain}"+"/admin/products/count.json"
    count = JSON.parse(RestClient.get count_url)['count']

    puts count
    page = 1
    pr_array = []
    while count > 0
      puts "page - "+page.to_s
      products_url = "http://"+"#{api_key}"+":"+"#{password}"+"@"+"#{domain}"+"/admin/products.json?per_page=100&page="+page.to_s
      products = JSON.parse(RestClient.get products_url)
      puts "products.count - "+products.count.to_s
        products.each do |p|
          p_data = {sku: p['id'], model: p['title'], brand: '', available:  p['available'], price: p['variants'][0]['base_price'], qt: p['variants'][0]['quantity']}
            pr_array.push(p_data)
            sleep 0.05
        end
      count -= 100
      page += 1
      sleep 0.10
      puts 'sleep 0.10'
    end

    xml = Nokogiri::XML::Builder.new(:encoding => 'UTF-8'){ |xml|
      xml.send(:'kaspi_catalog', :date => "#{Time.now.in_time_zone.strftime("%Y-%m-%d %H:%M")}", :xmlns => 'kaspiShopping',  :'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance", :'xsi:schemaLocation' => "kaspiShopping http://kaspi.kz/kaspishopping.xsd") {  #, :xmlns:xsi => "http://www.w3.org/2001/XMLSchema-instance", :xsi:schemaLocation => "kaspiShopping http://kaspi.kz/kaspishopping.xsd"
        xml.offers {
          xml.company 'c44_kz'
          xml.merchantid '412031'
        pr_array.each do |pr|
          # puts pr.to_s
          xml.send(:'offer', :sku => pr[:sku]) {
            xml.model pr[:model]
            xml.brand pr[:brand]
            xml.send(:'availabilities') {
              xml.availability(:available => pr[:available] == true ? 'yes' : 'no', :storeId => "Папанина 53д" )
            }
            xml.price pr[:price]
          }
        end
      }
      }
    }

    File.open("#{Rails.public_path}"+"/"+"kaspi.xml", "w")	{|f| f.write(xml.to_xml)}
    puts "Сформировали kaspi_xml "+"#{Time.zone.now}"
  end

  # def vstrade_url_normalize
  #   if !self.url.nil? && self.url.include?('vstrade')
  #     self.url = self.url.include?('https') ? self.url.gsub('https://vstrade.kz','https://www.vstrade.kz') : self.url.gsub('http://vstrade.kz','https://www.vstrade.kz')
  #   end
  # end
  def update_pricepr
    cost_price = self.costprice ||= 0
    s_cat_pricepr = self.cattitle.present? ? Product.ransack(cattitle_eq: self.cattitle, pricepr_not_nil: true).result.pluck(:pricepr).uniq.first : nil
    s_pricepr = self.pricepr.present? ? self.pricepr.to_f : s_cat_pricepr
    pricepr = s_pricepr.present? ? s_pricepr : nil
    new_price = (cost_price + pricepr.to_f / 100 * cost_price).round(-1)
    self.price = new_price
  end

  def update_pricepropt
    cost_price = self.costprice ||= 0
    s_cat_pricepropt = self.cattitle.present? ? Product.ransack(cattitle_eq: self.cattitle, pricepropt_not_nil: true).result.pluck(:pricepropt).uniq.first : nil
    s_pricepropt = self.pricepropt.present? ? self.pricepropt.to_f : s_cat_pricepropt
    pricepropt = s_pricepropt.present? ? s_pricepropt : nil
    new_optprice = (cost_price + pricepropt.to_f / 100 * cost_price).round(-1)
    self.optprice = new_optprice
  end

  def update_quantity
    q1 = self.quantity1 ||= 0
    q2 = self.quantity2 ||= 0
    self.quantity = q1 + q2
  end

	def normalize_data_white_space
	  self.attributes.each do |key, value|
	  	self[key] = value.squish if value.respond_to?("squish")
	  end
	end


end
