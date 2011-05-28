// we need instance methods to submit a form remotely using either jquery.rails' or remoteipart's handleRemote() functions.
// this hack reinstates callRemote, which can be called on a form object ex: triggered by submitHandler option of jquery.validate

jQuery(function($) {

  $.fn.extend({
    fire: function(name, data) {
      obj = this;
  		var event = new $.Event(name);
  		obj.trigger(event, data);
  		return event.result !== false;
  	},
  	
  	handleRemoteIp: function() {

      var element = this;
  		var method, url, data,
  			dataType = element.attr('data-type') || ($.ajaxSettings && $.ajaxSettings.dataType) || 'script';

      element.append($('<input />', {
        type: "hidden",
        name: "remotipart_submitted",
        value: true
      })).data('remotipartSubmitted', dataType);

  	  if (element.fire('ajax:before')) {
  	  	method = element.attr('method');
  	  	url = element.attr('action');
  	  	data = element.serializeArray();
  	  	// memoized value from clicked submit button
  	  	var button = element.data('ujs:submit-button');
  	  	if (button) {
  	  		data.push(button);
  	  		element.data('ujs:submit-button', null);
  	  	}


        if (dataType == 'script') {
  		  	url = url.split('?'); // split on GET params
  			  if(url[0].substr(-3) != '.js') url[0] += '.js'; // force rails to respond to respond to the request with :format = js
  			  url = url.join('?'); // join on GET params
        }
  			element.ajaxSubmit({
  				url: url, type: method || 'GET', data: data, dataType: dataType,
  				// stopping the "ajax:beforeSend" event will cancel the ajax request
  				beforeSend: function(xhr, settings) {
  					return element.fire('ajax:beforeSend', [xhr, settings]);
  				},
  				success: function(data, status, xhr) {
  					element.trigger('ajax:success', [data, status, xhr]);
  				},
  				complete: function(xhr, status) {
  					element.trigger('ajax:complete', [xhr, status]);
  				},
  				error: function(xhr, status, error) {
  					element.trigger('ajax:error', [xhr, status, error]);
  				}
  			});
  		}
  		return false;
  	},
  	
  	handleRemote: function() {
  	  var element = this;
  		var method, url, data,
  			dataType = element.data('type') || ($.ajaxSettings && $.ajaxSettings.dataType);

    	if (element.fire('ajax:before')) {
    		if (element.is('form')) {
    			method = element.attr('method');
    			url = element.attr('action');
    			data = element.serializeArray();
    			// memoized value from clicked submit button
    			var button = element.data('ujs:submit-button');
    			if (button) {
    				data.push(button);
    				element.data('ujs:submit-button', null);
    			}
    		} else {
    			method = element.data('method');
    			url = element.attr('href');
    			data = null;
    		}
  			$.ajax({
  				url: url, type: method || 'GET', data: data, dataType: dataType,
  				// stopping the "ajax:beforeSend" event will cancel the ajax request
  				beforeSend: function(xhr, settings) {
  					if (settings.dataType === undefined) {
  						xhr.setRequestHeader('accept', '*/*;q=0.5, ' + settings.accepts.script);
  					}
  					return element.fire('ajax:beforeSend', [xhr, settings]);
  				},
  				success: function(data, status, xhr) {
  					element.trigger('ajax:success', [data, status, xhr]);
  				},
  				complete: function(xhr, status) {
  					element.trigger('ajax:complete', [xhr, status]);
  				},
  				error: function(xhr, status, error) {
  					element.trigger('ajax:error', [xhr, status, error]);
  				}
  			});
  		}
  	},
  	
  	callRemote: function() {
    	if(this.find('input:file').length){
    	  this.handleRemoteIp();
    	} else {
    	  this.handleRemote();
    	}
  	}
  	
  })
})
