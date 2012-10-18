class UpdateEnabledSystemsAllStores < Mongoid::Migration
  def self.up

    Store.all.each do |store|

      agent_type = store.agent_type
      brands = store.brands.map(&:upcase)
      sites_enabled = store.systems_enabled

      if agent_type == "Authorized Reseller" && brands.include?("SIZZIX")
        store.systems_enabled = sites_enabled.push('szus', 'szuk').uniq - ["erus"]
        store.save(:validate => false)
      end

      if agent_type == "Authorized Reseller" && brands.include?("ELLISON")
        store.systems_enabled = sites_enabled.push('eeus', 'eeuk').uniq - ["erus"]
        store.save(:validate => false)
      end

      if agent_type == "Distributor" || agent_type == "Sales Representative"
        store.systems_enabled = ["erus"]
        store.save(:validate => false)
      end
    end

  end

  def self.down

    Store.all.each do |store|
      agent_type = store.agent_type
      brands = store.brands.map(&:upcase)

      if agent_type == "Authorized Reseller" && brands.include?("SIZZIX")
        store.systems_enabled = store.systems_enabled - [ 'szus', 'szuk' ]
        store.save(:validate => false)
      end

      if agent_type == "Authorized Reseller" && brands.include?("ELLISON")
        store.systems_enabled = store.systems_enabled - [ 'eeus', 'eeuk' ]
        store.save(:validate => false)
      end

      if agent_type == "Distributor" || agent_type == "Sales Representative"
        store.systems_enabled = store.systems_enabled - [ 'erus' ]
        store.save(:validate => false)
      end
    end

  end
end