require 'bundler/setup'
require 'pdf-forms'
require 'cliver'
require 'json'

class SF2809
  attr_accessor :fill_values

  def initialize(fill_values: {})
    @mappings = JSON.parse(File.read('sf2809_mappings.json'))
    @pdftk = PdfForms.new(Cliver.detect('pdftk'))
    @fill_values = fill_values
  end

  def save(save_path='tmp')
    filename = "#{save_path}/sf2809_#{Time.now.to_i}.pdf"
    @pdftk.fill_form 'sf2809.pdf', filename, convert_fill_values(@fill_values)

    filename
  end

  private
  def convert_fill_values(fill_values)
    converted_field_names = {}
    fill_values.each_pair do |api_name, value|
      converted_field_names[convert_field_name(api_name)] = value
    end

    converted_field_names
  end

  def convert_field_name(api_name)
    @mappings.select do |field|
      field['api_name'] == api_name
    end.first['pdf_name']
  end
end
