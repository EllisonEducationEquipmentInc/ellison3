# adds :cod_account_type, :cod_account attributes to Shippinglogic::FedEx::Rate::Service
Shippinglogic::FedEx::Rate::Service.class_exec {attr_accessor :cod_account, :cod_account_type}