require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'spec/rake/spectask'

GEM = "appengine-tools"
GEM_VERSION = "0.0.12"
HOMEPAGE = "http://code.google.com/p/appengine-jruby"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE"]
  s.summary = "Tools for developing and deploying apps to Google App Engine"
  s.description = <<-EOF
Tools and SDK for developing Ruby applications for Google App Engine.
Includes a local development server and tools for testing and deployment."
EOF
  s.authors = ["Ryan Brown", "John Woodell"]
  s.email = ["ribrdb@google.com", "woodie@google.com"]
  s.homepage = HOMEPAGE
  
  s.require_path = 'lib'
  s.files = %w(COPYING LICENSE README.rdoc Rakefile) +
      Dir.glob("{lib,spec}/**/*.{rb,class}")
  s.executables = [ 'appcfg.rb', 'dev_appserver.rb' ]
  s.add_dependency('appengine-rack')
  s.add_dependency('appengine-sdk')
  s.add_dependency('appengine-jruby-jars')
  s.add_dependency('bundler')
  s.add_dependency('rubyzip')
end

task :default => :spec

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = IO.read('spec/spec.opts').split
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the gem locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION}}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end
