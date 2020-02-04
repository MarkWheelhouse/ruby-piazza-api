require 'base64'
require "io/console"
require 'net/https'
require 'json'

################################################################################

# constant configuration:
MAIL_EXTN = "imperial.ac.uk"

################################################################################

class PiazzaAPI
  
  def initialize(services_url, auth=nil)
    @uri = URI.parse(services_url)

    @username = nil
    @password = nil
    @cookies = nil
    @users = {}

    @roles = {"TA" => "ta", "PROF" => "inst"}
    @mail_extn = MAIL_EXTN
    
    self.authenticate(auth)

    @https = Net::HTTP.new(@uri.host, @uri.port)
    #DEBUG @https.set_debug_output($stdout)
    @https.use_ssl = (@uri.scheme == "https")
    @https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    auth_token = Base64.urlsafe_encode64("#{@username}:#{@password}")
    @authorization = "Basic #{auth_token}"
  end

  def mail_extn
    @mail_extn
  end
  
  def authenticate(auth)
    if auth then
      login = auth[:piazza_login]
      @password = auth[:piazza_pwd] 
    else
      puts "Please enter your Piazza username:"
      login = STDIN.gets.chomp

      puts "Please enter your Piazza password:"
      @password = STDIN.noecho(&:gets).chomp 
      # does not show password on commandline
    end
    @username = "#{login}@#{@mail_extn}"
  end
  
  def login()
    # construct login post data
    login_data = { "method": "user.login",
                   "params": { "email": @username,
                               "pass": @password 
                             } 
                 } 
    uri = @uri.dup
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = login_data.to_json

    response = @https.request(request)

    # process session cookies
    all_cookies = response.get_fields('set-cookie')
    cookies_array = Array.new
    all_cookies.each do |cookie|
      cookies_array.push(cookie.split('; ')[0])
    end
    @cookies = cookies_array.join('; ')
    @session_id = @cookies.split("session_id=")[1].split(";")[0]
    #DEBUG puts "cookies: \n#{@cookies.inspect}\n"

    JSON::parse(response.body, :symbolize_names => true)
  end 
  
  # Piazza api call wrapper - returns a JSON object
  def apiCall(data)
    uri = @uri.dup
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request['Cookie'] = @cookies
    request['CSRF-Token'] = @session_id
    request.body = data.to_json

    response = @https.request(request)   
    JSON::parse(response.body, :symbolize_names => true)
  end

  def set_users(data)
    @users = data
  end

  # pull all Piazza courses data for authenticated user @username
  def get_course_data() 
    puts "retrieving all Piazza course data for #{@username}"

    post_data = {
      "method": "user.status",
      "params": {}
    }
    self.apiCall(post_data)
  end
  
  # change the course number for the course with class_id 
  def update_course_number(class_id, new_number)
    post_data = {
      "method": "network.update",
      "params": { "id": class_id,
                  "course_number": new_number
                }
    }
    self.apiCall(post_data)
    sleep(10)  
  end
  
  # set course with class_id to inactive status
  def deactivate_course(class_id)
    post_data = {
      "method": "network.update",
      "params": { "id": class_id,
                  "status": "inactive"
                }
    }
    self.apiCall(post_data)
    sleep(10)        
  end
  
  # set course with class_id to active status
  def activate_course(class_id)
    post_data = {
      "method": "network.update",
      "params": { "id": class_id,
                  "status": "active"
                }
    }
    self.apiCall(post_data)
    sleep(10)              
  end

  # Add students in logins array to the course with class_id
  def add_students(class_id, logins)
    add_list = []
    logins.each do |login|
      add_list << "#{login}@#{@mail_extn}"
    end

    post_data = {
      "method": "network.update",
      "params": { "from": "ClassSettingsPage",
                  "add_students": add_list,
                  "id": class_id
                }
    }
    self.apiCall(post_data)
    sleep(10)
  end

  # Add an instructor with login of type role to the course with class_id
  def add_instructor(class_id, role, login)
    type = @roles[role]
    return nil if !type

    post_data = {
      "method": "network.update",
      "params": { "from": "ClassSettingsPage",
                  "add_#{type}": "#{login}@#{@mail_extn}",
                  "id": class_id
              }
    }
    self.apiCall(post_data)
    sleep(10)
  end

  # retreive enrolled users for a Piazza course class_id
  def get_course_users(class_id)
    post_data = {
      "method": "network.get_all_users",
      "params": { "nid": class_id }
    }
    self.apiCall(post_data)
  end

  # Remove users in logins array from the course with uid
  def remove_users(class_id, logins)
    remove_list = []
    logins.each do |login|
      remove_list << @users[login]
    end

    post_data = {
      "method": "network.update",
      "params": {  "remove_users": remove_list,
                   "id": class_id
                }
    }
    self.apiCall(post_data)
    sleep(10)
  end

end

################################################################################

