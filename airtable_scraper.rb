require 'watir'
require 'nokogiri'
require 'open-uri'
require 'csv'


class AirtableScraper
  attr_accessor :browser, :partner_listings, :options

  SITEMAP_URL = 'https://ecosystem.airtable.com/consultants/sitemap.xml'.freeze
  AUTOSAVE_FREQUENCY = 5

  def initialize
    @options = provide_options
    @browser = Watir::Browser.new(:chrome, options: options)
    @partner_listings = []
  end

  def call
    partner_listing_urls.each_with_index do |url, idx|
      scrape_listing(url, idx)
    end

  end

  def scrape_listing(url, idx = 0)
    begin
      secs_to_sleep = rand(1..5)
      sleep(secs_to_sleep)
      browser.goto(url)
      Watir::Wait.until(timeout: 10) { browser.h2(class: 'notranslate typography-h4 py-1').exists? }
      partner_listings << listing_details
      puts "scraped partner: #{url}"
      save_to_csv if time_to_save?(idx)
    rescue => e
      puts ""
      puts "ERROR: #{e.message} on #{url}"
    end

  end

  def partner_listing_urls
    puts "Getting Partner URLs..."
    page = URI.open(SITEMAP_URL, "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3")
    xml = Nokogiri::XML(page)
    urls = xml.css('loc').map { | link | link.text }

    puts "#{urls.count} total sitemap URLs found..."
    urls.map do | url | 
      next if url == 'https://ecosystem.airtable.com/consultants'
      url
    end.compact

  end

  def save_to_csv
    file_name = "airtable_partner_listings.csv"

    CSV.open(file_name, "w") do |csv|
      header_values = partner_listings.first.keys
      csv << header_values

      partner_listings.each do |partner_listing|
        csv << partner_listing.values
      end
    end
    sleep(3)
    puts "saved #{file_name}"
  end

  def provide_options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--window-size=1920,1080') # Set viewport size
    options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3')
    options
  end

  def time_to_save?(idx)
    (idx % AUTOSAVE_FREQUENCY == 0)
  end

  def partner_name
    browser.h2s(class: 'notranslate typography-h4 py-1').first.text
  end

  def location
    browser.divs(class: 'inline').first.text
  end

  def ratings_review_split
    review_ratings = browser.divs(class: 'flex gap-x-1').first.text
    review_ratings.split("\n")
  end

  def rating
    ratings_review_split[0].delete("()")
  end

  def review_count
    if ratings_review_split[1].nil? 
      "0"
    else ratings_review_split[1].delete("()")
    end
  end

  def listing_details

    {
      partner_name: partner_name,
      location: location,
      rating: rating,
      review_count: review_count,
  
    }
  end


end

scraper = AirtableScraper.new

