require 'erb'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.tr('() +._-', '')
  if phone_number.length == 10
    phone_number
  elsif (phone_number.length == 11 && phone_number[0] == '1')
    phone_number[1..10]
  else
    '0000000000'
  end
end

def find_time_of_registration(regdate)
  Time.strptime(regdate, '%D %H:%M').hour
end

def find_day_of_registration(regdate)
  Time.strptime(regdate, '%D %H:%M').wday
end

def determine_most_common_hour(array_of_hours)
  mode(array_of_hours)
end

def determine_most_common_day_of_the_week(array_of_days)
  days_of_week = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  mode(array_of_days).map { |day| days_of_week[day] }
end

def mode(array)
  mode = {highest: 0, modes: []}
  array.tally.each do |key, amount|
    if mode[:modes].empty? || mode[:highest] == amount
      mode[:modes] << key
      mode[:highest] = amount
    elsif mode[:highest] < amount
      mode[:modes] = [key]
      mode[:highest] = amount
    end
  end
  mode[:modes]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('api_key').strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def create_thank_you_letter(id, letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts letter
  end
end

puts 'EventManager initialized!'

template = File.read('form_letter.erb')
erb_template = ERB.new template

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
  ) if File.exist?('event_attendees.csv')

registered_times = []
registered_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  phone_number = clean_phone_number row[:homephone]

  zipcode = clean_zipcode row[:zipcode]

  registered_times << find_time_of_registration(row[:regdate])

  registered_days << find_day_of_registration(row[:regdate])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  create_thank_you_letter(id, form_letter)
end

determine_most_common_hour(registered_times)
determine_most_common_day_of_the_week(registered_days)
