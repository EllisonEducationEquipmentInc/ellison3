if( typeof tm === "undefined") {
  var tm = {}
}

tm.mirrorCookies = function() {

  // Cookie notification on first visit
  function cookieNotification(msg) {

    // cookie exists?
    if($.cookie('cookie_law_uk') == null) {
      // no? display notification and
      addNotification(msg);
      // hide after 10 secs
      cookieNotifTimer();

      // create cookie
      $.cookie('cookie_law_uk', 'mirror', {
        expires : 30
      });
    };
  }

  // Cookie notification timeout
  function cookieNotifTimer() {
    var $popup = $('#cookieNotification'), onTimeOut = function() {
      $popup.hide();
    }, timer = setTimeout(onTimeOut, 15000);

    $popup.bind('mouseenter', function() {
      clearTimeout(timer);
    }).bind('mouseleave', function() {
      timer = setTimeout(onTimeOut, 15000);
    });
  }

  function addNotification(msg) {

    $('body').append(msg);
  }

  return {
    initCookies : function(msg) {
      cookieNotification(msg);
    }
  };
}();



