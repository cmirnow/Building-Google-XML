class GoogleXmlBuilder
  include ActionView::Helpers

  attr_reader :builder, :ids, :promotion_ids

  def initialize(ids, promotion_ids)
    @ids = ids
    @promotion_ids = promotion_ids
  end

  def generate
    @builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.rss("xmlns:g" => "http://base.google.com/ns/1.0", :version => "2.0") do
        xml.channel do
          xml.title "Brand_Name"
          xml.link "https://#{Rails.application.secrets.im_domain}"
          xml.description { xml.cdata '【Brand Name】 - Brand Description' }

          products.each do |product|
            xml.item do
              xml['g'].id product.code
              xml['g'].title { xml.cdata(product.name) }
              xml['g'].description { xml.cdata(description_for(product)) }
              xml['g'].link { xml.cdata(product.show_url) }
              xml['g'].image_link { xml.cdata(product.image_url) }
              xml['g'].condition 'new'
              xml['g'].availability product.quantity.to_f > 0 ? 'in stock' : 'out of stock'
              if product.action?
                xml['g'].price to_price(product.old_price)
                xml['g'].sale_price to_price(product.price)
              else
                xml['g'].price to_price(product.price)
              end

              product_type = product_type(product)
              if product_type.present?
                xml['g'].product_type product_type
              end

              xml['g'].brand product.brand.name
            end
          end
        end
      end
    end

    write_to_xml
  end

  def product_type(product)
    category_filter = product.category.filters.where(f_type: 0).first
    if category_filter
      product.filters.where(id: category_filter.child_ids).first.try(:name)
    end
  end

  def create_offers
    -> (xml) do
      products.each do |product|
        xml.offer(id: product.code, type: "vendor.model", available: "true") do
          xml.url product.show_url
          xml.price product.price
          xml.currencyId 'USD'
          xml.categoryId product.category_id
          xml.vendor product.brand.try(:name)
          xml.model product.name
          xml.picture product.image_url
        end
      end
    end
  end

  def create_categories
    -> (xml) do
      categories.each do |rc|
        xml.category(rc.name, id: rc.id)
        rc.children.each do |c|
          xml.category(c.name, id: c.id, parentId: c.parent_id)
        end
      end
    end
  end

  def write_to_xml
    File.open(Rails.root.join('public', 'data', 'google', promotion_ids.to_s + '.xml'), 'w:UTF-8') { |file| file.write(builder.to_xml) }
  end

  private

  def description_for(product)
    result = []
    result << "Brand: #{product.brand.name}" if product.brand.present?
    result << "Country: #{product.country.name}" if product.country.present?
    result << "Collection: #{product.collections.pluck(:name).join(' ')}" if product.collections.present?
    result << "Surface: #{product.surfaces.pluck(:name_ru).join(' ')}" if product.surfaces.present?
    result << "Color: #{product.colors.pluck(:name_ru).join(', ')}" if product.colors.present?
    result << "Applying: #{product.appliances.pluck(:name_ru).join(' ')}" if product.appliances.present?
    result << "Material: #{product.materials.pluck(:name_ru).join(' ')}" if product.materials.present?
    result << "Style: #{product.styles.pluck(:name_ru).join(' ')}" if product.styles.present?
    result << "Form: #{product.forms.pluck(:name_ru).join(' ')}" if product.forms.present?
    result << "Size, mm: #{product.dimensions}" if product.dimensions.present?
    result.join('. ')
  end

  def to_price(price)
    number_to_currency(price, unit: ' USD', format: '%n%u', delimiter: '')
  end

  def categories
    @categories ||= Category.for_product.includes(:children)
  end

  def products
    @products ||= Product.active.where(id: ids).includes(:images, :brand)
  end
end
