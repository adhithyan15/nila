//Written using Nila. Visit http://adhithyan15.github.io/nila
(function() {
  if (visitor_present) {
  //This file is for demonstration purpose. It doesn't really achieve anything
    if (active || happy) {
      console.log("Hello Wonderful Visitor!");
    } else if (idle && not_engaged) {
      console.log("Hello Visitor! It is time to engage!");
    } else {
      console.log("Hello user!");
    }
  }

}).call(this);