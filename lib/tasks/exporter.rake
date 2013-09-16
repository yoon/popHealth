namespace :export do
  desc 'Generate QRDA3 XML file for the measure specified via its nqf_id (e.g. 0438)'
  task :cat3_by_nqf_id do
    exporter = HealthDataStandards::Export::Cat3.new
    measure = HealthDataStandards::CQM::Measure.find_by({nqf_id: ENV['NQF_ID']})
    puts exporter.export([measure], Time.gm(2012, 12, 31), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
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
      puts "Exporting measure #{m.nqf_id}..."
      output = File.open("#{m.nqf_id}.cat3.xml", "w")
      output << exporter.export([m], Time.gm(2012, 12, 31), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
      output.close
    end
  end
end
