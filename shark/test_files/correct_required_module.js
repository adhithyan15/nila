//Written using Nila. Visit http://adhithyan15.github.io/nila
(function() {
  var fs;

  fs = require('fs');

  fs.readFile('/etc/hosts','utf8',function(err,data) {
    if (err) {
      console.log(err);
    }
    console.log(data);
  });

}).call(this);