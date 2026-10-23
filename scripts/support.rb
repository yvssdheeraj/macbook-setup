#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'digest'
require 'shellwords'
require 'open3'
require 'time'
require 'uri'
require 'rubygems/version'

CONFIG_KEYS = %w[
  GIT_USER_NAME GIT_USER_EMAIL GIT_DEFAULT_BRANCH GIT_EDITOR NODE_VERSION
  PYTHON_VERSION JAVA_VERSION JAVA_LTS GRADLE_VERSION INTELLIJ_EDITION
  COLIMA_CPU COLIMA_MEMORY COLIMA_DISK COLIMA_START_AT_LOGIN AWS_DEFAULT_REGION
  AWS_PROFILE BREW_PREFIX LOCAL_BIN APP_DIR STATE_DIR CACHE_DIR DATA_DIR NVM_DIR
  SDKMAN_DIR ZSH
].freeze

def user_path(path, follow_leaf = true)
  home = File.realpath(ENV.fetch('HOME'))
  raise 'HOME cannot be the filesystem root' if home == '/'
  expanded = File.expand_path(path)
  raise "Control character in path: #{path.inspect}" if expanded.match?(/[\x00-\x1f]/)
  missing = follow_leaf ? [] : [File.basename(expanded)]
  existing = follow_leaf ? expanded : File.dirname(expanded)
  until File.exist?(existing) || File.symlink?(existing)
    missing.unshift(File.basename(existing))
    parent = File.dirname(existing)
    raise "Cannot resolve path: #{path}" if parent == existing
    existing = parent
  end
  resolved = File.join(File.realpath(existing), *missing)
  raise "Installation path escapes HOME: #{path}" unless resolved.start_with?("#{home}/")
  expanded
end

def atomic_write(path, data, mode = 0o600)
  write_context!
  path = user_path(path)
  FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
  temporary = "#{path}.tmp-#{Process.pid}"
  begin
    File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, mode) { |file| file.write(data) }
    File.rename(temporary, path)
  ensure
    File.unlink(temporary) if File.exist?(temporary)
  end
end

def write_context!
  raise 'Writes are forbidden during dry-run or validation' if ENV['DRY_RUN'] == 'true' || ENV['MODE'] == 'validate'
  run = ENV['RUN_DIR']
  lock = File.join(ENV.fetch('STATE_DIR'), 'lock', 'pid')
  raise 'No active setup run; use setup.sh' unless run && File.directory?(user_path(run)) && File.file?(user_path(lock))
end

def state_path
  user_path(File.join(ENV.fetch('STATE_DIR'), 'ownership.json'))
end

def state
  return { 'schema' => 1, 'resources' => {} } unless File.exist?(state_path)
  value = JSON.parse(File.read(state_path))
  raise 'Unsupported or invalid ownership state' unless value['schema'] == 1 && value['resources'].is_a?(Hash)
  value
end

def save_state(value)
  atomic_write(state_path, JSON.pretty_generate(value) + "\n")
end

def fingerprint(path)
  return nil unless File.exist?(path) || File.symlink?(path)
  return "link:#{File.readlink(path)}" if File.symlink?(path)
  return "file:#{File.stat(path).mode & 0o777}:#{Digest::SHA256.file(path).hexdigest}" if File.file?(path)
  digest = Digest::SHA256.new
  digest << (File.stat(path).mode & 0o777).to_s << "\0"
  Dir.glob(File.join(path, '**', '*'), File::FNM_DOTMATCH).sort.each do |entry|
    next if %w[. ..].include?(File.basename(entry))
    digest << entry.delete_prefix("#{path}/") << "\0"
    digest << (File.lstat(entry).mode & 0o777).to_s << "\0"
    digest << (File.symlink?(entry) ? "link:#{File.readlink(entry)}" : File.file?(entry) ? Digest::SHA256.file(entry).hexdigest : 'directory')
  end
  "tree:#{digest.hexdigest}"
end

def snapshot(path, component)
  write_context!
  path = user_path(path, false)
  data = state
  id = "path:#{path}"
  resource = data['resources'][id]
  if resource
    raise "User changes detected; refusing to overwrite #{path}" if resource['after'] && fingerprint(path) != resource['after']
    if !resource['after'] && fingerprint(path) != resource['before']
      raise "Interrupted installation needs inspection; preserving #{path}"
    end
    return resource
  end
  before = fingerprint(path)
  raise "Refusing to adopt a pre-existing directory: #{path}" if File.directory?(path) && !File.symlink?(path)
  backup = nil
  if before
    backup = user_path(File.join(ENV.fetch('STATE_DIR'), 'backups', Digest::SHA256.hexdigest(path)))
    FileUtils.mkdir_p(File.dirname(backup), mode: 0o700)
    if File.symlink?(path)
      File.write(backup, File.readlink(path), mode: 'w', perm: 0o600)
    else
      FileUtils.cp(path, backup, preserve: true)
    end
  end
  resource = { 'kind' => 'path', 'component' => component, 'path' => path,
               'before' => before, 'backup' => backup, 'after' => nil }
  data['resources'][id] = resource
  save_state(data)
  resource
end

def seal(path)
  path = user_path(path, false)
  data = state
  resource = data['resources'].fetch("path:#{path}")
  resource['after'] = fingerprint(path)
  raise "Installation produced no resource: #{path}" unless resource['after']
  save_state(data)
end

def write_managed(path, component, contents)
  path = user_path(path)
  path = File.realpath(path) if File.symlink?(path)
  if File.file?(path) && File.binread(path) == contents
    record = state['resources']["path:#{path}"]
    seal(path) if record && !record['after']
    return 'unchanged'
  end
  snapshot(path, component)
  mode = File.file?(path) ? File.stat(path).mode & 0o777 : 0o600
  atomic_write(path, contents, mode)
  seal(path)
  'changed'
end

def block_markers(component)
  ["# >>> macbook-setup:#{component} >>>", "# <<< macbook-setup:#{component} <<<"]
end

def write_block(path, component, contents)
  path = user_path(path)
  path = File.realpath(path) if File.symlink?(path)
  start, finish = block_markers(component)
  existing = File.exist?(path) ? File.read(path) : ''
  pattern = /^#{Regexp.escape(start)}\n.*?^#{Regexp.escape(finish)}\n?/m
  matches = existing.scan(pattern)
  if existing.include?(start) || existing.include?(finish)
    raise "Malformed or duplicate managed block in #{path}" unless matches.length == 1 && existing.scan(start).length == 1 && existing.scan(finish).length == 1
  end
  data = state
  id = "block:#{component}:#{path}"
  resource = data['resources'][id]
  raise "Managed block has no ownership record; preserving #{path}" if !resource && matches.first
  if resource && matches.first && Digest::SHA256.hexdigest(matches.first) != resource['after']
    raise "Managed block was edited; preserving #{path}"
  end
  block = "#{start}\n#{contents.rstrip}\n#{finish}\n"
  updated = matches.empty? ? existing + (existing.empty? || existing.end_with?("\n") ? '' : "\n") + block : existing.sub(pattern) { block }
  return 'unchanged' if updated == existing
  data['resources'][id] ||= { 'kind' => 'block', 'component' => component, 'path' => path, 'created' => !File.exist?(path) }
  data['resources'][id]['after'] = Digest::SHA256.hexdigest(block)
  # Save the recovery record before replacing a file.
  save_state(data)
  atomic_write(path, updated, File.exist?(path) ? File.stat(path).mode & 0o777 : 0o600)
  'changed'
end

def config_values(path)
  File.readlines(path).each_with_index do |line, index|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    match = /\A(?:export\s+)?([A-Z][A-Z0-9_]*)=(.*)\z/.match(line)
    raise "#{path}:#{index + 1}: expected KEY=value" unless match && CONFIG_KEYS.include?(match[1])
    raw = match[2]
    raise "#{path}:#{index + 1}: shell expansion is not supported" if raw.include?('`') || raw.include?('$')
    # Shellwords handles quoting, but never expands or executes the input.
    quote = nil
    escaped = false
    comment = nil
    raw.each_char.with_index do |character, offset|
      if escaped
        escaped = false
      elsif character == '\\' && quote != "'"
        escaped = true
      elsif quote
        quote = nil if character == quote
      elsif character == '"' || character == "'"
        quote = character
      elsif character == '#' && (offset.zero? || raw[offset - 1].match?(/\s/))
        comment = offset
        break
      end
    end
    raw = raw[0...comment] if comment
    tokens = Shellwords.shellsplit(raw)
    raise "#{path}:#{index + 1}: quote values containing spaces" if tokens.length > 1
    value = tokens.first || ''
    raise "#{path}:#{index + 1}: control characters are not allowed" if value.match?(/[\x00-\x1f]/)
    puts "#{match[1]}\t#{value}"
  end
end

def validate_config
  raise 'DRY_RUN must be true or false' unless %w[true false].include?(ENV.fetch('DRY_RUN'))
  raise 'Invalid setup mode' unless %w[install update validate uninstall].include?(ENV.fetch('MODE'))
  CONFIG_KEYS.each do |key|
    raise "Control character in #{key}" if ENV.fetch(key, '').match?(/[\x00-\x1f]/)
  end
  %w[COLIMA_CPU COLIMA_MEMORY COLIMA_DISK].each do |key|
    raise "#{key} must be a positive integer" unless ENV.fetch(key).match?(/\A[1-9][0-9]*\z/)
  end
  raise 'JAVA_LTS must be latest or a major version' unless ENV.fetch('JAVA_LTS').match?(/\A(?:latest|[1-9][0-9]*)\z/)
  raise 'COLIMA_START_AT_LOGIN must be true or false' unless %w[true false].include?(ENV.fetch('COLIMA_START_AT_LOGIN'))
  raise 'Invalid IntelliJ edition' unless %w[idea-community idea-ultimate].include?(ENV.fetch('INTELLIJ_EDITION'))
  %w[NODE_VERSION PYTHON_VERSION JAVA_VERSION GRADLE_VERSION].each do |key|
    raise "Invalid #{key}" unless ENV.fetch(key).match?(/\A[a-zA-Z0-9][a-zA-Z0-9.*\/_-]*\z/)
  end
  raise 'Invalid AWS profile name' unless ENV.fetch('AWS_PROFILE').match?(/\A[a-zA-Z0-9_.@+-]+\z/)
  %w[BREW_PREFIX LOCAL_BIN APP_DIR STATE_DIR CACHE_DIR DATA_DIR NVM_DIR SDKMAN_DIR ZSH].each do |key|
    path = ENV.fetch(key)
    raise "#{key} must be an absolute path" unless path.start_with?('/')
    user_path(path)
  end
end

def json_field(value, path)
  path.split('.').inject(value) { |object, key| object.is_a?(Array) ? object.fetch(Integer(key)) : object.fetch(key) }
end

def capture(*argv)
  stdout, stderr, status = Open3.capture3(*argv)
  raise "#{argv.first} failed: #{stderr.strip}" unless status.success?
  stdout.strip
end

def read_default(domain, key)
  stdout, stderr, status = Open3.capture3('defaults', 'read', domain, key)
  return nil if !status.success? && stderr.match?(/does not exist|not found/i)
  raise "Cannot read #{domain}/#{key}: #{stderr}" unless status.success?
  { 'value' => stdout.strip, 'type' => capture('defaults', 'read-type', domain, key).sub('Type is ', '').strip }
end

def preference(domain, key, type, value)
  raise 'Invalid preference domain/key' unless domain.match?(/\A[a-zA-Z0-9.-]+\z/) && key.match?(/\A[a-zA-Z0-9_.-]+\z/)
  before = read_default(domain, key)
  normalized = type == 'bool' ? (value == 'true' ? '1' : '0') : value
  return 'unchanged' if before && before['value'] == normalized
  data = state
  id = "default:#{domain}:#{key}"
  record = data['resources'][id]
  raise "Preference changed outside setup: #{domain}/#{key}" if record && before != record['after']
  record ||= { 'kind' => 'default', 'component' => ENV.fetch('CURRENT_COMPONENT'), 'domain' => domain, 'key' => key, 'before' => before }
  data['resources'][id] = record
  save_state(data)
  capture('defaults', 'write', domain, key, "-#{type}", value)
  record['after'] = read_default(domain, key)
  raise "Preference write did not take effect: #{domain}/#{key}" unless record['after'] && record['after']['value'] == normalized
  save_state(data)
  'changed'
end

def report(component, status, detail)
  path = user_path(ENV.fetch('REPORT_FILE'))
  json = "#{path}.json"
  data = File.exist?(json) ? JSON.parse(File.read(json)) : { 'generated_at' => Time.now.utc.iso8601, 'mode' => ENV.fetch('MODE'), 'components' => [] }
  versions_path = File.join(ENV.fetch('RUN_DIR'), "versions.#{component}.json")
  versions = File.exist?(versions_path) ? JSON.parse(File.read(versions_path)) : []
  data['components'] << { 'component' => component, 'status' => status, 'detail' => detail, 'versions' => versions }
  atomic_write(json, JSON.pretty_generate(data) + "\n")
  escape = ->(value) { value.to_s.gsub('|', '\\|').gsub(/[\r\n]/, ' ') }
  lines = ["# macbook-setup report", '', "Generated: #{data['generated_at']}", "Mode: #{data['mode']}", '',
           '| Component | Status | Installed / requested | Detail |', '| --- | --- | --- | --- |']
  data['components'].each do |row|
    versions = row['versions'].map { |v| "#{v['name']}: #{v['installed']} / #{v['requested']}" }.join('; ')
    lines << "| #{escape.call(row['component'])} | #{escape.call(row['status'])} | #{escape.call(versions)} | #{escape.call(row['detail'])} |"
  end
  atomic_write(path, lines.join("\n") + "\n")
end

def package_record(type, name, version, prefix, dependency = false)
  raise 'Invalid package name' unless name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9@+_.\/-]*\z/)
  raise 'Invalid package type' unless %w[formula cask backend].include?(type)
  version = version.delete_prefix("#{name} ")
  data = state
  data['resources']["package:#{type}:#{name}"] = {
    'kind' => 'package', 'type' => type, 'name' => name, 'version' => version,
    'prefix' => user_path(prefix), 'component' => ENV.fetch('CURRENT_COMPONENT'), 'dependency' => dependency
  }
  save_state(data)
end

def package_policy(metadata, type)
  raise 'Upstream package is disabled' if metadata['disabled']
  return unless %w[cask bundle].include?(type)
  allowed = %w[app binary command_wrapper manpage zsh_completion bash_completion fish_completion uninstall zap]
  metadata.fetch('artifacts').each do |artifact|
    keys = artifact.keys - ['target']
    raise "Cask requires an unsupported installer/hook: #{keys.join(', ')}" unless (keys - allowed).empty?
    if type == 'cask' && artifact['uninstall']
      artifact.fetch('uninstall').each do |actions|
        unsupported = actions.keys - %w[quit signal login_item]
        raise "Cask has unsupported uninstall hooks: #{unsupported.join(', ')}; use its app bundle instead" unless unsupported.empty?
      end
    end
  end
  requirement = metadata.fetch('depends_on', {}).fetch('macos', {})
  if requirement['>=']
    actual = capture('sw_vers', '-productVersion').split('.').map(&:to_i)
    minimum = requirement['>='].first.split('.').map(&:to_i)
    raise "Cask requires macOS #{requirement['>='].first} or later" if (actual <=> minimum) == -1
  end
end

def change_dock(app)
  domain = 'com.apple.dock'
  key = 'persistent-apps'
  current = read_default(domain, key)
  raise 'Dock preferences are unavailable in this session' unless current
  url = "file://#{URI::DEFAULT_PARSER.escape(File.expand_path(app))}/"
  return 'unchanged' if current['value'].include?(url)
  data = state
  id = "default:#{domain}:#{key}"
  record = data['resources'][id]
  raise 'Dock layout changed outside setup; preserving it' if record && record['after'] != current
  record ||= { 'kind' => 'default', 'component' => 'dock', 'domain' => domain, 'key' => key, 'before' => current }
  data['resources'][id] = record
  save_state(data)
  xml = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>#{url.gsub('&', '&amp;').gsub('<', '&lt;')}</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
  capture('defaults', 'write', domain, key, '-array-add', xml)
  record['after'] = read_default(domain, key)
  save_state(data)
  'changed'
end

def wallpapers
  JSON.parse(capture('osascript', '-l', 'JavaScript', '-e',
                     'JSON.stringify(Application("System Events").desktops().map(d => ({id: d.id(), picture: d.picture()})))'))
end

def change_wallpaper(path)
  path = user_path(path)
  current = wallpapers
  raise 'No desktops are available in this login session' if current.empty?
  return 'unchanged' if current.all? { |desktop| desktop['picture'] == path }
  data = state
  record = data['resources']['wallpaper']
  raise 'Wallpaper changed outside setup; preserving it' if record && current != record['after']
  record ||= { 'kind' => 'wallpaper', 'component' => 'wallpaper', 'before' => current }
  data['resources']['wallpaper'] = record
  save_state(data)
  script = 'function run(argv) { Application("System Events").desktops().forEach(d => d.picture = argv[0]); }'
  capture('osascript', '-l', 'JavaScript', '-e', script, path)
  record['after'] = wallpapers
  raise 'Wallpaper change did not take effect' unless record['after'].all? { |desktop| desktop['picture'] == path }
  save_state(data)
  'changed'
end

def remove_resource(resource, dry_run)
  kind = resource.fetch('kind')
  label = resource['path'] || resource['name'] || [resource['domain'], resource['key']].compact.join('/')
  if dry_run
    puts "[DRY-RUN] Inspect and remove/restore owned #{kind}: #{label}"
    return false
  end
  case kind
  when 'path'
    path = user_path(resource.fetch('path'), false)
    return true unless fingerprint(path)
    raise "Retaining user-modified resource: #{path}" if resource['retain'] || !resource['after'] || fingerprint(path) != resource['after']
    if File.directory?(path) && !File.symlink?(path)
      FileUtils.remove_entry_secure(path)
    else
      File.unlink(path)
    end
    if resource['backup']
      backup = user_path(resource['backup'])
      if resource['before'].start_with?('link:')
        File.symlink(File.read(backup), path)
      else
        FileUtils.cp(backup, path, preserve: true)
      end
    end
  when 'block'
    path = user_path(resource.fetch('path'))
    return true unless File.exist?(path)
    start, finish = block_markers(resource.fetch('component'))
    pattern = /^#{Regexp.escape(start)}\n.*?^#{Regexp.escape(finish)}\n?/m
    contents = File.read(path)
    block = contents[pattern]
    return true unless block
    raise "Retaining edited managed block: #{path}" unless Digest::SHA256.hexdigest(block) == resource['after']
    updated = contents.sub(pattern, '')
    if updated.empty? && resource['created']
      File.unlink(path)
    else
      atomic_write(path, updated, File.stat(path).mode & 0o777)
    end
  when 'default'
    current = read_default(resource.fetch('domain'), resource.fetch('key'))
    raise "Retaining preference changed outside setup: #{label}" unless resource['after'] && current == resource['after']
    before = resource['before']
    if before
      type = { 'boolean' => 'bool', 'integer' => 'int', 'float' => 'float', 'string' => 'string' }[before['type']]
      argv = ['defaults', 'write', resource['domain'], resource['key']]
      argv << "-#{type}" if type
      argv << before.fetch('value')
      capture(*argv)
    else
      capture('defaults', 'delete', resource['domain'], resource['key'])
    end
  when 'wallpaper'
    raise 'Retaining wallpaper changed outside setup' unless resource['after'] && wallpapers == resource['after']
    script = 'function run(argv) { let old = JSON.parse(argv[0]); Application("System Events").desktops().forEach(d => { let item = old.find(o => o.id === d.id()); if (item) d.picture = item.picture; }); }'
    capture('osascript', '-l', 'JavaScript', '-e', script, JSON.generate(resource.fetch('before')))
  when 'package'
    if resource['type'] == 'backend'
      warn "[WARNING] Retaining the Homebrew bootstrap at #{resource['prefix']}; it may contain independently installed packages."
      return false
    end
    prefix = user_path(resource.fetch('prefix'))
    brew = File.join(prefix, 'bin', 'brew')
    raise "Cannot remove package without its original Homebrew: #{label}" unless File.executable?(brew)
    installed = capture(brew, 'list', "--#{resource.fetch('type')}", '--versions', resource.fetch('name'))
    installed = installed.delete_prefix("#{resource['name']} ")
    raise "Retaining package updated outside setup: #{label}" unless installed == resource.fetch('version')
    if resource['type'] == 'cask'
      apps = resource['apps']
      raise "Retaining cask without an application fingerprint: #{label}" unless apps && !apps.empty?
      apps.each do |path, expected|
        path = user_path(path, false)
        raise "Retaining application changed outside setup: #{path}" unless fingerprint(path) == expected
      end
    end
    capture(brew, 'uninstall', "--#{resource.fetch('type')}", resource.fetch('name'))
  when 'colima'
    home = user_path(resource.fetch('home'))
    env = { 'COLIMA_HOME' => home }
    _, stderr, status = Open3.capture3(env, 'colima', 'status', '--profile', 'macbook-setup')
    if status.success?
      _, error, stopped = Open3.capture3(env, 'colima', 'stop', '--profile', 'macbook-setup')
      raise "Could not stop owned Colima profile: #{error}" unless stopped.success?
    elsif !stderr.match?(/not running|not exist|stopped/i)
      raise "Cannot inspect owned Colima profile: #{stderr}"
    end
    warn "[WARNING] Retaining Colima VM data at #{home}."
  when 'service'
    path = user_path(resource.fetch('path'))
    _, error, loaded = Open3.capture3('launchctl', 'print', "gui/#{Process.uid}/dev.macbook-setup.colima")
    if loaded.success?
      raise "Loaded LaunchAgent changed outside setup: #{path}" unless fingerprint(path) == resource['fingerprint']
      capture('launchctl', 'bootout', "gui/#{Process.uid}/dev.macbook-setup.colima")
    elsif !error.match?(/could not find service|not found/i)
      raise "Cannot inspect user service: #{error}"
    end
  else
    raise "Unknown resource kind: #{kind}"
  end
  puts "[REMOVED/RESTORED] #{label}"
  true
end

begin
  command = ARGV.shift
  case command
  when 'path' then puts user_path(ARGV.fetch(0))
  when 'config' then config_values(ARGV.fetch(0))
  when 'validate-config' then validate_config
  when 'write' then puts write_managed(ARGV.fetch(0), ARGV.fetch(1), STDIN.binmode.read)
  when 'block' then puts write_block(ARGV.fetch(0), ARGV.fetch(1), STDIN.read)
  when 'snapshot' then snapshot(ARGV.fetch(0), ARGV.fetch(1))
  when 'seal' then seal(ARGV.fetch(0))
  when 'owned'
    exit 1 unless File.expand_path(ARGV.fetch(0)).start_with?("#{File.expand_path(ENV.fetch('HOME'))}/")
    path = user_path(ARGV.fetch(0), false)
    exit(state['resources'].values.any? { |r| r['kind'] == 'path' && (path == r['path'] || path.start_with?("#{r['path']}/")) } ? 0 : 1)
  when 'check-owned'
    path = user_path(ARGV.fetch(0), false)
    record = state['resources'].fetch("path:#{path}")
    raise "User changes detected in #{path}" unless fingerprint(path) == record['after']
  when 'retain-modified'
    path = user_path(ARGV.fetch(0), false)
    data = state
    record = data['resources'].fetch("path:#{path}")
    current = fingerprint(path)
    if record['after'] && current != record['after']
      warn "[WARNING] External changes detected; #{path} will be retained on uninstall."
      record['retain'] = true
      record['after'] = current
      save_state(data)
    end
  when 'package-owned'
    exit(state['resources'].key?("package:#{ARGV.fetch(0)}:#{ARGV.fetch(1)}") ? 0 : 1)
  when 'package' then package_record(*ARGV)
  when 'package-app'
    name, path = ARGV
    path = user_path(path)
    data = state
    record = data['resources'].fetch("package:cask:#{name}")
    record['apps'] = { path => fingerprint(path) }
    raise "Installed application is missing: #{path}" unless record['apps'][path]
    save_state(data)
  when 'package-policy' then package_policy(JSON.parse(STDIN.read), ARGV.fetch(0))
  when 'package-version'
    metadata = JSON.parse(STDIN.read)
    puts(ARGV.fetch(0) == 'formula' ? metadata.fetch('versions').fetch('stable') : metadata.fetch('version'))
  when 'brew-diff'
    before = File.readlines(ARGV.fetch(0)).map { |line| line.split.first }
    eligible = File.readlines(ARGV.fetch(3), chomp: true)
    File.readlines(ARGV.fetch(1)).each do |line|
      name, version = line.strip.split(' ', 2)
      next if before.include?(name) || !eligible.include?(name)
      prefix = user_path(ARGV.fetch(2))
      type = File.directory?(File.join(prefix, 'Caskroom', name)) ? 'cask' : 'formula'
      package_record(type, name, version, prefix, true)
    end
  when 'executable'
    source, target, component = ARGV
    source = user_path(source)
    target = user_path(target)
    contents = File.binread(source)
    if File.file?(target) && File.binread(target) == contents && File.executable?(target)
      puts 'unchanged'
    else
      snapshot(target, component)
      atomic_write(target, contents, 0o755)
      seal(target)
      puts 'changed'
    end
  when 'replace-tree'
    source, target = ARGV.map { |path| user_path(path) }
    resource = state['resources'].fetch("path:#{target}")
    snapshot(target, resource.fetch('component'))
    raise "Replacement source is not a directory: #{source}" unless File.directory?(source)
    FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
    old = "#{target}.previous-#{Process.pid}"
    incoming = "#{target}.incoming-#{Process.pid}"
    raise 'Recovery directory already exists; inspect it before retrying' if [old, incoming].any? { |path| File.exist?(path) || File.symlink?(path) }
    begin
      FileUtils.cp_r(source, incoming, preserve: true)
      File.rename(target, old) if File.exist?(target) || File.symlink?(target)
      begin
        File.rename(incoming, target)
      rescue SystemCallError
        File.rename(old, target) if File.exist?(old) && !File.exist?(target)
        raise
      end
      FileUtils.remove_entry_secure(old) if File.exist?(old) || File.symlink?(old)
    ensure
      FileUtils.remove_entry_secure(incoming) if File.exist?(incoming) || File.symlink?(incoming)
    end
  when 'archive-format'
    path = user_path(ARGV.fetch(0))
    File.open(path, 'rb') do |file|
      header = file.read(6).to_s
      file.seek(-512, IO::SEEK_END) if file.size >= 512
      footer = file.read(4).to_s
      if header.start_with?("PK\x03\x04".b)
        puts 'zip'
      elsif header.start_with?("\x1f\x8b".b)
        puts 'tar.gz'
      elsif header.start_with?("\xfd7zXZ\x00".b)
        puts 'tar.xz'
      elsif file.size >= 512 && footer == 'koly'
        puts 'dmg'
      else
        raise "Unsupported application container: #{path}"
      end
    end
  when 'link'
    path, target, component = ARGV
    path = user_path(path, false)
    target = File.expand_path(target)
    raise "Link target does not exist: #{target}" unless File.exist?(target)
    unless File.symlink?(path) && File.realpath(path) == File.realpath(target)
      snapshot(path, component)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.unlink(path) if File.exist?(path) || File.symlink?(path)
      File.symlink(target, path)
      seal(path)
      puts 'changed'
    else
      record = state['resources']["path:#{path}"]
      seal(path) if record && !record['after']
      puts 'unchanged'
    end
  when 'check-links'
    root = user_path(ARGV.fetch(0))
    Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |path|
      next unless File.symlink?(path)
      target = File.expand_path(File.readlink(path), File.dirname(path))
      raise "Archive symlink escapes staging: #{path}" unless target.start_with?("#{root}/")
    end
  when 'sdk-java'
    major = ARGV.fetch(0)
    candidates = STDIN.read.scan(/\b(#{Regexp.escape(major)}\.\d+\.\d+(?:\.\d+)?-tem)\b/).flatten.uniq
    raise "No stable Temurin Java #{major} candidate is available" if candidates.empty?
    puts candidates.max_by { |version| Gem::Version.new(version.delete_suffix('-tem')) }
  when 'sdk-gradle'
    candidates = STDIN.read.split.select { |token| token.match?(/\A\d+\.\d+(?:\.\d+)?\z/) }
    raise 'No stable Gradle candidate is available' if candidates.empty?
    puts candidates.max_by { |version| Gem::Version.new(version) }
  when 'python-version'
    candidates = JSON.parse(STDIN.read).select do |entry|
      entry.fetch('key').match?(/\Acpython-[0-9.]+-macos-aarch64-none\z/) && entry.fetch('version').match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)
    end
    raise 'No stable ARM64 CPython release matches the request' if candidates.empty?
    puts candidates.map { |entry| entry.fetch('version') }.max_by { |version| Gem::Version.new(version) }
  when 'json'
    result = json_field(JSON.parse(STDIN.read), ARGV.fetch(0))
    puts(result.is_a?(String) ? result : JSON.generate(result))
  when 'release'
    release = JSON.parse(STDIN.read)
    raise 'No stable release found' if release['draft'] || release['prerelease'] || !release['tag_name']
    if ARGV.empty?
      puts release.fetch('tag_name')
    else
      asset = release.fetch('assets').find { |entry| entry.fetch('name').match?(Regexp.new(ARGV.fetch(0))) }
      raise "Release has no matching asset: #{ARGV[0]}" unless asset
      digest = asset.fetch('digest', '').to_s
      raise "Release asset has no SHA256 digest: #{asset['name']}" unless digest.match?(/\Asha256:[0-9a-f]{64}\z/)
      puts [release['tag_name'], asset.fetch('browser_download_url'), digest.delete_prefix('sha256:')].join("\t")
    end
  when 'archive-paths'
    STDIN.each_line do |line|
      name = line.chomp
      raise "Unsafe archive member: #{name}" if name.start_with?('/') || name.split('/').include?('..')
    end
  when 'preference' then puts preference(*ARGV)
  when 'dock-add' then puts change_dock(ARGV.fetch(0))
  when 'wallpaper' then puts change_wallpaper(ARGV.fetch(0))
  when 'service'
    data = state
    path = user_path(ARGV.fetch(0))
    data['resources']["service:#{path}"] = { 'kind' => 'service', 'path' => path, 'fingerprint' => fingerprint(path), 'component' => ENV.fetch('CURRENT_COMPONENT') }
    save_state(data)
  when 'service-state'
    path = user_path(ARGV.fetch(0))
    _, error, loaded = Open3.capture3('launchctl', 'print', "gui/#{Process.uid}/dev.macbook-setup.colima")
    if loaded.success?
      record = state['resources']["service:#{path}"]
      raise "Loaded LaunchAgent is not unchanged and repo-owned: #{path}" unless record && record['fingerprint'] == fingerprint(path)
      puts 'loaded'
    elsif error.match?(/could not find service|not found/i)
      puts 'stopped'
    else
      raise "Cannot inspect user service: #{error}"
    end
  when 'colima-state'
    home = user_path(ARGV.fetch(0))
    output, error, running = Open3.capture3({ 'COLIMA_HOME' => home }, 'colima', 'status', '--profile', 'macbook-setup')
    if running.success?
      puts 'running'
    elsif "#{output}\n#{error}".match?(/not running|not exist|stopped/i)
      puts 'stopped'
    else
      raise "Cannot inspect Colima profile: #{error}"
    end
  when 'colima'
    home = user_path(ARGV.fetch(0))
    data = state
    data['resources']["colima:#{home}"] = { 'kind' => 'colima', 'home' => home, 'component' => 'docker' }
    save_state(data)
  when 'colima-owned'
    home = user_path(ARGV.fetch(0))
    exit(state['resources'].key?("colima:#{home}") ? 0 : 1)
  when 'launchagent'
    executable, home = ARGV
    user_path(home)
    escape = ->(text) { text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;') }
    arguments = [executable, 'start', '--profile', 'macbook-setup', '--vm-type', 'vz',
                 '--activate=false', '--ssh-config=false',
                 '--cpus', ENV.fetch('COLIMA_CPU'), '--memory', ENV.fetch('COLIMA_MEMORY'), '--disk', ENV.fetch('COLIMA_DISK')]
    puts '<?xml version="1.0" encoding="UTF-8"?>'
    puts '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    puts '<plist version="1.0"><dict><key>Label</key><string>dev.macbook-setup.colima</string>'
    puts "<key>ProgramArguments</key><array>#{arguments.map { |arg| "<string>#{escape.call(arg)}</string>" }.join}</array>"
    puts "<key>EnvironmentVariables</key><dict><key>COLIMA_HOME</key><string>#{escape.call(home)}</string><key>PATH</key><string>#{escape.call(ENV.fetch('PATH'))}</string></dict>"
    puts '<key>RunAtLoad</key><true/></dict></plist>'
  when 'wallpaper-check'
    expected = state['resources'].fetch('wallpaper').fetch('after')
    raise 'Wallpaper differs from recorded configuration' unless wallpapers == expected
  when 'dock-check'
    url = "file://#{URI::DEFAULT_PARSER.escape(File.expand_path(ARGV.fetch(0)))}/"
    current = read_default('com.apple.dock', 'persistent-apps')
    raise 'Chrome is not present in the Dock' unless current && current['value'].include?(url)
  when 'uninstall'
    dry_run = ARGV.include?('--dry-run')
    write_context! unless dry_run
    data = state
    failed = false
    priorities = { 'service' => 0, 'colima' => 1, 'block' => 2, 'default' => 2, 'wallpaper' => 2, 'path' => 3, 'package' => 4 }
    resources = data.fetch('resources').to_a.reverse.sort_by { |_, value| priorities.fetch(value['kind']) }
    errors = {}
    loop do
      progress = false
      retry_packages = []
      resources.each do |id, resource|
        begin
          if remove_resource(resource, dry_run)
            data['resources'].delete(id)
            save_state(data)
            progress = true
          end
        rescue RuntimeError, SystemCallError => error
          raise if %w[service colima].include?(resource['kind'])
          if resource['kind'] == 'package' && !dry_run
            retry_packages << [id, resource]
            errors[id] = error.message
          else
            warn "[WARNING] #{error.message}"
            failed = true
          end
        end
      end
      break if retry_packages.empty?
      unless progress
        retry_packages.each { |id, _| warn "[WARNING] #{errors.fetch(id)}" }
        failed = true
        break
      end
      resources = retry_packages
    end
    exit(failed ? 1 : 0)
  when 'version'
    component, name, installed, requested = ARGV
    path = File.join(ENV.fetch('RUN_DIR'), "versions.#{component}.json")
    versions = File.exist?(path) ? JSON.parse(File.read(path)) : []
    versions.reject! { |entry| entry['name'] == name }
    versions << { 'name' => name, 'installed' => installed, 'requested' => requested }
    atomic_write(path, JSON.generate(versions))
  when 'report' then report(*ARGV)
  when 'cleanup'
    path = user_path(ARGV.fetch(0))
    cache = user_path(ENV.fetch('CACHE_DIR'))
    raise 'Refusing broad cleanup' unless File.dirname(path) == cache && File.basename(path).start_with?('run.')
    raise 'Mounted volumes remain; refusing cleanup' unless Dir.glob(File.join(path, 'work.*', '.mounted')).empty?
    FileUtils.remove_entry_secure(path)
  else
    raise "Unknown support operation: #{command}"
  end
rescue ArgumentError, KeyError, JSON::ParserError, SystemCallError, RuntimeError => error
  warn "[ERROR] #{error.message}"
  exit 1
end
