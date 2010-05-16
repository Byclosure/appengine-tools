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

require File.dirname(__FILE__) + '/spec_helper.rb'
require 'appengine-tools/web-xml'
require 'appengine-tools/xml-formatter'

describe WebXmlBuilder do
  it "should generate correct xml" do
    rackup = IO.read("#{File.dirname(__FILE__)}/config.ru")
    builder = WebXmlBuilder.new do
      add_jruby_rack_defaults
      eval rackup, nil, "#{File.dirname(__FILE__)}/config.ru", 1
    end
    xml = AppEngine::Rack::XmlFormatter.format(builder.to_xml)
    xml.should == IO.read("#{File.dirname(__FILE__)}/web.xml")
  end
end