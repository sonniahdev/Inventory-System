require 'rails_helper'

RSpec.describe Product, type: :model do
  it "is valid with valid attributes" do
    product = Product.new(name: "Test", description: "Test", price: 10.99, quantity: 20)
    expect(product).to be_valid
  end

  it "is not valid without a name" do
    product = Product.new(name: nil, description: "Test", price: 10.99, quantity: 20)
    expect(product).not_to be_valid
  end

  it "updates stock correctly" do
    product = Product.create(name: "Test", description: "Test", price: 10.99, quantity: 20)
    product.update_stock(5, :increase)
    expect(product.quantity).to eq(25)
    product.update_stock(10, :decrease)
    expect(product.quantity).to eq(15)
  end

  it "detects low stock" do
    product = Product.create(name: "Test", description: "Test", price: 10.99, quantity: 5)
    expect(product.low_stock?).to be true
    product.quantity = 15
    expect(product.low_stock?).to be false
  end
end