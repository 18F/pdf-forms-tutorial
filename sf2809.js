var formData = {
  "6address1": "1800 F. Street NW"
};
var canvases = [
  '1', '2', '3', '4', '5', '6', '7', '8',
  '9', '10', '11', '12', '13', '14', '15'
];

var renderPdfFromResponseArray = function(responseArray, canvases) {
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
};

document.addEventListener('DOMContentLoaded', function() {
  var xhr = new XMLHttpRequest();
  xhr.open('POST', 'http://localhost:4567/sf2809', true);
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.responseType = 'arraybuffer';

  xhr.onload = function(e) {
    // response is unsigned 8 bit integer
    var responseArray = new Uint8Array(this.response);
    renderPdfFromResponseArray(responseArray, canvases);
  };

  xhr.send(JSON.stringify(formData));
});
