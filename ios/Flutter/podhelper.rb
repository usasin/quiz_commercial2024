# podhelper.rb

require 'json'

def parse_KV_file(file, separator='=')
    file_abs_path = File.expand_path(file)
    if !File.exist?(file_abs_path)
        return {}
    end
    File.foreach(file_abs_path).with_object({}) do |line, map|
        line = line.strip
        if line.start_with?('#')
            next
        end
        key, value = line.split(separator, 2)
        if key && value
            map[key.strip] = value.strip
        end
    end
end

def flutter_root(f)
    while f != '/'
        if File.exist?(File.join(f, 'flutter'))
            return f
        end
        f = File.expand_path('..', f)
    end
    raise "Unable to find Flutter root"
end

def flutter_install_all_ios_pods(ios_application_path = nil)
    ios_application_path ||= File.dirname(File.realpath(__FILE__))
    generated_plugins_path = File.join(ios_application_path, '.flutter-plugins-dependencies')
    if !File.exist?(generated_plugins_path)
        raise "#{generated_plugins_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
    end

    plugins = JSON.parse(File.read(generated_plugins_path))
    plugins['plugins'].each do |plugin|
        plugin_name = plugin['name']
        plugin_path = plugin['path']
        if plugin_path.nil?
            raise "No path for plugin #{plugin_name}"
        end
        symlink = File.join(ios_application_path, plugin_name)
        File.symlink(plugin_path, symlink) unless File.exist?(symlink)
        pod plugin_name, :path => plugin_path
    end
end
