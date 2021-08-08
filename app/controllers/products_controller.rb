class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  # GET /products
  # GET /products.json
  def index
    if params[:q].present?
      new_q = {}
      params[:q].each do |k,v|
        if k == 'quantity_in'
          puts v
          value = v == "0" ? 0 : Array(1..3500)
          new_q[k] = value
        else
          new_q[k] = v
        end
      end
      # puts new_q
    end

    @search = Product.ransack(new_q)
    @search.sorts = 'id desc' if @search.sorts.empty?
    @products = @search.result.paginate(page: params[:page], per_page: 100)
    # puts @products.count
    if params['otchet_type'] == 'selected'
      Product.csv_param_selected( params['selected_products'])
      new_file = "#{Rails.public_path}"+'/ins_c44kz_selected.csv'
      send_file new_file, :disposition => 'attachment'
    end

  end

  # GET /products/1
  # GET /products/1.json
  def show
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products
  # POST /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to @product, notice: 'Product was successfully created.' }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1
  # PATCH/PUT /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to @product, notice: 'Product was successfully updated.' }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1
  # DELETE /products/1.json
  def destroy
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_url, notice: 'Product was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def get_file
    if Rails.env.development?
      Product.get_file
    else
      Product.delay.get_file
    end
    flash[:notice] = 'Задача обновления остатков запущена'
    redirect_to products_path
  end

  def get_file_vstrade
    if Rails.env.development?
      Product.get_file_vstrade
    else
      Product.delay.get_file_vstrade
    end
    flash[:notice] = 'Задача обновления остатков Поставщик 2 запущена'
    redirect_to products_path
  end

  def edit_multiple
    puts params[:product_ids].present?
    if params[:product_ids].present?
			@products = Product.find(params[:product_ids])
			respond_to do |format|
			  format.js
			end
		else
			redirect_to products_url
		end
  end

  def update_multiple
    @products = Product.find(params[:product_ids])
		@products.each do |pr|
			attr = params[:product_attr]
			attr.each do |key,value|
				if key.to_s == 'picture'
					# if value.to_i == 1
					# product_id = pr.id
					#puts product_id
					# Product.productimage(product_id)
					# end
				end
				if key.to_s != 'picture'
					if !value.blank?
					pr.update_attributes(key => value)
            if key.to_s == 'pricepr'
              Product.update_pricepr(pr.id)
            end
            if key.to_s == 'pricepropt'
              Product.update_pricepropt(pr.id)
            end
					end
				end
			end
		end
		flash[:notice] = 'Данные обновлены'
		redirect_back(fallback_location: index)
  end

  def delete_selected
    @products = Product.find(params[:ids])
		@products.each do |product|
		    product.destroy
		end
		respond_to do |format|
		  format.html { redirect_to products_url, notice: 'Товары удалёны' }
		  format.json { render json: {:status => "ok", :message => "Товары удалёны"} }
		end
  end

  def load_by_api
    if Rails.env.development?
      Product.load_by_api
    else
      Product.delay.load_by_api
    end
    flash[:notice] = 'Задача обновления по api запущена'
    redirect_to products_path
  end

  def csv_param
    if Rails.env.development?
      Product.csv_param
    else
      Product.delay.csv_param
    end
    flash[:notice] = "Запустили"
    redirect_to products_path
  end

  def set_cattitle
    if Rails.env.development?
      Product.set_cattitle
    else
      Product.delay.set_cattitle
    end
    flash[:notice] = "Запустили"
    redirect_to products_path
  end

  def insales_param
    if Rails.env.development?
      Product.insales_param
    else
      Product.delay.insales_param
    end
    flash[:notice] = 'Задача обновления параметров по api insales запущена'
    redirect_to products_path
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(:sku, :sku2, :skubrand, :barcode, :brand, :title, :sdesc, :desc, :cat, :charact, :costprice, :costprice2, :price, :quantity, :quantity1, :quantity2, :image, :weight, :url, :cattitle, :pricepr, :otchet_type, :pricepropt, :optprice)
    end
end
