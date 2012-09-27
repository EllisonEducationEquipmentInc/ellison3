require 'spec_helper'

describe Admin::StoresController do
  let(:systems_enabled) { %w[szus szuk eeus eeuk erus] }
  let(:store_permission) { FactoryGirl.build(:permission, name: "stores", write: true, systems_enabled: systems_enabled) }
  let(:admin){ FactoryGirl.create(:admin_user, password: "test1234", permissions: [store_permission]) }

  before do
    sign_in admin
  end

  describe "GET index" do
    before do
      get :index
    end

    it { should assign_to(:stores) }
    it { should render_template("index") }
  end

  describe "GET new" do
    before do
      @store = double("as store")
      Store.should_receive(:new).with(:country => 'United States').and_return(@store)
      get :new
    end

    it { should assign_to(:store).with(@store) }
    it { should render_template("new") }
  end

  describe "POST create" do
    before do
      @store = double("as store")
      Store.should_receive(:new).with("name" => "foo name").and_return(@store)
      controller.current_admin.should_receive(:email).and_return("example@example.com")
      @store.should_receive(:created_by=).with("example@example.com")
      @store.should_receive(:save).and_return(true)
      post :create, store: { name: 'foo name' }
    end

    it { should assign_to(:store).with(@store) }
    it { should redirect_to edit_admin_store_url(@store) }
    it { should set_the_flash.to("Store was successfully created.") }
  end

  describe "PUT update" do
    before do
      @store = double("as store")
      Store.should_receive(:find).with('1afc').and_return(@store)
      controller.current_admin.should_receive(:email).and_return("example@example.com")
      @store.should_receive(:updated_by=).with("example@example.com")
      @store.should_receive(:update_attributes).with("name" => "foo name").and_return(true)
      put :update, id: '1afc', store: { name: 'foo name' }
    end

    it { should assign_to(:store).with(@store) }
    it { should redirect_to admin_stores_url }
    it { should set_the_flash.to("Store was successfully updated.") }
  end

  describe "DELETE destroy" do
    before do
      @store = double("as store")
      Store.should_receive(:find).with('1afc').and_return(@store)
      @store.should_receive(:destroy)
      delete :destroy, id: '1afc'
    end

    it { should assign_to(:store).with(@store) }
    it { should redirect_to admin_stores_url }
  end
end
