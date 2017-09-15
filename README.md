# PiazzaAPI

An Unofficial Ruby Client for Piazza's Internal API


## Usage

```ruby
>>> require File.join(File.dirname(__FILE__), 'apis', 'piazza_api.rb')
>>> auth_info = nil
>>> piazza_api = PiazzaAPI.new("https://piazza.com/logic/api", auth_info)
Please enter your Piazza username: ...
Please enter your Piazza password: ...

>>> json = piazza_api.get_course_data()
>>> courses_list = json[:result][:networks]
>>> courses_list.each do |entry|
>>>   puts entry.inspect
>>> end

>>>  json = piazza_api.get_course_users(class_id)
>>>  piazza_student_data = json[:result] 

>>> piazza_api.remove_users(class_id, rm_list)
  
>>> piazza_api.add_students(class_id, dbc_student_list)

>>> piazza_api.add_instructor(class_id, "PROF", login)

>>> piazza_api.add_instructor(class_id, "TA", login)
```

Above are some examples to help get you started.

You can also view the "piazza_api_info.txt" file to see more ways of 
interacting with the Piazza APIs, or simply use the Piazza website 
with the web-developer console set to network and observe the 
GET/POST methods sent to piazza.com.
You can add you own methods to the PiazzaAPI class to support such
API class internally.

## Installation

You need to have ruby 2.0 (or later) installed on your system.
You can then pull down this repo with:

```bash
git clone https://github.com/mjw03/ruby-piazza-api
cd ruby-piazza-api
python setup.py develop
```

## Contribute

* [Issue Tracker](https://github.com/mjw03/ruby-piazza-api/issues)
* [Source Code](https://github.com/mjw03/ruby-piazza-api)

## License

This project is licensed under the MIT License.


## Disclaimer

This is not an officially supported API for Piazza and I am in no way 
affiliated with Piazza Technologies Inc. 
Neither I nor Imperial College London are responsible for any damage
that you may inflict in using this API interface.

i.e. Use only at your own risk!
