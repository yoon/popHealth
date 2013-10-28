require 'hqmf-parser'

namespace :export do
  desc 'Generate QRDA1 file for specified measures (HQMF_ID=<UUID>) and patient first name (FIRST=Jessica)'
  task :cat1 do
    puts "Rails env: #{Rails.env}"
    exporter = HealthDataStandards::Export::Cat1.new
    measures = []
    measure_ids = ENV['HQMF_ID'].split(',')
    patient = Record.find_by(first: ENV['FIRST'])
    puts "#{patient.class}: #{patient.id} - #{patient.first} #{patient.last}"

    if ENV['HQMF_ID']
      puts "Measure count: #{measure_ids.count}"
      measure_ids.each do |m_id|
        Mongoid.session(:default)['measures'].find({ hqmf_id: ENV['HQMF_ID'] }).each do |measure|
          measures << HQMF::Document.from_json(measure['hqmf_document'])
        end
      end
    elsif ENV['MEASURE_TYPE']
      measures = case ENV['MEASURE_TYPE']
        when "ep" then Mongoid.session(:default)['measures'].all.select{|m| m.type == "ep"}
        when "eh" then Mongoid.session(:default)['measures'].all.select{|m| m.type == "eh"}
        else           Mongoid.session(:default)['measures'].all
      end
    else
      choose do |menu|
        menu.prompt = "Which measures? "
        HealthDataStandards::CQM::Measure.all.group_by(&:nqf_id).sort.each do |nqf_id, ms|
          menu.choice(nqf_id){ measures = ms }
        end
        menu.choice(:q, "quit") { say "quitter"; exit }
      end
    end
    destination_dir = File.join(Rails.root, 'tmp', 'test_results')
    FileUtils.mkdir_p destination_dir
    puts "Exporting #{destination_dir}/#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat1.xml..."

    output = File.open(File.join(destination_dir, "#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat1.xml"), "w")
    output << exporter.export(patient, measures, Time.gm(2012,1,1, 23,59,00), Time.gm(2012,12,31, 23,59,00),)
    output.close
  end


  desc 'Generate QRDA3 file for specified measures (NQF_ID=0004,0038) or measure types (MEASURE_TYPE=[ep|eh])'
  task :cat3 do
    exporter = HealthDataStandards::Export::Cat3.new
    measures = []
    if ENV['NQF_ID']
      measures = HealthDataStandards::CQM::Measure.any_in({nqf_id: ENV['NQF_ID'].split(",")}).all
    elsif ENV['MEASURE_TYPE']
      measures = case ENV['MEASURE_TYPE']
        when "ep" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "ep"}
        when "eh" then HealthDataStandards::CQM::Measure.all.select{|m| m.type == "eh"}
        else           HealthDataStandards::CQM::Measure.all
      end
    else
      choose do |menu|
        menu.prompt = "Which measures? "
        HealthDataStandards::CQM::Measure.all.group_by(&:nqf_id).sort.each do |nqf_id, ms|
          menu.choice(nqf_id){ measures = ms }
        end
        menu.choice(:q, "quit") { say "quitter"; exit }
      end
    end
    destination_dir = File.join(Rails.root, 'tmp', 'test_results')
    FileUtils.mkdir_p destination_dir
    puts "Measures: #{measures.map(&:nqf_id).join(",")}"
    puts "Rails env: #{Rails.env}"
    puts "Exporting #{destination_dir}/#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat3.xml..."
    output = File.open(File.join(destination_dir, "#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat3.xml"), "w")
    output << exporter.export(measures, generate_header(Time.now), Time.gm(2012, 12, 31,23,59,00), Date.parse("2012-01-01"), Date.parse("2012-12-31"))
    output.close
  end

  def generate_header(time)
    Qrda::Header.new(YAML.load(File.read(File.join(Rails.root, 'config', 'qrda3_header.yml'))).deep_merge(legal_authenticator: {time: time}), authors: {time: time})
  end
end
