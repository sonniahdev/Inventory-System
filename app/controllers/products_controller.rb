# app/controllers/products_controller.rb
require "csv"
require "roo"

class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :update_stock, :confirm_delete]
  
  def index
    if params[:search].present?
      @products = Product.where("name ILIKE ?", "%#{params[:search]}%")
    else
      @products = Product.all
    end
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params.except(:image))
    if params[:product][:image].present?
      @product.image.attach(params[:product][:image])
    end
    if @product.save
      respond_to do |format|
        format.html { redirect_to products_path, notice: "Product created." }
        format.turbo_stream
      end
    else
      render :new
    end
  end

  def edit
  end

  def update
    if params[:product][:image].present?
      @product.image.attach(params[:product][:image])
    end
    if @product.update(product_params.except(:image))
      respond_to do |format|
        format.html { redirect_to products_path, notice: "Product updated." }
        format.turbo_stream
      end
    else
      render :edit
    end
  end

  def destroy
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_path, notice: "Product deleted." }
      format.turbo_stream
    end
  end

  def export
    @products = Product.all
    respond_to do |format|
      format.csv { send_data @products.to_csv, filename: "products-#{Date.today}.csv" }
    end
  end

  def confirm_delete
    # @product is already set by before_action
  end

  # New method for bulk import page
  def bulk_import
    @import_results = session.delete(:import_results) # Get and clear results from session
  end

  # New method for processing bulk import
  def process_bulk_import
    unless params[:file].present?
      redirect_to bulk_import_products_path, alert: "Please select a file to upload."
      return
    end

    file = params[:file]
    
    # Validate file type
    unless file.content_type.in?(['application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'text/csv'])
      redirect_to bulk_import_products_path, alert: "Please upload an Excel (.xlsx, .xls) or CSV file."
      return
    end

    begin
      results = import_products_from_file(file)
      session[:import_results] = results
      redirect_to bulk_import_products_path, notice: "Import completed! #{results[:success_count]} products imported successfully."
    rescue => e
      redirect_to bulk_import_products_path, alert: "Error processing file: #{e.message}"
    end
  end

  # New method for downloading template
  def download_template
    template_data = generate_template_data
    respond_to do |format|
      format.csv { 
        send_data template_data, 
        filename: "product_import_template_#{Date.today}.csv",
        type: 'text/csv'
      }
    end
  end

  def update_stock
    # Get the amount from the form
    amount = params[:product][:amount].to_i
    
    # Determine action based on which submit button was clicked
    # Rails sends the button name and value when using name: 'action'
    action = nil
    if params[:action_name] == 'increase'
      action = :increase
    elsif params[:action_name] == 'decrease'
      action = :decrease
    # Fallback: check if 'increase' or 'decrease' exists in params
    elsif params.key?('increase')
      action = :increase
    elsif params.key?('decrease')
      action = :decrease
    # Another fallback: check commit value
    elsif params[:commit] == 'Increase'
      action = :increase
    elsif params[:commit] == 'Decrease'
      action = :decrease
    end
    
    # Debug: Rails.logger.debug "Params: #{params.inspect}"
    # Debug: Rails.logger.debug "Action determined: #{action}"
    
    if action.nil?
      redirect_to products_path, alert: "Could not determine action."
      return
    end
    
    # Validate inputs
    if amount <= 0
      redirect_to products_path, alert: "Amount must be greater than 0."
      return
    end
    
    if action == :decrease && @product.quantity < amount
      redirect_to products_path, alert: "Cannot decrease stock below 0. Current stock: #{@product.quantity}"
      return
    end
    
    # Update the stock
    if @product.update_stock(amount, action)
      @product.reload
      respond_to do |format|
        format.html { redirect_to products_path, notice: "Stock updated successfully." }
        format.turbo_stream # This will render update_stock.turbo_stream.erb
      end
    else
      redirect_to products_path, alert: "Failed to update stock."
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :quantity, :image, :amount)
  end

  def import_products_from_file(file)
    results = {
      success_count: 0,
      error_count: 0,
      errors: []
    }

    # Determine file type and parse accordingly
    if file.content_type == 'text/csv'
      csv_data = file.read
      rows = CSV.parse(csv_data, headers: true)
    else
      # Handle Excel files
      spreadsheet = Roo::Spreadsheet.open(file.path)
      rows = spreadsheet.parse(headers: true)
    end

    rows.each_with_index do |row, index|
      next if row.blank? || row.to_h.values.all?(&:blank?)
      
      begin
        product_data = {
          name: row['name'] || row['Name'] || row['NAME'],
          description: row['description'] || row['Description'] || row['DESCRIPTION'],
          price: row['price'] || row['Price'] || row['PRICE'],
          quantity: row['quantity'] || row['Quantity'] || row['QUANTITY']
        }

        # Validate required fields
        if product_data[:name].blank?
          results[:errors] << "Row #{index + 2}: Name is required"
          results[:error_count] += 1
          next
        end

        if product_data[:price].blank? || product_data[:price].to_f < 0
          results[:errors] << "Row #{index + 2}: Valid price is required"
          results[:error_count] += 1
          next
        end

        if product_data[:quantity].blank? || product_data[:quantity].to_i < 0
          results[:errors] << "Row #{index + 2}: Valid quantity is required"
          results[:error_count] += 1
          next
        end

        # Create the product
        product = Product.new(product_data)
        
        # Handle image if image_url is provided
        image_url = row['image_url'] || row['Image URL'] || row['IMAGE_URL']
        if image_url.present?
          begin
            product.attach_image_from_url(image_url)
          rescue => e
            results[:errors] << "Row #{index + 2}: Could not attach image from URL - #{e.message}"
          end
        end

        if product.save
          results[:success_count] += 1
        else
          results[:errors] << "Row #{index + 2}: #{product.errors.full_messages.join(', ')}"
          results[:error_count] += 1
        end

      rescue => e
        results[:errors] << "Row #{index + 2}: #{e.message}"
        results[:error_count] += 1
      end
    end

    results
  end

  def generate_template_data
    headers = ['name', 'description', 'price', 'quantity', 'image_url']
    sample_data = [
      ['Sample Product 1', 'This is a sample product description', '29.99', '100', 'https://example.com/image1.jpg'],
      ['Sample Product 2', 'Another sample product', '15.50', '50', 'https://example.com/image2.jpg'],
      ['Sample Product 3', 'Third sample product', '45.00', '25', '']
    ]

    CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each { |row| csv << row }
    end
  end
end