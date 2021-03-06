#! /usr/bin/ruby
# Copyright:: Copyright 2009 Google Inc.
# Original Author:: Ryan Brown (mailto:ribrdb@google.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'appengine-sdk'

module AppEngine
  module Development
    
    BOOT_APP_RB = File.join(File.dirname(__FILE__), 'boot_app.rb')

    class << self
      def boot_jruby(root=nil, options={})
        unless defined?(JRUBY_VERSION)
          require 'appengine-jruby-jars'

          jars = [
            AppEngine::JRubyJars.jruby_jar,
            AppEngine::JRubyJars.rubygems_jar,
            AppEngine::SDK::TOOLS_JAR,
            ]

          args = options[:args] || ARGV
          should_exec = options[:exec]
          should_exec ||= should_exec.nil?

          # TODO This is really ugly. We should just be using -I
          # for the paths we need (appengine-tools and it's deps)
          ENV['GEM_HOME'] = Gem.dir
          ENV['GEM_PATH'] = Gem.path.compact.join(File::SEPARATOR)
          appcfg = [File.expand_path(File.join(File.dirname($0),
                                               'appcfg.rb'))]
          if should_exec
            exec_jruby(root, jars, appcfg + args)
          else
            run_jruby(root, jars, appcfg + args)
          end
        end
      end
    
      def boot_app(root, args)
        root = File.expand_path(root)

        jars = AppEngine::SDK::RUNTIME_JARS

        jruby_args = ["-r#{BOOT_APP_RB}"] + args

        ENV['APPLICATION_ROOT'] = root
        ENV.delete 'GEM_HOME'
        exec_jruby(root, jars, jruby_args)
      end
      
      def build_command(root, jars, args)
        app_jars = root ? Dir.glob("#{root}/WEB-INF/lib/*.jar") : []
        classpath = (app_jars + jars).join(File::PATH_SEPARATOR)
        utf = "-Dfile.encoding=UTF-8"
        command = %W(java #{utf} -cp #{classpath} org.jruby.Main) + args
        if ENV['VERBOSE']
          puts command.map {|a| a.inspect}.join(' ')
        end
        command
      end
      
      def exec_jruby(root, jars, args)
        java_command = build_command(root, jars, args)
        exec *java_command
      end
      
      def run_jruby(root, jars, args)
        java_command = build_command(root, jars, args)
        if !system(*java_command)
          puts 'Error executing jruby'
        end
      end
    end
  end
end
