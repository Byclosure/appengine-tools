#!/usr/bin/ruby1.8 -w
#
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

require 'appengine-rack'
require 'appengine-tools/boot'
require 'appengine-tools/gem_bundler'
require 'appengine-tools/web-xml'
require 'appengine-tools/xml-formatter'
require 'fileutils'
require 'yaml'

module AppEngine
  module Admin

    class Application
      attr_reader :root

      def initialize(root)
        @root = root
      end

      def path(*pieces)
        File.join(@root, *pieces)
      end

      def webinf
        path('WEB-INF')
      end

      def webinf_lib
        path('WEB-INF', 'lib')
      end

      def gems_jar
        path('WEB-INF', 'lib', 'gems.jar')
      end

      def generation_dir
        path('WEB-INF', 'appengine-generated')
      end

      def gems_dir
        path('.gems')
      end

      def gemfile
        path('Gemfile')
      end

      def config_ru
        path('config.ru')
      end

      def web_xml
        path('WEB-INF', 'web.xml')
      end

      def aeweb_xml
        path('WEB-INF', 'appengine-web.xml')
      end

      def build_status
        path('WEB-INF', 'appengine-generated', 'build_status.yaml')
      end

      def bundled_jars
        path('WEB-INF', 'appengine-generated', 'bundled_jars.yaml')
      end

      def public_root
        path(AppEngine::Rack.app.public_root) if AppEngine::Rack.app.public_root
      end

      def favicon_ico
        File.join(public_root ? public_root : @root, 'favicon.ico')
      end

      def robots_txt
         File.join(public_root ? public_root : @root, 'robots.txt')
      end

      def rack_app
        AppEngine::Rack.app
      end

    end

    class AppBundler
      EXISTING_JRUBY = /^(jruby-abridged|appengine-jruby)-.*jar$/
      EXISTING_APIS = /^appengine-api.*jar$/

      def initialize(root_path)
        @app = Application.new(root_path)
      end

      def bundle(args=[])
        bundle_deps(args)
        convert_config_ru
      end

      def bundle_deps(args=[])
        confirm_appdir
        create_webinf
        bundle_gems(args)
        copy_jruby
        copy_sdk
      end

      def bundle_gems(args)
        return if defined? JRUBY_VERSION
        gem_bundler = AppEngine::Admin::GemBundler.new(app.root)
        gem_bundler.bundle(args)
      end

      def app
        @app
      end

      def confirm_appdir
        unless File.exists?(app.config_ru) or
            File.exists?(app.gemfile) or File.exists?(app.webinf)
          puts ""
          puts "Oops, this does not look like an application directory."
          puts "You need a #{app.gemfile} or #{app.config_ru} file."
          puts ""
          puts "Run 'appcfg.rb generate_app #{app.path}'"
          puts "to generate a skeleton application."
          exit 1
        end
      end

      def create_webinf
        Dir.mkdir(app.webinf) unless File.exists?(app.webinf)
        Dir.mkdir(app.webinf_lib) unless File.exists?(app.webinf_lib)
        Dir.mkdir(app.generation_dir) unless File.exists?(app.generation_dir)
      end

      def create_public
        return unless defined? JRUBY_VERSION
        if app.public_root and !File.exists?(app.public_root)
          Dir.mkdir(app.public_root)
        end
        FileUtils.touch(app.favicon_ico) unless File.exists?(app.favicon_ico)
        FileUtils.touch(app.robots_txt) unless File.exists?(app.robots_txt)
      end

      def convert_config_ru
        unless File.exists?(app.config_ru)
          puts "=> Generating rackup"
          app_id = File.basename(File.expand_path(app.path)).
              downcase.gsub('_', '-').gsub(/[^-a-z0-9]/, '')
          stock_rackup = <<EOF
require 'appengine-rack'
AppEngine::Rack.configure_app(
    :application => "#{app_id}",
    :precompilation_enabled => true,
    :version => "1")
run lambda { ::Rack::Response.new("Hello").finish }
EOF
          File.open(app.config_ru, 'w') {|f| f.write(stock_rackup) }
        end
        generate_xml
        create_public
      end

      def copy_jruby
        require 'appengine-jruby-jars'
        update_jars("JRuby", EXISTING_JRUBY, [AppEngine::JRubyJars.jruby_jar])
      end

      def copy_sdk
        require 'appengine-sdk'
        glob = "appengine-api-{1.0-sdk,labs}-*.jar"
        jars = Dir.glob("#{AppEngine::SDK::SDK_ROOT}/lib/user/#{glob}")
        update_jars('appengine-sdk', EXISTING_APIS, jars)
      end

      private

      def find_jars(regex)
        Dir.entries(app.webinf_lib).grep(regex) rescue []
      end

      def update_jars(name, regex, jars, opt_regex=nil, opt_jars=[])
        existing = find_jars(regex)
        if existing.empty?
          message = "=> Installing #{name}"
          jars_to_install = jars + opt_jars
        else
          has_optional_jars = existing.any? {|j| j =~ opt_regex}
          expected_jars = jars
          expected_jars.concat(opt_jars) if has_optional_jars
          expected = expected_jars.map {|path| File.basename(path)}
          if existing.size != expected.size ||
              (expected & existing) != expected
            message = "=> Updating #{name}"
            jars_to_install = expected_jars
          end
        end
        if jars_to_install
          puts message
          remove_jars(existing)
          if block_given?
            yield
          else
            FileUtils.cp(jars_to_install, app.webinf_lib)
          end
        end
      end

      def remove_jars(jars)
        paths = jars.map do |jar|
          "#{app.webinf_lib}/#{jar}"
        end
        FileUtils.rm_f(paths)
      end

      def valid_build
        return false unless File.exists? app.build_status
        return false unless File.exists? app.web_xml
        return false unless File.exists? app.aeweb_xml
        yaml = YAML.load_file app.build_status
        return false unless yaml.is_a? Hash
        return false unless File.stat(app.config_ru).mtime.eql? yaml[:config_ru]
        return false unless File.stat(app.web_xml).mtime.eql? yaml[:web_xml]
        return false unless File.stat(app.aeweb_xml).mtime.eql? yaml[:aeweb_xml]
        true
      end

      def generate_xml
        return if valid_build
        if defined? JRUBY_VERSION
          puts "=> Generating configuration files"
          Dir.glob("#{app.webinf_lib}/*.jar").each do |path|
            $: << path
          end
          app_root = app.root
          builder = WebXmlBuilder.new do
            # First read the user's rackup file
            Dir.chdir(app_root) do
              require File.join(".gems", "bundler_gems",
                  TARGET_ENGINE, TARGET_VERSION, "environment")
              eval IO.read('config.ru'), nil, 'config.ru', 1
            end

            # Now configure the basic jruby-rack settings.
            add_jruby_rack_defaults
          end
          open(app.web_xml, 'w') do |webxml|
            xml = AppEngine::Rack::XmlFormatter.format(builder.to_xml)
            webxml.write(xml)
          end
          open(app.aeweb_xml, 'w') do |aeweb|
            xml = AppEngine::Rack::XmlFormatter.format(app.rack_app.to_xml)
            aeweb.write(xml)
          end
          yaml = {
              :config_ru => File.stat(app.config_ru).mtime,
              :aeweb_xml => File.stat(app.aeweb_xml).mtime,
              :web_xml   => File.stat(app.web_xml).mtime }
          open(app.build_status, 'w') { |f| YAML.dump(yaml, f) }
        else
          AppEngine::Development.boot_jruby(app.root,
                                            :args => ['bundle', app.root],
                                            :exec => false)
        end
      end
    end

    def self.bundle_app(*args)
      AppBundler.new(args.pop).bundle(args)
    end

    def self.bundle_deps(*args)
      AppBundler.new(args.pop).bundle(args)
    end

  end
end
