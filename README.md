# SF 2809 - Health Benefits Election Form

A stateless REST API for filling the SF-2809 PDF.

## Quickstart

Clone this repo, `cd` into it and run `bundle`.

In one terminal tab, start the API server:

```
ruby server.rb
```

In another terminal tab, serve `index.html`:

- Ruby: `ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 8000, :DocumentRoot => Dir.pwd).start'`
- Python 3: `python3 -m http.server`

Visit `localhost:8000`

To modify the form data, alter `formData` in `sf2809.js`.

### API access

```bash
# in a new tab, while server.rb is running

curl \
-X POST \
-H "Content-Type: application/json" \
-d '{"part_i_area_code": "20006"}' \
http://localhost:4567 > sf2809.pdf

# ...

open sf2809.pdf
```

# How To

Below are the steps to teach you the process of "digitizing" a PDF form. A benefit of digitizing a PDF form us that you can store information as data and not as difficult-to-search files. Think of the filled PDF as one of many possible rendering implementations. The underlying data, once de-coupled from the PDF can be repurposed in useful ways, such as easy reporting. For example, suppose the underlying data is stored in a SQL database:

```
SELECT * FROM forms WHERE form.end_date < '2015-09-13';
```

Try doing that same operation against a folder of PDF files.

Moreovoer, my gaining the ability to represent the information contained in a PDF with semantic HTML, the information and user interface can become much more accessible.

At the end of this tutorial, you will have the following:

- A REST API that takes JSON and returns a filled PDF file
- A Javascript SDK that makes an AJAX request to the REST API and renders the result natively using PDF.js
- A simple Bootstrap HTML form. You fill in the form, submit it, and you get a filled PDF rendered in the same page.
- And most importantly: a particular set of skills that can be applied to any PDF form that accepts FDF data.

## Requirements

To complete this tutorial, you'll need some beginner/intermediate Ruby, Javascript, and HTML skills. Nothing too fancy.

Technically-speaking, your computer will need:

- Ruby (2.x should be fine)
- [pdftk](https://www.pdflabs.com/tools/pdftk-server/)

To follow along, clone this repo (and `cd` into it and run `bundle`) and run the included code samples as prompted in the tutorial.

Included in this repo:

- `sf2809.pdf` - the form we will be filling
- `generate_json_mappings.rb` - generates a JSON mapping file

## Technical Background

Fillable PDF forms use the "Acrobot Forms Data Format" (FDF) to serialize form data. While FDF is less pretty than other data exchance formats such as JSON, parsing it is already a solved problem. There are libraries for Ruby and Node, for example, that make it easy transform native data structures (e.g. Ruby's Hash or Javascript's Objects) to FDF.

At its core, a software-based PDF filler simply takes data from user input, serializes it to FDF, and applies that FDF to the PDF.

Thankfully, applying FDF to a PDF is also a solved problem thanks to a library called [`pdftk`](https://www.pdflabs.com/tools/pdftk-server/). `pdftk` is a command-line utility for editing and manipulating PDFs. The two `pdftk` commands we care about for PDF filling are:

- `dump_data_fields`
- `fill_form`

To make matters even easier, there is a Ruby gem called [`pdf-forms`](https://github.com/jkraemer/pdf-forms) that provides an interface to PDFs with clean, idiomatic Ruby. The equivalent `pdf-forms` functions that we care about are:

- `PdfForms#get_field_names`
- `PdfForms#fill_form`

## Get the FDF field names

The goal of this step is to become familiar with `pdftk` and `pdf-forms` and their output formats.

Run `pdftk sf2809.pdf dump_data_fields`. You should see a lot of entries that look like:

```
FieldType: Button
FieldName: 43. Med B
FieldNameAlt: Part, A,.  Enrollee and Family Member Information.  Number 43.  This is check box two of three.  Press the space bar to select this box if the third family member is covered by Medicare Part B.
FieldFlags: 0
FieldJustification: Left
FieldStateOption: 1
FieldStateOption: Off
```

Notice the information we get about each field in the form. Important to us are its type, name, alt text, and state options.

Writing a parser for this text would be a bit of a pain and thankfully `pdf-forms` does this for you. To get the field names in `pdf-forms`:

```ruby
require 'pdf-forms'
require 'cliver'

# Cliver makes it easy to find the path to command line utilities
pdftk = PdfForms.new(Cliver.detect('pdftk'))

pdftk.get_fields('sf2809.pdf')
#=>
# ...
# @flags="8388608",
# @justification="Center",
# @max_length="10",
# @name="H.  event date 1",
# @name_alt=
#  "Part H.  Signature.  Number 2.  Enter the date you signed the form.  Enter a two digit month
#  and day and a four digit year.",
# @type="Text">
# ...
```

Now that we can access the form fields as Ruby object, it's time to serialize the fields as a JSON file.

## Generate mappings JSON file

The goal of this step is to create a data dictionary that maps human-friendly field names with machine-friendly field names.

FDF fields are typically written by humans when using something like Adobe Acrobat. While these names may or may not be user-friendly, they are almost certainly not machine-friendly. For example, the SF 2809 has an FDF field called `47. email address`. Imagine that as a JSON key and it becomes clear that it will be useful to convert these field names to be more machine-friendly. `47. email address` could be converted to `"47_email_address"`, `"email"`, or `"email_47"`, for example.

One could write a single function that takes human-friendly field names and transforms them. A benefit is that the process is quick and automated. However, because the original field names were likely written by humans, they also likely lack the consistency to be addressable by humans. For this reason, it might be worth spending sometime manually creating the machine-friendly names.

For this tutorial, however, we're going to use the following function to transform the field names:

```ruby
# downcase it
# remove spaces
# remove periods
field.name.downcase.gsub(' ', '').gsub('.', '')
# ...
```

The file `generate_mappings_json.rb` creates a pretty-formatted JSON file with all the right field names on which you can add machine-friendly field names by hand-editing the file.

```ruby
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
```

All this code does is map an array of Ruby objects as hashes, converts it all to JSON, and writes the JSON to a file.

To generate the JSON file, run `ruby generate_mappings_json.rb`.

In a text editor, open `sf2809_mappings.json`. It should contain a lot of these:

```json
// ...
{
  "pdf_name": "1. Name",
  "api_name": "1name",
  "type": "text",
  "alt_text": "Part, A,.  Enrollee and Family Member Information.  Number 1.  Enter enrollee's last name, first name, and middle initial."
},
{
  "pdf_name": "2. SS",
  "api_name": "2ss",
  "type": "text",
  "alt_text": "Part, A,.  Enrollee and Family Member Information.  Number 2.  Enter enrollee's social security number."
},
// ...
```

## Create filler function

The goal of this step is to write a function that fills the PDF programatically and to then wrap that function inside of a Ruby class.

With the JSON mappings file, we can fill the PDF fairly easily using `PdfForms#fill_form`. The usage for that function is:

```ruby
pdftk = PdfForms.new(Cliver.detect('pdftk'))
pdftk.fill_form '/path/to/form.pdf', 'myform.pdf', foo: 'bar'
```

Adapted for the SF 2809, the usage would be:

```ruby
fill_values = {}
fill_values['6address1'] = '1800 F Street NW'
pdftk.fill_form 'sf2809.pdf', 'sf2809-filled.pdf', fill_values
```

Wrapping this into a simple Ruby class (in `form_filler.rb`):

```ruby
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

  def save(path: nil)
    full_path = ''
    if path.nil?
      full_path = 'sf2809-filled.pdf'
    else
      full_path = path
    end
    @pdftk.fill_form(
      'sf2809.pdf',
      full_path,
      convert_fill_values(@fill_values)
    )
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
```

The usage of this class is quite simple:

```ruby
fill_values = {
  '6address1' => '1800 F. Street NW'
}
form = SF2809.new(fill_values: fill_values)
path = form.save('tmp')
path #=> tmp/sf2809_1442198514.pdf
```

## Expose API

The goal of this step is to expose the `SF2809` Ruby class to a RESTful API.

At the end of this step, the following cURL command will return a filled PDF:

```bash
curl \
-X POST \
-H "Content-Type: application/json" \
-d '{"6address1": "1800 F. Street NW"}' \
http://localhost:4567/sf2809 > sf2809-filled-from-curl.pdf
```

For this step, we'll use Ruby's Sinatra web framework. This API will be stateless, meaning it won't store any information. It will accept JSON as part of a POST request, and send back the filled PDF file.

### A brief note on POST requests and SSL

POST requests work well because they will help ensure anonymity. If you use SSL in production (which this tutorial assumes), POST data will be encrypted and safe from prying eyes. POST data will also not "leak" the way GET data will.

### Back to the API step

This is the API from `server.rb`

```ruby
require 'bundler/setup'
require 'sinatra'
require 'json'
require 'tempfile'
require_relative 'form_filler.rb'

post '/sf2809' do
  begin
    json_params = JSON.parse(request.body.read)
    form = SF2809.new(fill_values: json_params)
    file = form.save('tmp')
    bytes = File.read(file)
    File.delete(file)
    tmpfile = Tempfile.new('response.pdf')
    tmpfile.write(bytes)
    send_file(tmpfile)
  rescue => e
    content_type :json
    return {
      error: e.to_s
    }
  end
end
```

The request is wrapped in a `begine rescue end` block so that errors can be caught and sent back to the client as JSON.

To start the server, run `ruby server.rb`. In another terminal tab, run:

```bash
curl \
-X POST \
-H "Content-Type: application/json" \
-d '{"6address1": "1800 F. Street NW"}' \
http://localhost:4567/sf2809 > sf2809-filled-from-curl.pdf
```

Open `sf2809-filled-from-curl.pdf` (and scroll down to the actual form) and notice the address field was filled! Exciting stuff!

## Render using PDF.js

The goal of this step is to provide a client-side Javascript interface to the API from the previous step which can render the PDF natively using PDF.js.

The first step is to create an HTML scaffold:

```html
<!DOCTYPE html>
<html>
  <head>
    <title>SF 2809</title>
    <script type="text/javascript" src="pdf.js"></script>
    <script type="text/javascript" src="sf2809.js"></script>
  </head>
  <body>
    <div id="main">
      <canvas id="1"></canvas>
      <canvas id="2"></canvas>
      <canvas id="3"></canvas>
      <canvas id="4"></canvas>
      <canvas id="5"></canvas>
      <canvas id="6"></canvas>
      <canvas id="7"></canvas>
      <canvas id="8"></canvas>
      <canvas id="9"></canvas>
      <canvas id="10"></canvas>
      <canvas id="11"></canvas>
      <canvas id="12"></canvas>
      <canvas id="13"></canvas>
      <canvas id="14"></canvas>
      <canvas id="15"></canvas>
    </div>
  </body>
</html>
```

`PDF.js` will expect a `canvas` tag for each page in the PDF. Because SF 2809 always has 15 pages, we can hard-code 15 canvases. We're also loading two scripts, `pdf.js` and `sf2809.js`. `pdf.js` is just copied from https://github.com/mozilla/pdfjs-dist/blob/master/build/pdf.combined.js.

In `sf2809.js`, we need to do two things:

- send a POST to the server
- take the POST response and feed it into PDF.js to render it onto the `canvas` tags

We'll be eschewing jQuery in favor of [`vanilla.js`](http://vanilla-js.com/).

In order to make a POST request, we need to instantiate an `XMLHttpRequest`:

```javascript
var formData = {
  "6address1": "1800 F. Street NW"
};

// ...

var xhr = new XMLHttpRequest();
xhr.open('POST', 'http://localhost:4567/sf2809', true);
xhr.setRequestHeader('Content-Type', 'application/json');
xhr.responseType = 'arraybuffer';

xhr.onload = function(e) {
  // response is unsigned 8 bit integer
  var responseArray = new Uint8Array(this.response);
  // rendering goes here
};

xhr.send(JSON.stringify(formData));
```

With the response, `responseArray`, we need to pass it to PDF.js:

```javascript
var responseArray = new Uint8Array(this.response);

PDFJS.getDocument(responseArray).then(function wub(pdf) {
  canvases.forEach(function(myCanvas) {
    var pageNumber = parseInt(myCanvas);
    pdf.getPage(pageNumber).then(function yoyo(page) {
      var scale = 1.5;
      var viewport = page.getViewport(scale);

      var canvas = document.getElementById(myCanvas);
      var context = canvas.getContext('2d');
      canvas.height = viewport.height;
      canvas.width = viewport.width;

      page.render({canvasContext: context, viewport: viewport}).promise.then(function() {
      // ...
      });
    });
  });
});
```

The finished file is in `sf2809.js` in this repo.

To run this locally, serve the files using a static file server. Here are two ways to do this (there are many more):

- Ruby: `ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => 8000, :DocumentRoot => Dir.pwd).start'`
- Python 3: `python3 -m http.server`

Visit `localhost:8000` (scroll down to the form) and notice that the data defined in `formData` from `sf2809.js` is now in the rendered PDF.

## Create an HTML form

The goal of this step is to create an HTML form which sends an AJAX request to the API using the Javascript from the previous step.

[TODO]

### Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
