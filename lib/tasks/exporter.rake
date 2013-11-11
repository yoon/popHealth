require 'hqmf-parser'

namespace :export do
  desc 'Generate QRDA CAT1 files for all patients, then copy them into sub-folders by HQMF_ID where each patient is part of the IPP for that measure.'
  task :cat1 do
    puts "Rails env: #{Rails.env}"
    exporter = HealthDataStandards::Export::Cat1.new
    mongo_session = Mongoid.session(:default)

    measures = []
    hqmf_ids = HealthDataStandards::CQM::Measure.all.collect{|m| m.hqmf_id }.uniq
    hqmf_ids.each_with_index do |hqmf_id, index|
      print "\rParsing #{hqmf_ids.length} HQMF documents: (#{index+1}) #{hqmf_id}"

      mongo_session['measures'].find({ hqmf_id: hqmf_id }).each do |measure|
        measures << HQMF::Document.from_json(measure['hqmf_document'])
      end
    end
    puts "\rParsing #{hqmf_ids.length} HQMF documents: DONE                                     "

    print "Loading #{mongo_session['patient_cache'].find.count} patient cache objects..."
    patient_cache_values = mongo_session['patient_cache'].find.collect{|pc| pc['value'] }
    puts "\rLoading #{mongo_session['patient_cache'].find.count} patient cache objects...DONE"

    print "Generating #{Record.all.count} CAT1 files:"
    all_patient_records = Record.all
    base_cat1_dir = File.join(Rails.root, 'tmp', 'cat1-exports')
    FileUtils.rm_rf(File.join(base_cat1_dir))
    all_patient_records.each_with_index do |patient, index|
      FileUtils.mkdir_p(base_cat1_dir)
      export_filename = "#{base_cat1_dir}/#{patient.last.downcase}-#{patient.first.downcase}.cat1.xml"

      print "\rGenerating #{Record.all.count} CAT1 files: (#{index+1}) #{export_filename}                                        "
      output = File.open(export_filename, "w")
      output << exporter.export(patient, measures, Time.gm(2012,1,1, 23,59,00), Time.gm(2012,12,31, 23,59,00),)
      output.close
      
    end
    puts "\rGenerating #{Record.all.count} CAT1 files: (DONE)                                                                    "

    print "Copying files"
    measures.each do |measure|
      per_measure_dir = File.join(Rails.root, 'tmp', 'cat1-exports', measure.hqmf_id)
      FileUtils.mkdir_p(per_measure_dir)
      all_patient_records.each do |patient|
        pcvs_where_patient_is_in_ipp = patient_cache_values.select do |pcv|
          pcv['IPP'] == 1 &&
          pcv['medical_record_id'] == patient.medical_record_number &&
          measure.hqmf_id == pcv['measure_id']
        end

        pcvs_where_patient_is_in_ipp.each do |pcv|
          print "."
          FileUtils.cp(File.join(base_cat1_dir, "#{patient.last.downcase}-#{patient.first.downcase}.cat1.xml"), per_measure_dir)
        end
      end
    end

    puts ""
  end


  desc 'Generate QRDA3 file for specified measures (NQF_ID=0004,0038) or measure types (MEASURE_TYPE=[ep|eh])'
  task :cat3 do
    exporter = HealthDataStandards::Export::Cat3.new
    measures = []
    if ENV['NQF_ID']
      measures = HealthDataStandards::CQM::Measure.any_in({nqf_id: ENV['NQF_ID'].split(",")}).sort(nqf_id: 1, sub_id: 1)
    elsif ENV['MEASURE_TYPE']
      measures = case ENV['MEASURE_TYPE']
        when "ep" then HealthDataStandards::CQM::Measure.all.where(type: "ep").sort(nqf_id: 1, sub_id: 1)
        when "eh" then HealthDataStandards::CQM::Measure.all.where(type: "eh").sort(nqf_id: 1, sub_id: 1)
        else           HealthDataStandards::CQM::Measure.sort(nqf_id: 1, sub_id: 1)
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
    effective_date = Time.gm(2012, 12, 31,23,59,00)
    measures.each do |measure|
      measure_model = QME::QualityMeasure.new(measure['id'], measure['sub_id'])
      oid_dictionary = OidHelper.generate_oid_dictionary(measure_model.definition)
      qr = QME::QualityReport.new(measure['id'],
                                  measure['sub_id'],
                                  'effective_date' => effective_date.to_i,
                                  'test_id' => measure['test_id'],
                                  'oid_dictionary' => oid_dictionary)
      qr.calculate(false) unless qr.calculated?
    end
    destination_dir = File.join(Rails.root, 'tmp', 'test_results')
    FileUtils.mkdir_p destination_dir
    puts "Measures: " + measures.map{|m| "#{m.nqf_id}#{m.sub_id}"}.join(",")
    puts "Rails env: #{Rails.env}"
    puts "Exporting #{destination_dir}/#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat3.xml..."
    output = File.open(File.join(destination_dir, "#{Time.now.strftime '%Y-%m-%d_%H%M'}.cat3.xml"), "w")
    output << exporter.export(measures, generate_header(Time.now), effective_date, Date.parse("2012-01-01"), Date.parse("2012-12-31"))
    output.close
  end

  def generate_header(time)
    Qrda::Header.new(YAML.load(File.read(File.join(Rails.root, 'config', 'qrda3_header.yml'))).deep_merge(legal_authenticator: {time: time}), authors: {time: time})
  end
end
