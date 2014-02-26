require 'json'
require 'pry'
require 'net/http'
require 'open-uri'
require 'csv'

NUM_IMAGES_TO_DOWNLOAD = 50


class Authenticate
  attr_reader :token

  def initialize
    @token = retrieve_token
  end

  def continuously_authenticate
    @authentication_thread = Thread.new{get_new_token}
  end

  def stop_continuously_authenticating
    puts "Finished downloading images. Closing authentication process."
    @authentication_thread.exit
  end

  def get_new_token
    loop do
      sleep(1750)
      puts "Current token about to expire."
      retrieve_token
    end
  end

  #FIXME
  #this class is a hack, designed to curl for a token
  #rather than use the oauth2 protocol because I
  #couldn't initialize a session from their endpoints
  def retrieve_token
    puts "Picking up new token."
    parsed_json = {}
    until parsed_json["access_token"]
      results = `curl -X -vvv -d 'client_id=MY_CLIENT_KEY&client_secret=MY_CLIENT_SECRET&grant_type=client_credentials' -X POST 'https://connect.gettyimages.com/oauth2/token/'`
      parsed_json = JSON.parse results
    end
    @token = parsed_json["access_token"]
  end
end


class DownloadEditorialImages

  def initialize(authenticator, search_query, parent_dir, max_num_images)
    @authenticator = authenticator
    @endpoint = "http://connect.gettyimages.com/v1/search/SearchForImages"
    @search_query = search_query
    @child_dir = @search_query.downcase.gsub(/ |,|'|\./, "_")
    @download_directory = create_download_directory(parent_dir)
    @max_num_images = max_num_images
  end

  def create_download_directory(parent_dir)
    child_dir_name = @child_dir
    parent_dir_path = parent_dir.downcase
    child_dir_path = File.join(parent_dir, child_dir_name)

    Dir.mkdir(File.join parent_dir_path) unless File.directory?(parent_dir_path)
    Dir.mkdir(child_dir_path) unless File.directory?(child_dir_path)

    child_dir_path
  end

  def save_images
    images = search_for_images
    puts "#{images.count} found. Downloading up to #{@max_num_images} images to #{@download_directory}."
    images.to_enum.with_index(1) do |new_image, i|
      File.open("#{@download_directory}/#{@child_dir}_#{i}.jpg", 'wb') do |save_copy|
        begin
          save_copy.write open(new_image["UrlComp"]).read
        rescue
          puts "#{@child_dir}: Image is not save-able"
        end
      end
    end
  end

   # token received from CreateSession/RenewSession API call
  def search_for_images
    request = {
        :RequestHeader => { :Token => @authenticator.token},
        :SearchForImages2RequestBody => {
            :Query => { :SearchPhrase => @search_query},
            :ResultOptions => {
                :ItemCount => @max_num_images,
                :EditorialSortOrder => 'MostPopular'
            },
            :Filter => {
                :ImageFamilies => ["editorial"],
                :GraphicStyles => ["Photography"]
            }
        }
    }
    response = post_json(request)
    if response["ResponseHeader"]["Status"]
      response["SearchForImagesResult"]["Images"]
    else
      raise "No images returned #{response['ResponseHeader']['Status']}"
    end
  end

  def post_json(request)
    uri = URI.parse(@endpoint)
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    response = http.post(uri.path, request.to_json, {'Content-Type' =>'application/json'}).body
    begin
      JSON.parse(response)
    rescue
      puts "#{response} is not parse-able"
    end
  end
end


class ReadSearchQueries
  attr_reader :search_terms

  def initialize(csv_file)
    @file_name = csv_file
    @search_terms = []
    read_csv
  end

  def read_csv
    CSV.foreach(@file_name) do |row|
      @search_terms << row[0]
    end
    puts "Ready to begin with the following data: "
    puts @search_terms[0..10].join(", ") + "..."
  end
end


class QueryGettyImages
  def initialize(files, num_downloads_per_term)
    @auth = Authenticate.new
    @search_term_files = files
    @num_downloads_per_term = num_downloads_per_term
  end

  def run_downloader
    @auth.continuously_authenticate
    @search_term_files.each do |f|
      file_dir = f.split('.')[0].strip
      search_terms = ReadSearchQueries.new(f).search_terms
      search_terms.each do |term|
        puts "Initializing downloader for #{term}"
        DownloadEditorialImages.new(@auth, term, file_dir, @num_downloads_per_term).save_images
      end
    end
    @auth.stop_continuously_authenticating
  end
end

QueryGettyImages.new([*ARGV], NUM_IMAGES_TO_DOWNLOAD).run_downloader
