require 'bundler/setup'
require 'pdf_forms'
require 'cliver'
require 'json'

pdftk = PdfForms.new(Cliver.detect('pdftk'))

fields = pdftk.get_fields('sf2809.pdf').map do |field|
  result = {}
  result[:pdf_name] = field.name
  result[:api_name] = field.name.downcase.gsub(' ', '').gsub('.', '')
  result[:type] = field.type.downcase
  result[:alt_text] = field.name_alt
  if field.respond_to?(:options) && !field.options.nil?
    result[:options] = field.options
  end

  result
end

File.write('sf2809_mappings.json', JSON.pretty_generate(fields))
