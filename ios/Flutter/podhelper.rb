def parse_KV_file(file, separator='=')
  file_abs_path = File.expand_path(file)
  return [] unless File.exist?(file_abs_path)
  File.foreach(file_abs_path).map { |line|
    next if line.strip.empty? || line.strip.start_with?('#')
    line.split(separator, 2).map(&:strip)
  }.to_h
end

def flutter_root
  File.expand_path(File.join('..', '..'), __dir__)
end

def flutter_ios_podfile_setup
  ios_application_path = File.expand_path(File.join(__dir__, '..', '..'))
  File.expand_path(ios_application_path)
end

def flutter_install_all_ios_pods(installer)
  flutter_ios_podfile_setup
  File.expand_path(File.join(installer, '..', 'Podfile'))
end
