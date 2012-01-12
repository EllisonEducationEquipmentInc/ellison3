class SubscriptionImporter
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :file_name
  field :complete, :type => Boolean, :default => false
  field :percent, :type => Integer, :default => 0
  field :total_count, :type => Integer, :default => 0
  field :system
  field :import_errors, :type => Array, :default => []
  
  validates_presence_of :file_name
  
  def initialize(attrs = nil)
    super
    set_current_system self.system || current_system
    self.total_count = File.readlines(file_name).count
  end
  
  def import_subscriptions
    n = 0
    CSV.foreach(self.file_name, :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      set_current_system list_to_system(row['list'])
      self.system = current_system
      get_list_and_segments
      @subscription = Subscription.first(:conditions => {:email => row['email'].downcase, :list => subscription_list}) || Subscription.new 
      @subscription.email = row['email'].downcase
      @subscription.confirmed = true
      @subscription.list = subscription_list
      @subscription.list_name = @list[1]
      @segments.keys.map(&:to_s).each do |segment|
        @subscription.segments << segment if row[segment] == "1"
      end
      @subscription.segments.uniq!
      if @subscription.save
        Rails.logger.info "===== #{@subscription.valid?} #{@subscription.email} #{@subscription.list} ===="
      	Rails.logger.info "sending id: #{@subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s}}"
        Lyris.delay.new :create_single_member, :email_address => @subscription.email, :list_name => @subscription.list, :full_name => @subscription.name
        Lyris.delay.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'normal'
        Lyris.delay.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s}
      else
        update_attribute :import_errors, self.import_errors << row['email']
        Rails.logger.info "!!! subscription record is invalid. #{@subscription.errors}"
      end
      n += 1
      percentage!(n)
    end
  rescue Exception => e
    @subscription.destroy if @subscription
    self.import_errors << e.message
    Rails.logger.error("#{e}")
  ensure
    completed!
  end

private

  def modulo
    m = self.total_count/10
    case 
    when m < 2
      2
    when m > 50
      50
    else
      m
    end
  end

  def percentage!(n)
    update_attribute(:percent, (n.to_f)/total_count*100) if n%modulo==0
  end

  def completed!
    self.complete = true
    self.percent = 100
    save!
    FileUtils.rm_f self.file_name
  end  
end
