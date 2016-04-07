Gem::Specification.new do |s|
  s.name        = 'cyclid'
  s.version     = '0.1.0'
  s.licenses    = ['Apache-2.0']
  s.summary     = 'Cyclid CI API'
  s.description = 'The Cyclid CI system'
  s.authors     = ['Kristian Van Der Vliet']
  s.email       = 'vanders@liqwyd.com'
  s.files       = Dir.glob('lib/**/*') + %w(LICENSE README.md)

  s.add_runtime_dependency('oj', '~> 2.14')
  s.add_runtime_dependency('require_all', '~> 1.3')
  s.add_runtime_dependency('sinatra', '~> 1.4')
  s.add_runtime_dependency('sinatra-contrib', '~> 1.4')
  s.add_runtime_dependency('warden', '~> 1.2')
  s.add_runtime_dependency('activerecord', '~> 4.2')
  s.add_runtime_dependency('sinatra-activerecord', '~> 2.0')
  s.add_runtime_dependency('bcrypt', '~> 3.1')
  s.add_runtime_dependency('net-ssh', '~> 3.1')
  s.add_runtime_dependency('sidekiq', '~> 4.1')

  s.add_runtime_dependency('cyclid-core', '~> 0')
  s.add_runtime_dependency('mist-client', '~> 0')
end