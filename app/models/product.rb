class Product < ApplicationRecord
  require 'open-uri'
  scope :product_all_size, -> { order(:id).size }
  scope :product_qt_not_null, -> { where('quantity > 0') }
  scope :product_qt_not_null_size, -> { where('quantity > 0').size }
  scope :product_cat, -> { order('cattitle ASC').select(:cattitle).uniq }
  scope :product_barcode_nil, -> { where(barcode: [nil, '']).order(:id) }
  scope :product_image_nil, -> { where(image: [nil, '']).order(:id) }
  scope :product_api_update, -> { product_barcode_nil + product_image_nil }
  scope :product_for_insales, -> { where('quantity > 0').where.not(price: [nil, 0]).pluck(:id) }
  validates :sku, uniqueness: true

  #Product.select(:cattitle).uniq.order('cattitle ASC')

  def self.get_file
    puts 'загружаем файл с остатками - '+Time.now.in_time_zone('Moscow').to_s

    	    url = "https://order.al-style.kz/export/Al-Style_price.xlsx"

    	    download = RestClient::Request.execute(method: :get, url: url, raw_response: true)
    	    unless download.code == 200
    	      sleep 0.5
    	      puts 'sleep 0.5'
    	    else
    	      download_path = "#{Rails.public_path}"+'/ost.xlsx' #+Date.today.in_time_zone('Moscow').strftime("%d_%m_%Y").to_s+'.xlsx'
    		    IO.copy_stream(download.file.path, download_path)
    	      Product.open_file(download_path)
    	    end

      # begin
      # RestClient.get( url, raw_response: true) { |response, request, result, &block|
      #   case response.code
      #   when 200
      #     puts 'code 200 - ok - обновили содержание'
      #     puts response.file.size
      #   when 422
      #     puts response
      #     break #raise SomeCustomExceptionIfYouWant
      #   when 404
      #     puts ' error 404'
      #     puts 'sleep 0.5'
      #     sleep 0.5
      #     redo
      #   else
      #     response.return!(&block)
      #   end
      #   }
      #
      # end

      # loop do
      #   download = RestClient::Request.execute(method: :get, url: url, raw_response: true)
      #   if download.code == 200
      #     download_path = "#{Rails.public_path}"+'/ost.xlsx' #+Date.today.in_time_zone('Moscow').strftime("%d_%m_%Y").to_s+'.xlsx'
  		#     IO.copy_stream(download.file.path, download_path)
  	  #     Product.open_file(download_path)
      #     break       # this will cause execution to exit the loop
      #   end
      #   if download.code == 404
      #     sleep 0.5
  	  #     puts 'sleep 0.5'
      #   end
      # end

    puts 'закончили загружаем файл с остатками - '+Time.now.in_time_zone('Moscow').to_s
  end

  def self.get_file_vstrade
    puts 'загружаем файл vstrade с остатками - '+Time.now.in_time_zone('Moscow').to_s
    file = "#{Rails.public_path}"+'/vstrade_full.html'
		check = File.file?(file)
		if check.present?
			File.delete(file)
		end

    a = Mechanize.new
		a.get("https://www.vstrade.kz/")
		form = a.page.form_with(:action => "/index.php?login=yes")
		form['LoginForm[username]'] = "info@c44.kz"
		form['LoginForm[password]'] = "87654321"
		form.submit
		page = a.get("https://www.vstrade.kz/")
		url = "http://vstrade.kz/t/spec-price.php"

    download = RestClient::Request.execute(method: :get, url: url, raw_response: true)
    unless download.code == 200
      sleep 0.5
      puts 'sleep 0.5'
    else
  		download_path = "#{Rails.public_path}"+"/vstrade_full.html"
  		IO.copy_stream(download.file.path, download_path)
      Product.update_all(quantity2: 0)
      Product.open_file_vstrade
    end

    puts 'закончили загружаем файл vstrade с остатками - '+Time.now.in_time_zone('Moscow').to_s
  end

  def self.open_file(file)
    puts 'обновляем из файла - '+Time.now.in_time_zone('Moscow').to_s
		spreadsheet = open_spreadsheet(file)
		header = spreadsheet.row(1)
    if Rails.env.development?
      last_number = 120
    else
      last_number = spreadsheet.last_row.to_i
    end
    (2..last_number).each do |i|
			row = Hash[[header, spreadsheet.row(i)].transpose]

			sku = row["Код"]
			skubrand = row["Артикул"]
			title = row["Наименование"]
			sdesc = row["Полное наименование"]
			costprice = row["Цена дил."]
			price = row["Цена роз."]
      quantity1 = row["Остаток"].to_s.gsub('>','') if row["Остаток"] != nil
      if title.present?
  			product = Product.find_by_sku(sku)
  			if product.present?
  				product.update_attributes(skubrand: skubrand, title: title, sdesc: sdesc, costprice: costprice, quantity1: quantity1)
  			else
  				Product.create(sku: sku, skubrand: skubrand, title: title, sdesc: sdesc, costprice: costprice, price: price, quantity1: quantity1)
  			end
      end
    end

		puts 'конец обновляем из файла - '+Time.now.in_time_zone('Moscow').to_s
    Product.update_quantity
    Product.price_updates
  end

  def self.open_file_vstrade
    puts 'обновляем из файла vstrade - '+Time.now.in_time_zone('Moscow').to_s
    file_url = "#{Rails.public_path}"+"/vstrade_full.html"
    doc = Nokogiri::HTML(open(file_url, :read_timeout => 50))
    table = doc.css('table')[1]
    products_file = table.css('tr')
    products_file.each_with_index do |prf, index|
      if !prf.css('td')[1].nil? and prf.css('td')[1] != 'Наименование'
  			sku2 = prf.css('td')[0].text
        sku = sku2+"-2"
  			skubrand = prf.css('td')[2].text
  			title_file = prf.css('td')[1]
        title = title_file.text
        url = title_file.css('a')[0]['href'].gsub('http','https')
  			costprice2 = prf.css('td')[3].text
        quantity2 = prf.css('td')[4].text
        if sku.present?
    			product = Product.find_by_sku2(sku2)
    			if product.present?
            if product.costprice.present? and product.sku != sku
              costprice = product.costprice
            else
              costprice = costprice2
            end
    				product.update_attributes(costprice: costprice, costprice2: costprice2, quantity2: quantity2)
    			else
    				Product.create(sku: sku, sku2: sku2, skubrand: skubrand, title: title, costprice: costprice2, costprice2: costprice2, quantity2: quantity2, url: url)
    			end
        end
      end

      break if index == 30 and Rails.env.development?
    end

		puts 'конец обновляем из файла vstrade - '+Time.now.in_time_zone('Moscow').to_s
    Product.vstrade_get_image_desc
    Product.update_quantity
    Product.price_updates
  end

  def self.vstrade_get_image_desc
    puts 'обновляем vstrade_get_image_desc - '+Time.now.in_time_zone('Moscow').to_s

    products = Product.where.not(sku2: [nil, '']).where(image: [nil, ''])
    products.each do |pr|
      puts "pr id - "+pr.id.to_s
      pr_url = Addressable::URI.parse(pr.url).normalize.to_s
      RestClient.get( pr_url) { |response, request, result, &block|
          case response.code
          when 200
            Product.vstrade_get_image_desc_by_product(pr.id)
          when 422
            puts "error 422 - обновляем vstrade_get_image_desc"
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
          }
    end

    puts 'конец обновляем vstrade_get_image_desc - '+Time.now.in_time_zone('Moscow').to_s
  end

  def self.vstrade_get_image_desc_by_product(pr_id)
    pr = Product.find_by_id(pr_id)
    pr_doc = Nokogiri::HTML(open(Addressable::URI.parse(pr.url).normalize  , :read_timeout => 50), nil, Encoding::UTF_8.to_s)
    # pr_doc = Nokogiri::HTML(open(Addressable::URI.parse(url).normalize  , :read_timeout => 50), nil, Encoding::UTF_8.to_s)
    weight = pr_doc.css('.weight').text.gsub('Вес товара: ','').gsub('г','')
    pict_thumbs = pr_doc.css('.thumbnails-slidee .thumb img')
    picts = []
    if pict_thumbs.size > 0
      pict_thumbs.each do |p|
        if !p['data-big-src'].include?('gif')
          pl = "https://www.vstrade.kz"+p['data-big-src'].to_s.gsub('resizer2/1','resizer2/15')
          picts.push(pl)
        end
      end
    else
      if pr_doc.css('.product-photo img').present? and !pr_doc.css('.product-photo img')[0]['data-big-src'].include?('gif')
        pl = "https://www.vstrade.kz"+pr_doc.css('.product-photo img')[0]['data-big-src'].to_s.gsub('resizer2/1','resizer2/15')
      else
        pl = ''
      end
      picts.push(pl)
    end
    pict_file = picts.uniq.join(' ')
    proper = []
    proper_file = pr_doc.css('.tech-info-block .expand-content').inner_html.gsub('</dt>',':').gsub('</dd>',' --- ').gsub('<dt>','').gsub('<dd>','')
    clear_proper = Nokogiri::HTML(proper_file)
    properties = clear_proper.text
    properties.split('---').each do |prop|
      if prop.include?(':') and prop.include?('Полное описание')
        @desc = prop.gsub('Полное описание:','').squish
      end
      if prop.include?(':') and prop.include?('Штрих код')
        @barcode = prop.gsub('Штрих код:','').squish
      end
      if prop.include?(':') and !prop.include?('Полное описание') and !prop.include?('Бренд') and !prop.include?('Штрих код')
        proper.push(prop.squish)
      end
    end
    charact_file = proper.join(' --- ')

    cat_array = []
    pr_doc.css('.breadcrumbs-content a span').each do |c|
      if c.text == 'Каталог'
        cat_array.push('Vstrade')
      else
        cat_array.push(c.text)
      end
    end

    cattitle_file = cat_array.join('/')
    if !pr.desc.present?
      desc = @desc
    else
      desc = pr.desc
    end

    brand_file = pr_doc.css("meta[itemprop=brand]")[0]['content'] if pr_doc.css("meta[itemprop=brand]").present?
    if !pr.brand.present?
      brand = brand_file
    else
      brand = pr.brand
    end

    if !pr.image.present?
      image = pict_file
    else
      image = pr.image
    end

    if !pr.cattitle.present?
      cattitle = cattitle_file
    else
      cattitle = pr.cattitle
    end

    if !pr.charact.present?
      charact = charact_file
    else
      charact = pr.charact
    end

    if !pr.barcode.present?
      barcode = @barcode
    else
      barcode = pr.barcode
    end

    pr.update_attributes(desc: desc, charact: charact, image: image, brand: brand, cattitle: cattitle, barcode: barcode )
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
    	    when ".csv" then Roo::CSV.new(file.path)#csv_options: {col_sep: ";",encoding: "windows-1251:utf-8"})
    	    when ".xls" then Roo::Excel.new(file.path)
    	    when ".xlsx" then Roo::Excelx.new(file.path)
    	    when ".XLS" then Roo::Excel.new(file.path)
    	    else raise "Unknown file type: #{file.original_filename}"
        end
	    end
	end

  def self.load_by_api
    puts 'загружаем данные api - '+Time.now.in_time_zone('Moscow').to_s

    count = Product.product_api_update.size
    offset = 0
    while count > 0
      puts "offset - "+offset.to_s
      products = Product.product_api_update.slice("#{offset}".to_i, 50) #.limit(50).offset("#{offset}")
      articles = products.pluck(:sku).join(',') || ''
      # puts articles
      if articles.present? and articles != ''
      url = "https://api.al-style.kz/api/element-info?access-token=Py8UvH0yDeHgN0KQ3KTLP2jDEtCR5ijm&article="+articles+"&additional_fields=barcode,description,brand,properties,detailtext,images,weight,url"
      puts url
      RestClient.get( url ) { |response, request, result, &block|
          case response.code
          when 200
            products = JSON.parse(response)
            products.each do |pr|
              Product.api_update_product(pr)
            end
          when 422
            puts "error 422 - не добавили клиента"
            puts response
            break
          when 404
            puts 'error 404'
            break
          when 503
            sleep 1
            puts 'sleep 1 error 503'
          else
            response.return!(&block)
          end
          }

      count = count - 50
  		offset = offset + 50
  		# sleep 0.1
  		# puts 'sleep 0.1'
      else
        break
      end

		end

    puts 'закончили загружаем данные api - '+Time.now.in_time_zone('Moscow').to_s
    Product.set_cattitle
  end

  def self.api_update_product(data)
    # data = JSON.parse(pr_info)
    product = Product.find_by_sku(data['article'])
    characts_array = []
    data['properties'].each do |k,v|
      if k != 'Не включать в прайс-лист' and k != 'Дата последнего прихода' and k != 'Штрихкод' and k != 'Код' and k != 'Базовая единица' and k != 'Короткое наименование' and k != 'Бренд' and k != 'Полное наименование' and k != 'Вес' and k != 'Артикул-PartNumber' and k != 'Анонс'
        characts_array.push(k+' : '+v.to_s)
      end
    end
    characts = characts_array.join('---')
    images = data['images'].join(' ')
    product.update_attributes(skubrand: data['article_pn'], barcode: data['barcode'], brand: data['brand'], desc: data['detailtext'], cat: data['category'], charact: characts, image: images, weight: data['weight'], url: data['url'])
  end

  def self.csv_param
	  puts "Файл инсалес c параметрами на лету - "+Time.now.in_time_zone('Moscow').to_s
		file = "#{Rails.public_path}"+'/c44kz.csv'
		check = File.file?(file)
		if check.present?
			File.delete(file)
		end
		file_ins = "#{Rails.public_path}"+'/ins_c44kz.csv'
		check = File.file?(file_ins)
		if check.present?
			File.delete(file_ins)
		end

		#создаём файл со статичными данными
		@tovs = Product.where(id: product_for_insales)#.limit(1) #where('title like ?', '%Bellelli B-bip%')
		file = "#{Rails.root}/public/c44kz.csv"
		CSV.open( file, 'w') do |writer|
		headers = ['fid','Артикул', 'Штрих-код', 'Название товара', 'Краткое описание', 'Полное описание', 'Цена продажи', 'Остаток', 'Изображения', 'Параметр: Брэнд', 'Параметр: Артикул Производителя', 'Подкатегория 1', 'Подкатегория 2', 'Подкатегория 3', 'Подкатегория 4', 'Вес' ]

		writer << headers
		@tovs.each do |pr|
			if pr.title != nil
				fid = pr.id
				sku = pr.sku
        barcode = pr.barcode
        title = pr.title
        sdesc = pr.sdesc
        desc = pr.desc
        price = pr.price
        quantity = pr.quantity
				image = pr.image
        brand = pr.brand
        skubrand = pr.skubrand
				cat = pr.cattitle.split('/')[0] || '' if pr.cattitle != nil
				cat1 = pr.cattitle.split('/')[1] || '' if pr.cattitle != nil
				cat2 = pr.cattitle.split('/')[2] || '' if pr.cattitle != nil
				cat3 = pr.cattitle.split('/')[3] || '' if pr.cattitle != nil
        weight = pr.weight
				writer << [fid, sku, barcode, title, sdesc, desc, price, quantity, image, brand, skubrand, cat, cat1, cat2, cat3, weight ]
				end
			end
		end #CSV.open

		#параметры в таблице записаны в виде - "Состояние: новый --- Вид: квадратный --- Объём: 3л --- Радиус: 10м"
		# дополняем header файла названиями параметров

		vparamHeader = []
		p = @tovs.select(:charact)
		p.each do |p|
			if p.charact != nil
				p.charact.split('---').each do |pa|
					vparamHeader << pa.split(':')[0].strip if pa != nil
				end
			end
		end
		addHeaders = vparamHeader.uniq
    puts "addHeaders "+addHeaders.to_s
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
      if check_property_use.include?(addH)
        puts "параметр -"+addH
    		additional_column_names = ['Параметр: '+addH]
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
		end
		# Overwrite csv file

		# заполняем параметры по каждому товару в файле
		new_file = "#{Rails.public_path}"+'/ins_c44kz.csv'
		CSV.open(new_file, "w") do |csv_out|
			rows = CSV.read(file, headers: true).collect do |row|
				row.to_hash
			end
			column_names = rows.first.keys
			csv_out << column_names
			CSV.foreach(file, headers: true ) do |row|
			fid = row[0]
      # puts fid
			vel = Product.find_by_id(fid)
				if vel != nil
# 				puts vel.id
					if vel.charact.present? # Вид записи должен быть типа - "Длина рамы: 20 --- Ширина рамы: 30"
  					vel.charact.split('---').each do |vp|
              key_val = vp.split(':')[0].strip if vp != nil
              if check_property_use.include?(key_val)
  						key = 'Параметр: '+key_val
                if key.present?
      						value = vp.split(':')[1].remove('.') if vp.split(':')[1] !=nil
      						row[key] = value
                  # puts "здесь key -'"+key+"'-здесь value-'"+value+"'"
                end
              end
  					end
					end
				end
			csv_out << row
			end
		end
	puts "Finish Файл инсалес с параметрами на лету - "+Time.now.in_time_zone('Moscow').to_s

	# current_process = "создаём файл csv_param"
	# CaseMailer.notifier_process(current_process).deliver_now
	end

  def self.csv_param_selected(products)
		file = "#{Rails.public_path}"+'/c44kz_selected.csv'
		check = File.file?(file)
		if check.present?
			File.delete(file)
		end
		file_ins = "#{Rails.public_path}"+'/ins_c44kz_selected.csv'
		check = File.file?(file_ins)
		if check.present?
			File.delete(file_ins)
		end

		#создаём файл со статичными данными
		@tovs = Product.where(id: products).where.not(price: [nil, 0]).order(:id)#.limit(10) #where('title like ?', '%Bellelli B-bip%')
		file = "#{Rails.root}/public/c44kz_selected.csv"
		CSV.open( file, 'w') do |writer|
		headers = ['fid','Артикул', 'Штрихкод', 'Название товара', 'Краткое описание', 'Полное описание', 'Цена продажи', 'Остаток', 'Изображения', 'Параметр: Брэнд', 'Параметр: Артикул Производителя', 'Подкатегория 1', 'Подкатегория 2', 'Подкатегория 3', 'Подкатегория 4', 'Вес' ]

		writer << headers
		@tovs.each do |pr|
			if pr.title != nil
				fid = pr.id
				sku = pr.sku
        barcode = pr.barcode
        title = pr.title
        sdesc = pr.sdesc
        desc = pr.desc
        price = pr.price
        quantity = pr.quantity
				image = pr.image
        brand = pr.brand
        skubrand = pr.skubrand
				cat = pr.cattitle.split('/')[0] || '' if pr.cattitle != nil
				cat1 = pr.cattitle.split('/')[1] || '' if pr.cattitle != nil
				cat2 = pr.cattitle.split('/')[2] || '' if pr.cattitle != nil
				cat3 = pr.cattitle.split('/')[3] || '' if pr.cattitle != nil
        weight = pr.weight
				writer << [fid, sku, barcode, title, sdesc, desc, price, quantity, image, brand, skubrand, cat, cat1, cat2, cat3, weight ]
				end
			end
		end #CSV.open

		#параметры в таблице записаны в виде - "Состояние: новый --- Вид: квадратный --- Объём: 3л --- Радиус: 10м"
		# дополняем header файла названиями параметров

		vparamHeader = []
		p = @tovs.select(:charact)
		p.each do |p|
			if p.charact != nil
				p.charact.split('---').each do |pa|
					vparamHeader << pa.split(':')[0].strip if pa != nil
				end
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
      if check_property_use.include?(addH)
    		additional_column_names = ['Параметр: '+addH]
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
		end
		# Overwrite csv file

		# заполняем параметры по каждому товару в файле
		new_file = "#{Rails.public_path}"+'/ins_c44kz_selected.csv'
		CSV.open(new_file, "w") do |csv_out|
			rows = CSV.read(file, headers: true).collect do |row|
				row.to_hash
			end
			column_names = rows.first.keys
			csv_out << column_names
			CSV.foreach(file, headers: true ) do |row|
			fid = row[0]
      # puts fid
			vel = Product.find_by_id(fid)
				if vel != nil
# 				puts vel.id
					if vel.charact.present? # Вид записи должен быть типа - "Длина рамы: 20 --- Ширина рамы: 30"
					vel.charact.split('---').each do |vp|
						key = 'Параметр: '+vp.split(':')[0].strip
						value = vp.split(':')[1].remove('.') if vp.split(':')[1] !=nil
						row[key] = value
					end
					end
				end
			csv_out << row
			end
		end
	# current_process = "создаём файл csv_param"
	# CaseMailer.notifier_process(current_process).deliver_now
	end

  def self.set_cattitle
    puts 'проставляем названия категорий - '+Time.now.in_time_zone('Moscow').to_s
    url = "https://api.al-style.kz/api/categories?access-token=Py8UvH0yDeHgN0KQ3KTLP2jDEtCR5ijm"
		resp = RestClient.get(url, :accept => :json, :content_type => "application/json")
		cats = JSON.parse(resp)
		c_a_o_h = []
		cats.each do |cat|
			c_a_o_h.push(cat)
		end
		puts c_a_o_h.to_s
		products = Product.where(cattitle: [nil, ''])
    products.each do |product|
      @cat_id = product.cat.to_i
      puts '@cat_id - '+@cat_id.to_s
      puts @cat_id.nil?
      if @cat_id != 0 and @cat_id != nil
  		search_cat = c_a_o_h.select{|k,v| k["id"] == @cat_id }
  		puts search_cat.to_s
    		if search_cat.present?
      		new_name = []
      		if search_cat[0]['level'] - 1 > 0
      		new_name.unshift(search_cat[0]['name'])
      		@level = search_cat[0]['level'] - 1
      		@left = search_cat[0]["left"]
      		while @left > 0 && @level > 0
      			# puts "left - "+@left.to_s
      			a = c_a_o_h.select{|k,v| k["level"] == @level && k['left'] == @left }
      			if a.present?
      				# puts a.to_s
      				new_name.unshift(a[0]['name'])
      			# добавляем название вышестоящей категории к названию этой категории
      				if a[0]['level'] == 1
      					break
      				else
      					@level = @level - 1
      					@left = a[0]['left'] - 1
      				end
      			else
      				@left = @left - 1
      			end
      		end
      		end
      		# puts new_name.join('/')
      		product.update_attributes(cattitle: new_name.join('/'))
    		end
      end
    end
    puts 'конец проставляем названия категорий - '+Time.now.in_time_zone('Moscow').to_s
  end

  def self.price_updates
    puts 'обновляем цены по процентам по категориям - '+Time.now.in_time_zone('Moscow').to_s
    products = Product.all.order(:id)
    products.each do |product|
      Product.update_pricepr(product.id)
    end
    puts 'конец обновляем цены по процентам по категориям - '+Time.now.in_time_zone('Moscow').to_s
  end

  def self.update_pricepr(pr_id)
    product = Product.find_by_id(pr_id)
    cost_price = product.costprice ||= 0
    if product.pricepr.present?
      new_price = (cost_price + product.pricepr.to_f/100*cost_price).round(-1)
      product.update_attributes(price: new_price)
    else
      if product.cattitle.present?
        search_product = Product.where(cattitle: product.cattitle).where.not(pricepr: [nil]).first
        if search_product.present?
          product.update_attributes(pricepr: search_product.pricepr)
          new_price = (cost_price + search_product.pricepr.to_f/100*cost_price).round(-1)
          product.update_attributes(price: new_price)
        end
      end
    end
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
      puts "параметр - "+"#{value}"
      url = "http://"+Rails.application.secrets.insales_login+":"+Rails.application.secrets.insales_pass+"@"+Rails.application.secrets.insales_domain+"/admin/properties.json"
        data = 	{
            "property":
                  {
                "title": "#{value}"
                  }
              }

        RestClient.post( url, data.to_json, {:content_type => 'application/json', accept: :json}) { |response, request, result, &block|
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
                }
    end
    puts 'finish insales_param'
  end

  def self.update_quantity
    products = Product.all
    products.each do |pr|
      q1 = pr.quantity1 ||= 0
      q2 = pr.quantity2 ||= 0
      pr.quantity = q1 + q2
      pr.save
    end
  end

end
