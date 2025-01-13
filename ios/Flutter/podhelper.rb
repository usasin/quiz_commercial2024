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
  app_framework_dir = File.expand_path(File.join('..', '..', 'Flutter'), __dir__)
  unless File.exist?(File.join(app_framework_dir, 'App.framework'))
    raise "#{app_framework_dir}/App.framework must exist. If you're running pod install manually, make sure flutter build ios is executed first"
  end
end

def flutter_install_all_ios_pods(installer)
  flutter_ios_podfile_setup
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end

