# db:migration replacment for mongoid. Since we don't use RDBMS, there's no need to run db migrations, but sometimes we have to populate (insert) data, or mass update existing records.
# place those tasks here, and run +rake migrations:run+
namespace :migrations do |ns|
	
	#======== define migration tasks below: ========
	
	desc "Populate Countries"
	task :populate_countries => :environment do
		CSV.parse(iso_countries, :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      Country.create(:iso_name => row['iso_name'], :iso => row['iso'], :name => row['name'], :iso3 => row['iso3'], :numcode => row['numcode'], :vat_exempt => row['vat_exempt'], :gbp => row['gbp'])
    end
	end
	
	desc "set VAT value (20.0%)"
	task :set_vat_value => :environment do
		SystemSetting.create :key => "vat", :value => "20.0"
	end
	
	desc "setup countries for systems"
	task :setup_countries => :environment do
	  us = Country.find_by_name("United States")
	  us.update_attributes :systems_enabled => ["szus", "eeus", "erus"]
	  eu_countries = Country.where(:name.in => ["Austria", "Belgium", "Bulgaria", "Croatia", "Czech Republic", "Denmark", "Estonia", "Finland", "France", "Germany", "Greece", "Hungary", "Italy", "Latvia", "Lithuania", "Luxembourg", "Netherlands", "Norway", "Poland", "Portugal", "Romania", "Slovakia", "Slovenia", "Spain", "Switzerland", "United Kingdom", "Isle of Man", "Northern Ireland", "Guernsey", "Jersey", "Sweden", "Ireland"])
	  eu_countries.each {|e| e.update_attributes(:systems_enabled => ["szuk", "eeuk", "erus"])}
	  all_other_countries = Country.where(:systems_enabled => nil)
	  all_other_countries.each {|e| e.update_attributes(:systems_enabled => ["erus"])}
	end
	
	desc "puts US and UK to the top of country list"
	task :country_display_order => :environment do
	  Country.all.each {|e| e.update_attributes(:display_order => 300)}
	  Country.find_by_name("United States").update_attributes :display_order => 1
	  Country.find_by_name("United Kingdom").update_attributes :display_order => 2
	end
	
	desc "populate fedex zones"
	task :fedex_zones => :environment do
	  FedexZone.delete_all
	  CSV.parse(fedex_zones_csv, :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      FedexZone.create(:zip_start => tozip(row['zip'])[0], :zip_end => tozip(row['zip'])[1], :zone => row['zone'], :express_zone => row['express_zone'])
    end
	end
	
	desc "populate UK shipping rates"
	task :uk_shipping_rates => :environment do
	  set_current_system "szuk"
	  Country.send("szuk").each do |country|
	    sz_rate_1 = ShippingRate.new(:price_min_gbp => 0.0, :price_max_gbp => 74.99, :price_min_eur => 0.0, :price_max_eur => 145.01, :standard_rate_gbp => country.gbp ? 5.91 : 14.10, :standard_rate_eur => 15.65, :system => "szuk", :zone_or_country => country.name)
	    sz_rate_2 = ShippingRate.new(:price_min_gbp => 75.0, :price_max_gbp => 10000000, :price_min_eur => 145.02, :price_max_eur => 10000000, :standard_rate_gbp => country.gbp ? 0.0 : 17.11, :standard_rate_eur => 19.13, :system => "szuk", :zone_or_country => country.name)
	    sz_rate_1.save!
	    sz_rate_2.save!
	    ee_rate_1 = sz_rate_1.clone
	    ee_rate_2 = sz_rate_2.clone
	    ee_rate_1.identify
	    ee_rate_2.identify
	    ee_rate_1.system = ee_rate_2.system = "eeuk"
	    ee_rate_1.new_record = ee_rate_2.new_record = true
	    ee_rate_1.save!
	    ee_rate_2.save!
	  end
	  set_current_system "szus"
	end
	
	desc "populate retailer discount matrix"
	task :discount_matrix => :environment do
	  @matrix = CSV.open(File.expand_path(File.dirname(__FILE__) + "/migrations/discount_matrix.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"').to_a
	  CSV.foreach(File.expand_path(File.dirname(__FILE__) + "/migrations/discount_categories.csv"), :headers => true, :row_sep => :auto, :skip_blanks => true, :quote_char => '"') do |row|
      @discount_category = DiscountCategory.new(:name => row["name"], :old_id => row["id"])
      RetailerDiscountLevels.instance.levels.each do |level|
        @discount_category.send("discount_#{level.id}=", @matrix.detect {|e| e["discount_level_id"] == "#{level.id}" && e["discount_category_id"] == row["id"]}["discount"])
      end
      @discount_category.save!
	  end
	end
	
	desc "set order number sequence to start from 1000000"
	task :order_number_sequence => :environment do
	  o=Order.new
	  o.valid?
	  h=Mongoid::Sequence::Holder.last
	  h.seq = 1000000
    p h.save
	end
	
	desc "create grade level tags"
	task :grade_levels => :environment do
    set_current_system "eeus"
	  ["Pre-K", "K-2", "3-5", "6-8", "9-12"].each do |grade|
	    p Tag.create :name => grade, :tag_type => 'grade_level', :systems_enabled => ["eeus", "erus"], :start_date_eeus => 1.year.ago, :end_date_eeus => 30.years.since
	  end
	end
	
	
	#======== migration tasks end here ========
	
	desc "run all migrations that haven't run"
	task :run => :environment do |t|
		@tasks = Migration.all.map {|m| m.name}
		@tasks << t.name
		ns.tasks.reject {|task| @tasks.include? task.name}.each { |e| e.execute; completed(e) }
	end
	
	# when task is completed, we create a Migration record in the db, so the task won't run again
	def completed(t)
		Migration.create(:name => t.name.to_s)
		p "#{t.name} ran successfully..."
	end
	
  def tozip(z)
    if z =~ /^\d{5}$/
      return [z.to_i, z.to_i]
    elsif z =~ /^\d{3}-\d{3}$/
      a=z.split("-")
      return [a[0].to_i*100, a[1].to_i*100 +99]
    elsif z =~ /^\d{3}$/
      return [z.to_i*100, z.to_i*100 +99]
    else
      a=z.split("-")
      a=a.map {|e| to_five(e)}
      a.length < 2 ? [a[0], a[0]+999 ] : a
    end
  end

  def to_five(z)
    z.to_i < 1000 ? z.to_i * 100 : z.to_i
  end
  
  def fedex_zones_csv
    <<-CSV
"zip","zone","express_zone"
"005","8",
"010-212","8",
"214-268","8",
"270-324","8",
"325","7",
"326-342","8",
"344","8",
"346-347","8",
"349","8",
"350-352","7",
"354-359","7",
"360-363","8",
"364-367","7",
"368","8",
"369-372","7",
"373-374","8",
"375","7",
"376-379","8",
"380-397","7",
"398-399","8",
"400-402","7",
"403-418","8",
"420-424","7",
"425-426","8",
"427","7",
"430-459","8",
"460-466","7",
"467-468","8",
"469","7",
"470","8",
"471-472","7",
"473","8",
"474-479","7",
"480-497","8",
"498-499","7",
"500-503","6",
"504","7",
"505","6",
"506-507","7",
"508-516","6",
"520-528","7",
"530-532","7",
"534-535","7",
"537-551","7",
"553-560","7",
"561","6",
"562-567","7",
"570-577","6",
"580-581","6",
"582","7",
"583-588","6",
"590-591","5",
"592-595","6",
"596-599","5",
"600-620","7",
"622-631","7",
"633-639","7",
"640-641","6",
"644-649","6",
"650-652","7",
"653","6",
"654-655","7",
"656-658","6",
"660-662","6",
"664-676","6",
"677-679","5",
"680-681","6",
"683-692","6",
"693","5",
"700-701","7",
"703-708","7",
"710-711","6",
"712-714","7",
"716-717","7",
"718-719","6",
"720-725","7",
"726-731","6",
"733-738","6",
"739","5",
"740-741","6",
"743-789","6",
"790-794","5",
"795-796","6",
"797-812","5",
"813","4",
"814-816","5",
"820-838","5",
"840-847","4",
"850","4",
"851","4",
"852-853","4",
"855-857","4",
"859-860","4",
"863","4",
"864","3",
"865","4",
"870-872","5",
"873-874","4",
"875","5",
"877-878","5",
"879","4",
"880-885","5",
"889-891","3",
"893-895","4",
"897-898","4",
"900-908","2",
"910-928","2",
"930-933","2",
"934","3",
"935","2",
"936-939","3",
"940-966","4",
"970-986","5",
"988-994","5",
"006-007","10",
"009","10",
"96700","9","12"
"96701","9","10"
"96702-96705","9","12"
"96706-96707","9","10"
"96708","9","12"
"96709","9","10"
"96710","9","12"
"96711-96712","9","10"
"96713-96716","9","12"
"96717","9","10"
"96718-96729","9","12"
"96730-96731","9","10"
"96732-96733","9","12"
"96734","9","10"
"96735-96743","9","12"
"96744","9","10"
"96745-96757","9","12"
"96758-96759","9","10"
"96760-96761","9","12"
"96762","9","10"
"96763-96774","9","12"
"96775","9","10"
"96776-96781","9","12"
"96782","9","10"
"96783-96788","9","12"
"96789","9","10"
"96790","9","12"
"96791-96792","9","10"
"96793","9","12"
"96794-96795","9","10"
"96796","9","12"
"96797","9","10"
"96798","9","12"
"96800","9","12"
"96801-96863","9","10"
"96864-96899","9","12"
"99500","17","11"
"99501-99524","17","9"
"99525-99539","17","11"
"99540","17","9"
"99541-99566","17","11"
"99567","17","9"
"99568-99576","17","11"
"99577","17","9"
"99578-99999","17","11"
CSV
  end
	
	def iso_countries
		<<-CSV
"iso_name","iso","name","iso3","numcode","vat_exempt","gbp"
"AFGHANISTAN","AF","Afghanistan","AFG",4,1,0
"ALBANIA","AL","Albania","ALB",8,1,0
"ALGERIA","DZ","Algeria","DZA",12,1,0
"AMERICAN SAMOA","AS","American Samoa","ASM",16,1,0
"ANDORRA","AD","Andorra","AND",20,1,0
"ANGOLA","AO","Angola","AGO",24,1,0
"ANGUILLA","AI","Anguilla","AIA",660,1,0
"ANTIGUA AND BARBUDA","AG","Antigua and Barbuda","ATG",28,1,0
"ARGENTINA","AR","Argentina","ARG",32,1,0
"ARMENIA","AM","Armenia","ARM",51,1,0
"ARUBA","AW","Aruba","ABW",533,1,0
"AUSTRALIA","AU","Australia","AUS",36,1,0
"AUSTRIA","AT","Austria","AUT",40,0,0
"AZERBAIJAN","AZ","Azerbaijan","AZE",31,1,0
"BAHAMAS","BS","Bahamas","BHS",44,1,0
"BAHRAIN","BH","Bahrain","BHR",48,1,0
"BANGLADESH","BD","Bangladesh","BGD",50,1,0
"BARBADOS","BB","Barbados","BRB",52,1,0
"BELARUS","BY","Belarus","BLR",112,1,0
"BELGIUM","BE","Belgium","BEL",56,0,0
"BELIZE","BZ","Belize","BLZ",84,1,0
"BENIN","BJ","Benin","BEN",204,1,0
"BERMUDA","BM","Bermuda","BMU",60,1,0
"BHUTAN","BT","Bhutan","BTN",64,1,0
"BOLIVIA","BO","Bolivia","BOL",68,1,0
"BOSNIA AND HERZEGOVINA","BA","Bosnia and Herzegovina","BIH",70,1,0
"BOTSWANA","BW","Botswana","BWA",72,1,0
"BRAZIL","BR","Brazil","BRA",76,1,0
"BRUNEI DARUSSALAM","BN","Brunei Darussalam","BRN",96,1,0
"BULGARIA","BG","Bulgaria","BGR",100,0,0
"BURKINA FASO","BF","Burkina Faso","BFA",854,1,0
"BURUNDI","BI","Burundi","BDI",108,1,0
"CAMBODIA","KH","Cambodia","KHM",116,1,0
"CAMEROON","CM","Cameroon","CMR",120,1,0
"CANADA","CA","Canada","CAN",124,1,0
"CAPE VERDE","CV","Cape Verde","CPV",132,1,0
"CAYMAN ISLANDS","KY","Cayman Islands","CYM",136,1,0
"CENTRAL AFRICAN REPUBLIC","CF","Central African Republic","CAF",140,1,0
"CHAD","TD","Chad","TCD",148,1,0
"CHILE","CL","Chile","CHL",152,1,0
"CHINA","CN","China","CHN",156,1,0
"COLOMBIA","CO","Colombia","COL",170,1,0
"COMOROS","KM","Comoros","COM",174,1,0
"CONGO","CG","Congo","COG",178,1,0
"CONGO, THE DEMOCRATIC REPUBLIC OF THE","CD","Congo, the Democratic Republic of the","COD",180,1,0
"COOK ISLANDS","CK","Cook Islands","COK",184,1,0
"COSTA RICA","CR","Costa Rica","CRI",188,1,0
"COTE D'IVOIRE","CI","Cote D'Ivoire","CIV",384,1,0
"CROATIA","HR","Croatia","HRV",191,1,0
"CUBA","CU","Cuba","CUB",192,1,0
"CYPRUS","CY","Cyprus","CYP",196,0,0
"CZECH REPUBLIC","CZ","Czech Republic","CZE",203,0,0
"DENMARK","DK","Denmark","DNK",208,0,0
"DJIBOUTI","DJ","Djibouti","DJI",262,1,0
"DOMINICA","DM","Dominica","DMA",212,1,0
"DOMINICAN REPUBLIC","DO","Dominican Republic","DOM",214,1,0
"ECUADOR","EC","Ecuador","ECU",218,1,0
"EGYPT","EG","Egypt","EGY",818,1,0
"EL SALVADOR","SV","El Salvador","SLV",222,1,0
"EQUATORIAL GUINEA","GQ","Equatorial Guinea","GNQ",226,1,0
"ERITREA","ER","Eritrea","ERI",232,1,0
"ESTONIA","EE","Estonia","EST",233,0,0
"ETHIOPIA","ET","Ethiopia","ETH",231,1,0
"FALKLAND ISLANDS (MALVINAS)","FK","Falkland Islands (Malvinas)","FLK",238,1,0
"FAROE ISLANDS","FO","Faroe Islands","FRO",234,1,0
"FIJI","FJ","Fiji","FJI",242,1,0
"FINLAND","FI","Finland","FIN",246,0,0
"FRANCE","FR","France","FRA",250,0,0
"FRENCH GUIANA","GF","French Guiana","GUF",254,1,0
"FRENCH POLYNESIA","PF","French Polynesia","PYF",258,1,0
"GABON","GA","Gabon","GAB",266,1,0
"GAMBIA","GM","Gambia","GMB",270,1,0
"GEORGIA","GE","Georgia","GEO",268,1,0
"GERMANY","DE","Germany","DEU",276,0,0
"GHANA","GH","Ghana","GHA",288,1,0
"GIBRALTAR","GI","Gibraltar","GIB",292,1,0
"GREECE","GR","Greece","GRC",300,0,0
"GREENLAND","GL","Greenland","GRL",304,1,0
"GRENADA","GD","Grenada","GRD",308,1,0
"GUADELOUPE","GP","Guadeloupe","GLP",312,1,0
"GUAM","GU","Guam","GUM",316,1,0
"GUATEMALA","GT","Guatemala","GTM",320,1,0
"GUERNSEY","GG","Guernsey","GGY",826,1,1
"GUINEA","GN","Guinea","GIN",324,1,0
"GUINEA-BISSAU","GW","Guinea-Bissau","GNB",624,1,0
"GUYANA","GY","Guyana","GUY",328,1,0
"HAITI","HT","Haiti","HTI",332,1,0
"HOLY SEE (VATICAN CITY STATE)","VA","Holy See (Vatican City State)","VAT",336,1,0
"HONDURAS","HN","Honduras","HND",340,1,0
"HONG KONG","HK","Hong Kong","HKG",344,1,0
"HUNGARY","HU","Hungary","HUN",348,0,0
"ICELAND","IS","Iceland","ISL",352,1,0
"INDIA","IN","India","IND",356,1,0
"INDONESIA","ID","Indonesia","IDN",360,1,0
"IRAN, ISLAMIC REPUBLIC OF","IR","Iran, Islamic Republic of","IRN",364,1,0
"IRAQ","IQ","Iraq","IRQ",368,1,0
"IRELAND","IE","Ireland","IRL",372,0,0
"ISLE OF MAN","IM","Isle of Man","IMN",826,0,1
"ISRAEL","IL","Israel","ISR",376,1,0
"ITALY","IT","Italy","ITA",380,0,0
"JAMAICA","JM","Jamaica","JAM",388,1,0
"JAPAN","JP","Japan","JPN",392,1,0
"JERSEY","JE","Jersey","JEY",826,1,1
"JORDAN","JO","Jordan","JOR",400,1,0
"KAZAKHSTAN","KZ","Kazakhstan","KAZ",398,1,0
"KENYA","KE","Kenya","KEN",404,1,0
"KIRIBATI","KI","Kiribati","KIR",296,1,0
"KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF","KP","North Korea","PRK",408,1,0
"KOREA, REPUBLIC OF","KR","South Korea","KOR",410,1,0
"KUWAIT","KW","Kuwait","KWT",414,1,0
"KYRGYZSTAN","KG","Kyrgyzstan","KGZ",417,1,0
"LAO PEOPLE'S DEMOCRATIC REPUBLIC","LA","Lao People's Democratic Republic","LAO",418,1,0
"LATVIA","LV","Latvia","LVA",428,0,0
"LEBANON","LB","Lebanon","LBN",422,1,0
"LESOTHO","LS","Lesotho","LSO",426,1,0
"LIBERIA","LR","Liberia","LBR",430,1,0
"LIBYAN ARAB JAMAHIRIYA","LY","Libyan Arab Jamahiriya","LBY",434,1,0
"LIECHTENSTEIN","LI","Liechtenstein","LIE",438,1,0
"LITHUANIA","LT","Lithuania","LTU",440,0,0
"LUXEMBOURG","LU","Luxembourg","LUX",442,0,0
"MACAO","MO","Macao","MAC",446,1,0
"MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF","MK","Macedonia","MKD",807,1,0
"MADAGASCAR","MG","Madagascar","MDG",450,1,0
"MALAWI","MW","Malawi","MWI",454,1,0
"MALAYSIA","MY","Malaysia","MYS",458,1,0
"MALDIVES","MV","Maldives","MDV",462,1,0
"MALI","ML","Mali","MLI",466,1,0
"MALTA","MT","Malta","MLT",470,0,0
"MARSHALL ISLANDS","MH","Marshall Islands","MHL",584,1,0
"MARTINIQUE","MQ","Martinique","MTQ",474,1,0
"MAURITANIA","MR","Mauritania","MRT",478,1,0
"MAURITIUS","MU","Mauritius","MUS",480,1,0
"MEXICO","MX","Mexico","MEX",484,1,0
"MICRONESIA, FEDERATED STATES OF","FM","Micronesia, Federated States of","FSM",583,1,0
"MOLDOVA, REPUBLIC OF","MD","Moldova, Republic of","MDA",498,1,0
"MONACO","MC","Monaco","MCO",492,1,0
"MONGOLIA","MN","Mongolia","MNG",496,1,0
"MONTSERRAT","MS","Montserrat","MSR",500,1,0
"MOROCCO","MA","Morocco","MAR",504,1,0
"MOZAMBIQUE","MZ","Mozambique","MOZ",508,1,0
"MYANMAR","MM","Myanmar","MMR",104,1,0
"NAMIBIA","NA","Namibia","NAM",516,1,0
"NAURU","NR","Nauru","NRU",520,1,0
"NEPAL","NP","Nepal","NPL",524,1,0
"NETHERLANDS","NL","Netherlands","NLD",528,0,0
"NETHERLANDS ANTILLES","AN","Netherlands Antilles","ANT",530,1,0
"NEW CALEDONIA","NC","New Caledonia","NCL",540,1,0
"NEW ZEALAND","NZ","New Zealand","NZL",554,1,0
"NICARAGUA","NI","Nicaragua","NIC",558,1,0
"NIGER","NE","Niger","NER",562,1,0
"NIGERIA","NG","Nigeria","NGA",566,1,0
"NIUE","NU","Niue","NIU",570,1,0
"NORFOLK ISLAND","NF","Norfolk Island","NFK",574,1,0
"NORTHERN MARIANA ISLANDS","MP","Northern Mariana Islands","MNP",580,1,0
"NORWAY","NO","Norway","NOR",578,1,0
"OMAN","OM","Oman","OMN",512,1,0
"PAKISTAN","PK","Pakistan","PAK",586,1,0
"PALAU","PW","Palau","PLW",585,1,0
"PANAMA","PA","Panama","PAN",591,1,0
"PAPUA NEW GUINEA","PG","Papua New Guinea","PNG",598,1,0
"PARAGUAY","PY","Paraguay","PRY",600,1,0
"PERU","PE","Peru","PER",604,1,0
"PHILIPPINES","PH","Philippines","PHL",608,1,0
"PITCAIRN","PN","Pitcairn","PCN",612,1,0
"POLAND","PL","Poland","POL",616,0,0
"PORTUGAL","PT","Portugal","PRT",620,0,0
"PUERTO RICO","PR","Puerto Rico","PRI",630,1,0
"QATAR","QA","Qatar","QAT",634,1,0
"REUNION","RE","Reunion","REU",638,1,0
"ROMANIA","RO","Romania","ROM",642,0,0
"RUSSIAN FEDERATION","RU","Russian Federation","RUS",643,1,0
"RWANDA","RW","Rwanda","RWA",646,1,0
"SAINT HELENA","SH","Saint Helena","SHN",654,1,0
"SAINT KITTS AND NEVIS","KN","Saint Kitts and Nevis","KNA",659,1,0
"SAINT LUCIA","LC","Saint Lucia","LCA",662,1,0
"SAINT PIERRE AND MIQUELON","PM","Saint Pierre and Miquelon","SPM",666,1,0
"SAINT VINCENT AND THE GRENADINES","VC","Saint Vincent and the Grenadines","VCT",670,1,0
"SAMOA","WS","Samoa","WSM",882,1,0
"SAN MARINO","SM","San Marino","SMR",674,1,0
"SAO TOME AND PRINCIPE","ST","Sao Tome and Principe","STP",678,1,0
"SAUDI ARABIA","SA","Saudi Arabia","SAU",682,1,0
"SENEGAL","SN","Senegal","SEN",686,1,0
"SEYCHELLES","SC","Seychelles","SYC",690,1,0
"SIERRA LEONE","SL","Sierra Leone","SLE",694,1,0
"SINGAPORE","SG","Singapore","SGP",702,1,0
"SLOVAKIA","SK","Slovakia","SVK",703,0,0
"SLOVENIA","SI","Slovenia","SVN",705,0,0
"SOLOMON ISLANDS","SB","Solomon Islands","SLB",90,1,0
"SOMALIA","SO","Somalia","SOM",706,1,0
"SOUTH AFRICA","ZA","South Africa","ZAF",710,1,0
"SPAIN","ES","Spain","ESP",724,0,0
"SRI LANKA","LK","Sri Lanka","LKA",144,1,0
"SUDAN","SD","Sudan","SDN",736,1,0
"SURINAME","SR","Suriname","SUR",740,1,0
"SVALBARD AND JAN MAYEN","SJ","Svalbard and Jan Mayen","SJM",744,1,0
"SWAZILAND","SZ","Swaziland","SWZ",748,1,0
"SWEDEN","SE","Sweden","SWE",752,0,0
"SWITZERLAND","CH","Switzerland","CHE",756,1,0
"SYRIAN ARAB REPUBLIC","SY","Syrian Arab Republic","SYR",760,1,0
"TAIWAN, PROVINCE OF CHINA","TW","Taiwan","TWN",158,1,0
"TAJIKISTAN","TJ","Tajikistan","TJK",762,1,0
"TANZANIA, UNITED REPUBLIC OF","TZ","Tanzania, United Republic of","TZA",834,1,0
"THAILAND","TH","Thailand","THA",764,1,0
"TOGO","TG","Togo","TGO",768,1,0
"TOKELAU","TK","Tokelau","TKL",772,1,0
"TONGA","TO","Tonga","TON",776,1,0
"TRINIDAD AND TOBAGO","TT","Trinidad and Tobago","TTO",780,1,0
"TUNISIA","TN","Tunisia","TUN",788,1,0
"TURKEY","TR","Turkey","TUR",792,1,0
"TURKMENISTAN","TM","Turkmenistan","TKM",795,1,0
"TURKS AND CAICOS ISLANDS","TC","Turks and Caicos Islands","TCA",796,1,0
"TUVALU","TV","Tuvalu","TUV",798,1,0
"UGANDA","UG","Uganda","UGA",800,1,0
"UKRAINE","UA","Ukraine","UKR",804,1,0
"UNITED ARAB EMIRATES","AE","United Arab Emirates","ARE",784,1,0
"UNITED KINGDOM","GB","United Kingdom","GBR",826,0,1
"UNITED STATES","US","United States","USA",840,1,0
"URUGUAY","UY","Uruguay","URY",858,1,0
"UZBEKISTAN","UZ","Uzbekistan","UZB",860,1,0
"VANUATU","VU","Vanuatu","VUT",548,1,0
"VENEZUELA","VE","Venezuela","VEN",862,1,0
"VIET NAM","VN","Viet Nam","VNM",704,1,0
"VIRGIN ISLANDS, BRITISH","VG","Virgin Islands, British","VGB",92,1,0
"VIRGIN ISLANDS, U.S.","VI","Virgin Islands, U.S.","VIR",850,1,0
"WALLIS AND FUTUNA","WF","Wallis and Futuna","WLF",876,1,0
"WESTERN SAHARA","EH","Western Sahara","ESH",732,1,0
"YEMEN","YE","Yemen","YEM",887,1,0
"ZAMBIA","ZM","Zambia","ZMB",894,1,0
"ZIMBABWE","ZW","Zimbabwe","ZWE",716,1,0
CSV
	end

end