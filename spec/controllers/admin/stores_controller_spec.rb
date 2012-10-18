require 'spec_helper'

describe Admin::StoresController do
  let(:systems_enabled) { %w[szus szuk eeus eeuk erus] }
  let(:store_permission) { FactoryGirl.build(:permission, name: "stores", write: true, systems_enabled: systems_enabled) }
  let(:admin){ FactoryGirl.create(:admin_user, password: "test1234", permissions: [store_permission]) }
  let(:store){ double("as store") }

  before do
    sign_in admin
  end

  describe "GET index" do

    describe "when an Admin user is making any request" do
      before do
        get :index
      end

      it { should assign_to(:stores) }
      it { should render_template("index") }
    end

    context "when an Admin user is searching for a store" do
      before do
        stub_admin_acccess!

        @criteria = double('store criteria', where: double('where'))
        @criteria.should_receive(:order_by).and_return store

        store.should_receive(:paginate)

        @criteria.should_receive(:where).with({ :deleted_at => nil }).and_return @criteria
        @criteria.should_receive(:where).with({ :active => true }).and_return @criteria

        Mongoid::Criteria.should_receive(:new).and_return @criteria
      end

      describe "when an Admin is filtering by Physical Store" do
        it "filters the search by Physical Store" do
          @criteria.where.should_receive(:physical_stores).and_return @criteria
          get :index, physical_stores: 'Physical Store'
        end
      end

      describe "when an Admin is filtering by WebStore" do
        it "filters the search by WebStore" do
          @criteria.where.should_receive(:webstores).and_return @criteria
          get :index, webstores: 'WebStore'
        end
      end

      describe "when an Admin is filtering by Catalog Company" do
        it "filters the search by Catalog Company" do
          @criteria.where.should_receive(:catalog_companies).and_return @criteria
          get :index, catalog_company: 'Catalog Company'
        end
      end

      describe "when an Admin is filtering by Brands" do
        it "filters the search by Brands" do
          @criteria.should_receive(:where).with(:brands.in => ['Brands']).and_return @criteria
          get :index, brands: 'Brands'
        end
      end

      describe "when an Admin is filtering by Product Line" do
        it "filters the search by Product Line" do
          @criteria.should_receive(:where).with(:product_line.in => ['Product Line']).and_return @criteria
          get :index, product_line: 'Product Line'
        end
      end

      describe "when an Admin is filtering by Agent type" do
        it "filters the search by Agent type" do
          @criteria.should_receive(:where).with(:agent_type.in => ['Agent type']).and_return @criteria
          get :index, agent_type: 'Agent type'
        end
      end
    end
  end

  describe "GET new" do
    before do
      Store.should_receive(:new).with(:country => 'United States').and_return(store)
      get :new
    end

    it { should assign_to(:store).with(store) }
    it { should render_template("new") }
  end

  describe "POST create" do
    before do
      Store.should_receive(:new).with("name" => "foo name").and_return(store)
      controller.current_admin.should_receive(:email).and_return("example@example.com")
      store.should_receive(:created_by=).with("example@example.com")
      store.should_receive(:save).and_return(true)
      store.stub(to_param: "1010")
      post :create, store: { name: 'foo name' }
    end

    it { should assign_to(:store).with(store) }
    it { should redirect_to edit_admin_store_url(store) }
    it { should set_the_flash.to("Store was successfully created.") }
  end

  describe "PUT update" do
    before do
      Store.should_receive(:find).with('1afc').and_return(store)
      controller.current_admin.should_receive(:email).and_return("example@example.com")
      store.should_receive(:updated_by=).with("example@example.com")
      store.should_receive(:update_attributes).with("name" => "foo name").and_return(true)
      put :update, id: '1afc', store: { name: 'foo name' }
    end

    it { should assign_to(:store).with(store) }
    it { should redirect_to admin_stores_url }
    it { should set_the_flash.to("Store was successfully updated.") }
  end

  describe "DELETE destroy" do
    before do
      Store.should_receive(:find).with('1afc').and_return(store)
      store.should_receive(:destroy)
      delete :destroy, id: '1afc'
    end

    it { should assign_to(:store).with(store) }
    it { should redirect_to admin_stores_url }
  end
end
