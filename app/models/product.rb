# app/models/product.rb
require "csv"
require "open-uri"

class Product < ApplicationRecord
  # Active Storage attachment for images
  has_one_attached :image

  # Validations
  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0, message: "must be greater than or equal to 0" }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0, message: "must be a non-negative integer" }

  # Method to update stock levels
  def update_stock(amount, action)
    case action.to_sym
    when :increase
      self.update(quantity: self.quantity + amount)
    when :decrease
      if self.quantity >= amount
        self.update(quantity: self.quantity - amount)
      else
        false
      end
    else
      false
    end
  end

  # Define the low stock threshold
  def low_stock_threshold
    10
  end

  # Check if the product is at or below the low stock threshold
  def low_stock?
    quantity <= low_stock_threshold
  end

  # Method to attach image from URL
  def attach_image_from_url(url)
    return if url.blank?
    
    begin
      # Download the image
      downloaded_image = URI.open(url)
      
      # Extract filename from URL or generate one
      filename = File.basename(URI.parse(url).path)
      filename = "image_#{SecureRandom.hex(8)}.jpg" if filename.blank? || !filename.include?('.')
      
      # Attach the image
      self.image.attach(
        io: downloaded_image,
        filename: filename,
        content_type: downloaded_image.content_type || 'image/jpeg'
      )
    rescue => e
      Rails.logger.error "Failed to attach image from URL #{url}: #{e.message}"
      raise "Failed to download image from URL"
    end
  end

  # CSV export method
  def self.to_csv
    attributes = %w[name description price quantity]
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |product|
        csv << attributes.map { |attr| product.send(attr) }
      end
    end
  end

  # Enhanced CSV export with image URLs
  def self.to_csv_with_images
    attributes = %w[name description price quantity image_url]
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |product|
        row = attributes.map do |attr|
          if attr == 'image_url' && product.image.attached?
            Rails.application.routes.url_helpers.rails_blob_url(product.image, only_path: false)
          else
            product.send(attr) unless attr == 'image_url'
          end
        end
        csv << row
      end
    end
  end
end