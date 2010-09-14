# db:migration replacment for mongoid. Since we don;t use RDBMS, there's no need to run db migrations, but sometimes we have to populate (insert) data, or mass update existing records.
# place those tasks here, and run +rake migrations:run+
namespace :migrations do |ns|
	
	# define migrations task below.
	desc "Populate Countries"
	task :populate_countries => :environment do
		FastererCSV.parse(countries, '"') do |row|
      Country.create(:iso_name => row['iso_name'], :iso => row['iso'], :name => row['name'], :iso3 => row['iso'], :numcode => row['numcode'])
    end
	end
	
	desc "set VAT value (17.5)"
	task :set_vat_value => :environment do
		SystemSetting.create :key => "vat", :value => "17.5"
	end
	
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
	
	def countries
		<<-CSV
"iso_name","iso","name","iso3","numcode"
"AFGHANISTAN","AF","Afghanistan","AFG",4
"ALBANIA","AL","Albania","ALB",8
"ALGERIA","DZ","Algeria","DZA",12
"AMERICAN SAMOA","AS","American Samoa","ASM",16
"ANDORRA","AD","Andorra","AND",20
"ANGOLA","AO","Angola","AGO",24
"ANGUILLA","AI","Anguilla","AIA",660
"ANTIGUA AND BARBUDA","AG","Antigua and Barbuda","ATG",28
"ARGENTINA","AR","Argentina","ARG",32
"ARMENIA","AM","Armenia","ARM",51
"ARUBA","AW","Aruba","ABW",533
"AUSTRALIA","AU","Australia","AUS",36
"AUSTRIA","AT","Austria","AUT",40
"AZERBAIJAN","AZ","Azerbaijan","AZE",31
"BAHAMAS","BS","Bahamas","BHS",44
"BAHRAIN","BH","Bahrain","BHR",48
"BANGLADESH","BD","Bangladesh","BGD",50
"BARBADOS","BB","Barbados","BRB",52
"BELARUS","BY","Belarus","BLR",112
"BELGIUM","BE","Belgium","BEL",56
"BELIZE","BZ","Belize","BLZ",84
"BENIN","BJ","Benin","BEN",204
"BERMUDA","BM","Bermuda","BMU",60
"BHUTAN","BT","Bhutan","BTN",64
"BOLIVIA","BO","Bolivia","BOL",68
"BOSNIA AND HERZEGOVINA","BA","Bosnia and Herzegovina","BIH",70
"BOTSWANA","BW","Botswana","BWA",72
"BRAZIL","BR","Brazil","BRA",76
"BRUNEI DARUSSALAM","BN","Brunei Darussalam","BRN",96
"BULGARIA","BG","Bulgaria","BGR",100
"BURKINA FASO","BF","Burkina Faso","BFA",854
"BURUNDI","BI","Burundi","BDI",108
"CAMBODIA","KH","Cambodia","KHM",116
"CAMEROON","CM","Cameroon","CMR",120
"CANADA","CA","Canada","CAN",124
"CAPE VERDE","CV","Cape Verde","CPV",132
"CAYMAN ISLANDS","KY","Cayman Islands","CYM",136
"CENTRAL AFRICAN REPUBLIC","CF","Central African Republic","CAF",140
"CHAD","TD","Chad","TCD",148
"CHILE","CL","Chile","CHL",152
"CHINA","CN","China","CHN",156
"COLOMBIA","CO","Colombia","COL",170
"COMOROS","KM","Comoros","COM",174
"CONGO","CG","Congo","COG",178
"CONGO, THE DEMOCRATIC REPUBLIC OF THE","CD","Congo, the Democratic Republic of the","COD",180
"COOK ISLANDS","CK","Cook Islands","COK",184
"COSTA RICA","CR","Costa Rica","CRI",188
"COTE D'IVOIRE","CI","Cote D'Ivoire","CIV",384
"CROATIA","HR","Croatia","HRV",191
"CUBA","CU","Cuba","CUB",192
"CYPRUS","CY","Cyprus","CYP",196
"CZECH REPUBLIC","CZ","Czech Republic","CZE",203
"DENMARK","DK","Denmark","DNK",208
"DJIBOUTI","DJ","Djibouti","DJI",262
"DOMINICA","DM","Dominica","DMA",212
"DOMINICAN REPUBLIC","DO","Dominican Republic","DOM",214
"ECUADOR","EC","Ecuador","ECU",218
"EGYPT","EG","Egypt","EGY",818
"EL SALVADOR","SV","El Salvador","SLV",222
"EQUATORIAL GUINEA","GQ","Equatorial Guinea","GNQ",226
"ERITREA","ER","Eritrea","ERI",232
"ESTONIA","EE","Estonia","EST",233
"ETHIOPIA","ET","Ethiopia","ETH",231
"FALKLAND ISLANDS (MALVINAS)","FK","Falkland Islands (Malvinas)","FLK",238
"FAROE ISLANDS","FO","Faroe Islands","FRO",234
"FIJI","FJ","Fiji","FJI",242
"FINLAND","FI","Finland","FIN",246
"FRANCE","FR","France","FRA",250
"FRENCH GUIANA","GF","French Guiana","GUF",254
"FRENCH POLYNESIA","PF","French Polynesia","PYF",258
"GABON","GA","Gabon","GAB",266
"GAMBIA","GM","Gambia","GMB",270
"GEORGIA","GE","Georgia","GEO",268
"GERMANY","DE","Germany","DEU",276
"GHANA","GH","Ghana","GHA",288
"GIBRALTAR","GI","Gibraltar","GIB",292
"GREECE","GR","Greece","GRC",300
"GREENLAND","GL","Greenland","GRL",304
"GRENADA","GD","Grenada","GRD",308
"GUADELOUPE","GP","Guadeloupe","GLP",312
"GUAM","GU","Guam","GUM",316
"GUATEMALA","GT","Guatemala","GTM",320
"GUINEA","GN","Guinea","GIN",324
"GUINEA-BISSAU","GW","Guinea-Bissau","GNB",624
"GUYANA","GY","Guyana","GUY",328
"HAITI","HT","Haiti","HTI",332
"HOLY SEE (VATICAN CITY STATE)","VA","Holy See (Vatican City State)","VAT",336
"HONDURAS","HN","Honduras","HND",340
"HONG KONG","HK","Hong Kong","HKG",344
"HUNGARY","HU","Hungary","HUN",348
"ICELAND","IS","Iceland","ISL",352
"INDIA","IN","India","IND",356
"INDONESIA","ID","Indonesia","IDN",360
"IRAN, ISLAMIC REPUBLIC OF","IR","Iran, Islamic Republic of","IRN",364
"IRAQ","IQ","Iraq","IRQ",368
"IRELAND","IE","Ireland","IRL",372
"ISRAEL","IL","Israel","ISR",376
"ITALY","IT","Italy","ITA",380
"JAMAICA","JM","Jamaica","JAM",388
"JAPAN","JP","Japan","JPN",392
"JORDAN","JO","Jordan","JOR",400
"KAZAKHSTAN","KZ","Kazakhstan","KAZ",398
"KENYA","KE","Kenya","KEN",404
"KIRIBATI","KI","Kiribati","KIR",296
"KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF","KP","North Korea","PRK",408
"KOREA, REPUBLIC OF","KR","South Korea","KOR",410
"KUWAIT","KW","Kuwait","KWT",414
"KYRGYZSTAN","KG","Kyrgyzstan","KGZ",417
"LAO PEOPLE'S DEMOCRATIC REPUBLIC","LA","Lao People's Democratic Republic","LAO",418
"LATVIA","LV","Latvia","LVA",428
"LEBANON","LB","Lebanon","LBN",422
"LESOTHO","LS","Lesotho","LSO",426
"LIBERIA","LR","Liberia","LBR",430
"LIBYAN ARAB JAMAHIRIYA","LY","Libyan Arab Jamahiriya","LBY",434
"LIECHTENSTEIN","LI","Liechtenstein","LIE",438
"LITHUANIA","LT","Lithuania","LTU",440
"LUXEMBOURG","LU","Luxembourg","LUX",442
"MACAO","MO","Macao","MAC",446
"MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF","MK","Macedonia","MKD",807
"MADAGASCAR","MG","Madagascar","MDG",450
"MALAWI","MW","Malawi","MWI",454
"MALAYSIA","MY","Malaysia","MYS",458
"MALDIVES","MV","Maldives","MDV",462
"MALI","ML","Mali","MLI",466
"MALTA","MT","Malta","MLT",470
"MARSHALL ISLANDS","MH","Marshall Islands","MHL",584
"MARTINIQUE","MQ","Martinique","MTQ",474
"MAURITANIA","MR","Mauritania","MRT",478
"MAURITIUS","MU","Mauritius","MUS",480
"MEXICO","MX","Mexico","MEX",484
"MICRONESIA, FEDERATED STATES OF","FM","Micronesia, Federated States of","FSM",583
"MOLDOVA, REPUBLIC OF","MD","Moldova, Republic of","MDA",498
"MONACO","MC","Monaco","MCO",492
"MONGOLIA","MN","Mongolia","MNG",496
"MONTSERRAT","MS","Montserrat","MSR",500
"MOROCCO","MA","Morocco","MAR",504
"MOZAMBIQUE","MZ","Mozambique","MOZ",508
"MYANMAR","MM","Myanmar","MMR",104
"NAMIBIA","NA","Namibia","NAM",516
"NAURU","NR","Nauru","NRU",520
"NEPAL","NP","Nepal","NPL",524
"NETHERLANDS","NL","Netherlands","NLD",528
"NETHERLANDS ANTILLES","AN","Netherlands Antilles","ANT",530
"NEW CALEDONIA","NC","New Caledonia","NCL",540
"NEW ZEALAND","NZ","New Zealand","NZL",554
"NICARAGUA","NI","Nicaragua","NIC",558
"NIGER","NE","Niger","NER",562
"NIGERIA","NG","Nigeria","NGA",566
"NIUE","NU","Niue","NIU",570
"NORFOLK ISLAND","NF","Norfolk Island","NFK",574
"NORTHERN MARIANA ISLANDS","MP","Northern Mariana Islands","MNP",580
"NORWAY","NO","Norway","NOR",578
"OMAN","OM","Oman","OMN",512
"PAKISTAN","PK","Pakistan","PAK",586
"PALAU","PW","Palau","PLW",585
"PANAMA","PA","Panama","PAN",591
"PAPUA NEW GUINEA","PG","Papua New Guinea","PNG",598
"PARAGUAY","PY","Paraguay","PRY",600
"PERU","PE","Peru","PER",604
"PHILIPPINES","PH","Philippines","PHL",608
"PITCAIRN","PN","Pitcairn","PCN",612
"POLAND","PL","Poland","POL",616
"PORTUGAL","PT","Portugal","PRT",620
"PUERTO RICO","PR","Puerto Rico","PRI",630
"QATAR","QA","Qatar","QAT",634
"REUNION","RE","Reunion","REU",638
"ROMANIA","RO","Romania","ROM",642
"RUSSIAN FEDERATION","RU","Russian Federation","RUS",643
"RWANDA","RW","Rwanda","RWA",646
"SAINT HELENA","SH","Saint Helena","SHN",654
"SAINT KITTS AND NEVIS","KN","Saint Kitts and Nevis","KNA",659
"SAINT LUCIA","LC","Saint Lucia","LCA",662
"SAINT PIERRE AND MIQUELON","PM","Saint Pierre and Miquelon","SPM",666
"SAINT VINCENT AND THE GRENADINES","VC","Saint Vincent and the Grenadines","VCT",670
"SAMOA","WS","Samoa","WSM",882
"SAN MARINO","SM","San Marino","SMR",674
"SAO TOME AND PRINCIPE","ST","Sao Tome and Principe","STP",678
"SAUDI ARABIA","SA","Saudi Arabia","SAU",682
"SENEGAL","SN","Senegal","SEN",686
"SEYCHELLES","SC","Seychelles","SYC",690
"SIERRA LEONE","SL","Sierra Leone","SLE",694
"SINGAPORE","SG","Singapore","SGP",702
"SLOVAKIA","SK","Slovakia","SVK",703
"SLOVENIA","SI","Slovenia","SVN",705
"SOLOMON ISLANDS","SB","Solomon Islands","SLB",90
"SOMALIA","SO","Somalia","SOM",706
"SOUTH AFRICA","ZA","South Africa","ZAF",710
"SPAIN","ES","Spain","ESP",724
"SRI LANKA","LK","Sri Lanka","LKA",144
"SUDAN","SD","Sudan","SDN",736
"SURINAME","SR","Suriname","SUR",740
"SVALBARD AND JAN MAYEN","SJ","Svalbard and Jan Mayen","SJM",744
"SWAZILAND","SZ","Swaziland","SWZ",748
"SWEDEN","SE","Sweden","SWE",752
"SWITZERLAND","CH","Switzerland","CHE",756
"SYRIAN ARAB REPUBLIC","SY","Syrian Arab Republic","SYR",760
"TAIWAN, PROVINCE OF CHINA","TW","Taiwan","TWN",158
"TAJIKISTAN","TJ","Tajikistan","TJK",762
"TANZANIA, UNITED REPUBLIC OF","TZ","Tanzania, United Republic of","TZA",834
"THAILAND","TH","Thailand","THA",764
"TOGO","TG","Togo","TGO",768
"TOKELAU","TK","Tokelau","TKL",772
"TONGA","TO","Tonga","TON",776
"TRINIDAD AND TOBAGO","TT","Trinidad and Tobago","TTO",780
"TUNISIA","TN","Tunisia","TUN",788
"TURKEY","TR","Turkey","TUR",792
"TURKMENISTAN","TM","Turkmenistan","TKM",795
"TURKS AND CAICOS ISLANDS","TC","Turks and Caicos Islands","TCA",796
"TUVALU","TV","Tuvalu","TUV",798
"UGANDA","UG","Uganda","UGA",800
"UKRAINE","UA","Ukraine","UKR",804
"UNITED ARAB EMIRATES","AE","United Arab Emirates","ARE",784
"UNITED KINGDOM","GB","United Kingdom","GBR",826
"UNITED STATES","US","United States","USA",840
"URUGUAY","UY","Uruguay","URY",858
"UZBEKISTAN","UZ","Uzbekistan","UZB",860
"VANUATU","VU","Vanuatu","VUT",548
"VENEZUELA","VE","Venezuela","VEN",862
"VIET NAM","VN","Viet Nam","VNM",704
"VIRGIN ISLANDS, BRITISH","VG","Virgin Islands, British","VGB",92
"VIRGIN ISLANDS, U.S.","VI","Virgin Islands, U.S.","VIR",850
"WALLIS AND FUTUNA","WF","Wallis and Futuna","WLF",876
"WESTERN SAHARA","EH","Western Sahara","ESH",732
"YEMEN","YE","Yemen","YEM",887
"ZAMBIA","ZM","Zambia","ZMB",894
"ZIMBABWE","ZW","Zimbabwe","ZWE",716
CSV
	end

end