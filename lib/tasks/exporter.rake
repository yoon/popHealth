namespace :export do
  desc 'Generate QRDA3 XML file for the measure specified via its nqf_id (e.g. 0438)'
  task :cat3_by_nqf_id, [:nqf_id] => :environment do |t, args|
    puts args[:nqf_id]
    exporter = HealthDataStandards::Export::Cat3.new
    measure = HealthDataStandards::CQM::Measure.find_by({nqf_id: args[:nqf_id]})

    puts "Rails env: #{Rails.env}"
    puts "Exporting measure #{measure.nqf_id}.#{measure.hqmf_id}..."
    output = File.open("#{measure.nqf_id}.#{measure.hqmf_id}.cat3.xml", "w")
    output <<  exporter.export([measure], generate_header, Time.gm(2012, 12, 31), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
    output.close
  end
  
  desc 'Generate QRDA3 file for all specified measure types, and outputs it to STDOUT.'
  task :cat3 do
    exporter = HealthDataStandards::Export::Cat3.new
    
    measures = case ENV['MEASURE_TYPE']
      when "ep" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "ep"}
      when "eh" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "eh"}
      else           HealthDataStandards::CQM::Measure.all
    end
  
    measures.each do |m|
      puts "Exporting measure #{m.nqf_id}.#{m.hqmf_id}..."
      output = File.open("#{m.nqf_id}.#{m.hqmf_id}.cat3.xml", "w")
      output << exporter.export([m], generate_header, Time.gm(2012, 12, 31), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
      output.close
    end
  end

  def generate_header
   header_hash=  {identifier: {root: "1.2.3.4", extension: "header_ext"},
     authors: [{ids: [ {root: "2.16.840.1.113883.3.416" , extension: "health-data-standards-gem"}],
                  device: {name:"popHealth2" , model: "v2.1.2"},
                  addresses:[{
                    street:["MITRE Corporation","732 Robertson Rd"],
                    city:"South Elgin",
                    state:"IL",
                    zip:"60177",
                    country:"US"
                  }],
                  telecoms: [{
                    use:"WP",
                    value:"(847)608-7316"
                  }],
                  
                  time: Time.now,
                  organization: {ids: [ {root: "2.16.840.1.113883.3.1502" , extension: ""}],
                                  name: "mitre-org"}}],
     custodian: {ids: [ {root: "1.2.3.4" , extension: "custodian_ext"}],
                 person: {given: "Jeff", family: "Lunt"},
                 organization: {ids: [ {root: "1.2.3.4" , extension: "custodian_organization_ext"}],
                                name: ""}},
     legal_authenticator:{ids: [ {root: "1.2.3.4" , extension: "legal_authenticator_ext"}],
                          addresses: [],
                          telecoms:[],
                          time: Time.now,
                          person: {given:"hey", family: "there"},
                          organization:{ids: [ {root: "1.2.3.4" , extension: "legal_authenticator_org_ext"}],
                                        name: ""}
                          }
      }
    
    Qrda::Header.new(header_hash)
  end
end
