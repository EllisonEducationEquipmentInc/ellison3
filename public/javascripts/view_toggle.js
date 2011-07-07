/* DO NOT MODIFY. This file was compiled Thu, 07 Jul 2011 17:52:09 GMT from
 * /home/mark/ellison3/app/coffeescripts/view_toggle.coffee
 */

(function() {
  (function($) {
    var ViewToggler;
    ViewToggler = function(settings, dom) {
      this.settings = settings;
      this.dom = dom;
      return this.current_state = settings.initial_state;
    };
    $.fn.toggleView = function(options) {
      var settings;
      settings = $.extend({}, $.fn.toggleView.defaults, options);
      return this.each(function() {
        var dom;
        dom = $(this);
        if (dom.data("toggleView")) {
          return;
        }
        dom.data("toggleView", true);
        return new ViewToggler(settings, dom).init();
      });
    };
    $.fn.toggleView.defaults = {
      toggled_class: "toggled",
      state_attribute: "data-current-state",
      list_view_class: "listview",
      toggle_text: "%state% view",
      states: ["grid", "list"],
      collection_container: ".highlightable",
      initial_state: "grid"
    };
    return $.extend(ViewToggler.prototype, {
      init: function() {
        this.setInitialStateIfNeccessary();
        return this.connectToggleEvents();
      },
      setInitialStateIfNeccessary: function() {
        if (this.dom.attr("data-current-state") === this.settings.initial_state) {
          return;
        }
        this.dom.text(this.settings.toggle_text.replace("%state%", this.getOpposite()));
        this.dom.attr("data-current-state", this.settings.initial_state);
        if (this.settings.states.indexOf(this.settings.initial_state) === 1) {
          this.dom.addClass("toggled");
          return $(this.settings.collection_container).addClass("listview");
        }
      },
      toggle_state: function() {
        var that;
        that = this;
        this.dom.text(that.settings.toggle_text.replace("%state%", that.current_state));
        this.current_state = this.getOpposite();
        this.dom.attr("data-current-state", that.current_state);
        if (this.settings.states.indexOf(this.current_state) === 0) {
          this.dom.removeClass("toggled");
        } else {
          this.dom.addClass("toggled");
        }
        $(window).unbind("hashchange");
        location.hash = $.param.fragment(location.hash, {
          view: this.current_state
        }, 0);
        return $(this.settings.collection_container).fadeOut("fast", function() {
          if (that.settings.states.indexOf(that.current_state) === 0) {
            $(this).fadeIn("fast").removeClass("listview");
          } else {
            $(this).fadeIn("fast").addClass("listview");
          }
          return bind_hashchange();
        });
      },
      connectToggleEvents: function() {
        var that;
        that = this;
        return this.dom.click(function() {
          that.toggle_state();
          return false;
        });
      },
      getOpposite: function() {
        if (this.settings.states.indexOf(this.current_state) === 0) {
          return this.settings.states[1];
        } else {
          return this.settings.states[0];
        }
      }
    });
  })(jQuery);
}).call(this);
