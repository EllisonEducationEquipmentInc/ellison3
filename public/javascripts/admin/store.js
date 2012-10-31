(function() {

  document.AdminStore = (function() {
    var agent_type_dom, bind_agent_type, bind_country, country_dom, hide_representative_serving_states, representative_serving_dom, selected_agent_type, selected_country, show_representative_serving_states, verify_agent_type_country;

    function AdminStore() {
      this.country_dom = $("#store_country");
      this.agent_type_dom = $("#store_agent_type");
      this.representative_serving_dom = $(".representative_serving");
    }

    country_dom = function(dom) {
      if (dom == null) {
        dom = null;
      }
      return this.country_dom || (this.country_dom = dom);
    };

    agent_type_dom = function(dom) {
      if (dom == null) {
        dom = null;
      }
      return this.agent_type_dom || (this.agent_type_dom = dom);
    };

    representative_serving_dom = function(dom) {
      if (dom == null) {
        dom = null;
      }
      return this.representative_servig_dom || (this.representative_servig_dom = dom);
    };

    selected_agent_type = function() {
      return agent_type_dom().find(":selected").text();
    };

    selected_country = function() {
      return country_dom().find(":selected").text();
    };

    bind_agent_type = function() {
      return agent_type_dom().change(function() {
        return verify_agent_type_country(selected_agent_type(), selected_country());
      });
    };

    bind_country = function() {
      return country_dom().change(function() {
        return verify_agent_type_country(selected_agent_type(), selected_country());
      });
    };

    verify_agent_type_country = function(agent_type, country) {
      if (agent_type === 'Sales Representative' && country === 'United States') {
        return show_representative_serving_states();
      } else {
        return hide_representative_serving_states();
      }
    };

    show_representative_serving_states = function() {
      return representative_serving_dom().fadeIn('show');
    };

    hide_representative_serving_states = function() {
      return representative_serving_dom().hide();
    };

    AdminStore.prototype.bind_agent_type_and_country = function() {
      country_dom(this.country_dom);
      agent_type_dom(this.agent_type_dom);
      representative_serving_dom(this.representative_serving_dom);
      bind_agent_type();
      bind_country();
      return verify_agent_type_country(selected_agent_type(), selected_country());
    };

    return AdminStore;

  })();

}).call(this);
