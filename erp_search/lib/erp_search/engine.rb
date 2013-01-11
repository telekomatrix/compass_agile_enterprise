require 'sunspot_rails'

module ErpSearch
  class Engine < Rails::Engine
    isolate_namespace ErpSearch

    ActiveSupport.on_load(:active_record) do
      include ErpSearch::Extensions::ActiveRecord::HasDynamicSolrSearch
    end

    #add observers
	  #this is ugly need a better way
	  observers = [:party_observer, :contact_observer]
	  (config.active_record.observers.nil?) ? config.active_record.observers = observers : config.active_record.observers += observers

    ErpBaseErpSvcs.register_as_compass_ae_engine(config, self)
  end
end
