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

require 'rack'
require 'rexml/document'
require 'uri'

require 'appengine-rack/java'

class WebXmlBuilder < Rack::Builder
  DUMMY_APP = Proc.new{|env|}

  def initialize(&block)
    @path = "/"
    @paths = Hash.new {|h, k| h[k] = []}
    @skip_defaults = false
    @mime_mapping = {}
    instance_eval(&block) if block_given?
  end

  def add_mime_mapping(doc)
    @mime_mapping.each_pair do |key,val|
      mime = doc.add_element('mime-mapping')
      mime.add_element('extension').add_text(key.to_s)
      mime.add_element('mime-type').add_text(val)
    end
  end

  def add_jruby_rack_defaults
    unless @skip_defaults
      use JavaServletFilter, 'org.jruby.rack.RackFilter',
        { :name => 'RackFilter', :wildcard => true }
    end
  use JavaContextListener, 'com.google.appengine.jruby.LazyContextListener'
  end

  def use(middleware, *args, &block)
    if middleware.respond_to? :append_xml
      @paths[@path] << [middleware, args, block]
    else
      @paths[@path] << [middleware.new(DUMMY_APP, *args, &block)]
    end
  end

  def map(path, &block)
    if URI.parse(path).scheme.nil?  # we can only natively support path matching
      saved_path = @path
      @path = [@path, path].join('/').squeeze('/')
      begin
        instance_eval(&block) if block_given?
      ensure
        @path = saved_path
      end
    end
  end

  def run(app)
    @paths[@path] << [app, [], nil]
  end

  def to_xml
    doc = REXML::Document.new.add_element('web-app')
    doc.add_attribute("xmlns", "http://java.sun.com/xml/ns/javaee")
    doc.add_attribute("version", "2.5")
    each_path do |path, objects|
      pattern = path.chomp('/')
      pattern = '/' if pattern.empty?
      objects.each do |object, args, block|
        if object.respond_to? :append_xml
          object.append_xml(doc, pattern, *args, &block)
        end
      end
    end
    add_mime_mapping(doc)
    doc
  end

  private
  def each_path
    @paths.sort {|a, b| b[0].length - a[0].length}.each do |path, value|
      yield path, value
    end
  end
end
