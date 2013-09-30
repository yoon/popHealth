namespace :export do
  desc 'Generate QRDA3 file for specified measures (NQF_ID=0004,0038) or measure types (MEASURE_TYPE=[ep|eh])'
  task :cat3 do
    exporter = HealthDataStandards::Export::Cat3.new
    measures = []
    if ENV['NQF_ID']
      measures = HealthDataStandards::CQM::Measure.any_in({nqf_id: ENV['NQF_ID'].split(",")}).all
    else
      measures = case ENV['MEASURE_TYPE']
        when "ep" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "ep"}
        when "eh" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "eh"}
        else           HealthDataStandards::CQM::Measure.all
      end
    end
    Dir.mkdir(destination_dir = File.join(Rails.root, 'tmp', 'test_results'))
    puts "Measures: #{measures.map(&:nqf_id).join(",")}"
    puts "Rails env: #{Rails.env}"
    puts "Exporting #{destination_dir}/#{Time.now.strftime '%y-%m-%d_%H%M'}.cat3.xml..."
    output = File.open(File.join(destination_dir, "#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat3.xml"), "w")
    output << exporter.export(measures, generate_header, Time.gm(2012, 12, 31,23,59,00), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
    output.close
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
                  organization: {ids: [ {root: "2.16.840.1.113883.3.1502" , extension: "mitre-org"}],
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
