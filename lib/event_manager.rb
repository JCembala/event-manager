# frozen_string_literal: true

require 'date'
require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'

# return valid zipcode, append by zeros or cut to 5 digits
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0').slice(0, 5)
end

# return valid phone number or nothing
def clean_phone_number(phone_number)
  phone_number_digits = phone_number.delete('^0-9')
  length = phone_number_digits.length
  return phone_number_digits if length == 10
  return unless length == 11

  return phone_number_digits.slice(1, 10) if phone_number_digits[0] == 1
end

# Return string with comma seperated legistators name
def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

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

# saves letter to file based on form
def save_form_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filepath = "output/letter_#{id}.html"

  File.open(filepath, 'w') do |file|
    file.puts form_letter
  end
end

# return hour from date in format like: "MM/DD/YYYY hh:mm"
def registration_hour(date)
  DateTime.strptime(date, '%m/%d/%Y %H:%M').hour
end

# return sorted hash with key as hour and val as counted
def peak_hours(hours)
  peak_hours = Hash.new(0)
  hours.each { |hour| peak_hours[hour] += 1 }
  peak_hours.sort_by { |key, val| -val}.to_h
end

def registration_weekday(date)
  DateTime.strptime(date, '%m/%d/%Y %H:%M').strftime('%A')
end

def peak_weekdays(days)
  peak_weekdays = Hash.new(0)
  days.each { |day| peak_weekdays[day] += 1}
  peak_weekdays.sort_by { |key, val| -val }.to_h
end

puts '-------------------------'
puts 'Event Manager initialized'
puts '-------------------------'

letter_template = File.read('form_letter.erb')
erb_template = ERB.new letter_template

content = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

hours = []
weekdays = []

content.each do |row|
  id = row[0]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  name = row[:first_name]
  reg_date = row[:regdate]
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_form_letter(id, form_letter)

  hours.push(registration_hour(reg_date))
  weekdays.push(registration_weekday(reg_date))
end

puts "Most active hour is #{peak_hours(hours).keys[0]} with #{peak_hours(hours).values[0]} occurrence."
puts "Most active weekday is #{peak_weekdays(weekdays).keys[0]} with #{peak_weekdays(weekdays).values[0]} occurrence."
puts '-------------------------'