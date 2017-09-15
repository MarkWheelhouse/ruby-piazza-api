#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'apis', 'piazza_api.rb')

################################################################################

################################################################################

# CONSTANTS #

STAFF_OPTOUT_LIST = [] # for any staff members who do not want their data to be sent to Piazza

################
# Main Program #
################

if ARGV.length < 1 || ARGV.length > 2 then
  puts "Usage: #{$0} <api_year> <dry_run>?"
  puts "     <dbc_api_year> = database year (e.g. 1617)"
  puts "     <dry_run> = run without executing any Piazza API writes"      
  exit -1
end

year_code = ARGV[0]
dry_run = ARGV[1]

if File.exists?("config.json") then
  auth_info = JSON::parse(File.read("config.json"), :symbolize_names => true)
  puts "authentication data read from file"
end

# set up "specified year" filters
start = "20#{year_code[0..1]}"
finish = "20#{year_code[2..3]}"
@terms = ["Fall #{start}", "Spring #{finish}", "Summer #{finish}"]

puts "Running Piazza enrolment update for #{year_code} courses"

# generate Piazza session login data
@piazza_api = PiazzaAPI.new("https://piazza.com/logic/api", auth_info)
result = @piazza_api.login()
#DEBUG puts "login attempt result: \n#{result.inspect}\n"

# quit if Piazza login failed
if result[:error] != nil then
  puts result[:error]
  puts "Piazza login failed - aborting!"
  exit -1
end

# pull all Piazza courses data (for authenticated user)
@piazza_courses = {}
json = @piazza_api.get_course_data()
#DEBUG puts json.inspect
#DEBUG puts json[:result].inspect

courses_list = json[:result][:networks]
#DEBUG puts courses_list.first.inspect

courses_list.each do |entry|
  if @terms.include?(entry[:term]) then
    code = entry[:course_number]
    class_id = entry[:id]
    puts "processing #{code}:#{entry[:name]} (#{entry[:term]}) - #{class_id}"
    @piazza_courses[code] = class_id
  end
end

#DEBUG puts @piazza_courses.inspect
#  @piazza_courses.each do |course|
#    puts course.inspect
#  end

# iterate updates over all found courses
@piazza_courses.each do |course_code, class_id|
  #next if course_code.to_i >= 300 #to skip 3rd/4th/MSC classes (while testing)
  #next if (course_code.to_i % 100) == 0 #to skip the general discussion boards

  puts "> working on course #{course_code} (#{class_id})"

  users = {}

  json = @piazza_api.get_course_users(class_id)
  piazza_student_data = json[:result]
  #DEBUG
  #piazza_student_data.each do |user|
  #  puts user.inspect unless user[:role] == "student"
  #end

  # populate Piazza course enrolment data lists
  piazza_student_list = []
  piazza_staff_list = []

  piazza_student_data.each do |member|
    #DEBUG puts "processing: #{member[:email].inspect}"
    emails = member[:email].split(", ") 
    #DEBUG puts emails.inspect
    college_emails = emails.select do |email| 
      parts = email.split("@")
      parts[1] == @piazza_api.mail_extn && !parts[0].include?(".")
    end
    #DEBUG puts college_emails.inspect
    email = college_emails[0] || emails[0]
    login = email.split("@")[0] 
    users[login] = member[:id]
    #DEBUG puts "#{login} -> #{member[:id]}"   
    if member[:role] == "student" then
      piazza_student_list << login
    else
      piazza_staff_list << login
    end
  end

  @piazza_api.set_users(users)

  # remove your piazza-admin from the piazza-list (so never deleted)
  piazza_staff_list.delete("piazza-admin")

  piazza_student_list.sort!
  piazza_staff_list.sort!

  #DEBUG
  #puts "Piazza student enrolment list (length = #{piazza_student_list.length}"
  #puts piazza_student_list.inspect
  #puts "Piazza staff enrolment list (length = #{piazza_staff_list.length}"
  #puts piazza_staff_list.inspect
  
  # POPULATE YOUR COURSE DATA HERE (possibly from a CSV or your own database API)
  student_list = []
  staff_list = []
  helper_list = []

  # remove duplicate entries from student list
  student_list.uniq! 
  # DEBUG puts student_list.inspect

  # remove any duplicate entries from staff list
  staff_list.uniq! 
  staff_list -= STAFF_OPTOUT_LIST

  # remove any duplicate entries from helper list
  helper_list.uniq! 
  helper_list -= STAFF_OPTOUT_LIST

  student_list.sort!
  staff_list.sort!
  helper_list.sort!

  #DEBUG
  #puts "student enrolment list (length = #{student_list.length}"
  #puts student_list.inspect
  #puts "DBC staff enrolment list (length = #{staff_list.length}"
  #puts staff_list.inspect

  # process the lists to create the necessary course update diff lists
  students_to_remove_list = []
  staff_to_remove_list = []
  helpers_to_remove_list =[]

  piazza_student_list.each do |student|
    if !student_list.delete(student) then
      students_to_remove_list << student
    end
  end

  piazza_staff_list.each do |staff|
    if !staff_list.delete(staff) && !helper_list.delete(staff) then
      staff_to_remove_list << staff
    end
  end

  #DEBUG
  puts "students to delete list (length = #{students_to_remove_list.length})"
  puts students_to_remove_list.inspect

  puts "students to add list (length = #{student_list.length})"
  puts student_list.inspect

  puts "staff to delete list (length = #{staff_to_remove_list.length})"
  puts staff_to_remove_list.inspect

  puts "lecturers to add list (length = #{staff_list.length})"
  puts staff_list.inspect

  puts "helpers to add list (length = #{helper_list.length})"
  puts helper_list.inspect

  (puts "DRY RUN - skipping Piazza API updates \n\n"; next) if dry_run

  # make the API calls to enact the Piazza data sync
  rm_list = students_to_remove_list + staff_to_remove_list
  #DEBUG puts "RM LIST: #{rm_list.inspect}"

  if rm_list.length > 0 then
    puts "removing specified users"
    @piazza_api.remove_users(class_id, rm_list)
  end
  
  if dbc_student_list.length > 0 then
    puts "adding specified students"  
    @piazza_api.add_students(class_id, student_list)
  end
  
  staff_list.each do |login|
    @piazza_api.add_instructor(class_id, "PROF", login)
  end

  helper_list.each do |login|
    @piazza_api.add_instructor(class_id, "TA", login)
  end

  puts "-- #{course_code} done --\n\n"

end
puts "== DBC-Piazza enrolment syncronisation complete! =="
