(function($){

$.fn.toggleView = function(options) {
	
	var settings = $.extend({}, $.fn.toggleView.defaults, options);
	
	return this.each(function() {
		var dom = $(this);
		if (dom.data('toggleView'))
			return; // already toggleView
		dom.data('toggleView', true);
		
		new ViewToggler(settings, dom).init();
	})
};

$.fn.toggleView.defaults = {
	toggled_class:		"toggled",
	state_attribute: 	'data-current-state',
	list_view_class: 	'listview',
	toggle_text: 			"switch to %state% view",
	states: 					["grid", "list"],
	collection_container: '.highlightable',
	initial_state: "grid", 
};

function ViewToggler(settings, dom) {
	this.settings = settings;
	this.dom = dom;
	this.current_state = settings.initial_state;
};

$.extend(ViewToggler.prototype, {
	
	init: function() {
		this.setInitialStateIfNeccessary();
		this.connectToggleEvents()
	},
	
	setInitialStateIfNeccessary: function() {
		if(this.dom.attr('data-current-state') == this.settings.initial_state)
			return;
		this.dom.text(this.settings.toggle_text.replace("%state%", this.getOpposite()));
		this.dom.attr('data-current-state', this.settings.initial_state)
		if (this.settings.states.indexOf(this.settings.initial_state) == 1) {
			this.dom.addClass("toggled");
			$(this.settings.collection_container).addClass("listview");
		}
	},
	
	toggle_state: function() {
		var that = this;
		this.dom.text(that.settings.toggle_text.replace("%state%", that.current_state));
		this.current_state = this.getOpposite()
		this.dom.attr('data-current-state', that.current_state);
		if (this.settings.states.indexOf(this.current_state) == 0) {
			this.dom.removeClass("toggled");
		} else {
			this.dom.addClass("toggled");
		};
		$(window).unbind( 'hashchange');
		location.hash = $.param.fragment( location.hash, {view: this.current_state}, 0 );
		$(this.settings.collection_container).fadeOut("fast", function() {
			if (that.settings.states.indexOf(that.current_state) == 0) {
				$(this).fadeIn("fast").removeClass("listview");
			} else {
				$(this).fadeIn("fast").addClass("listview");
			};
			bind_hashchange();
    });
	},
	
	connectToggleEvents: function() {
		var that = this;
		this.dom.click(function(){ that.toggle_state(); return false;})
	},
	
	getOpposite: function() {
		return (this.settings.states.indexOf(this.current_state) == 0) ? this.settings.states[1] : this.settings.states[0];
	},
	
});
})(jQuery);