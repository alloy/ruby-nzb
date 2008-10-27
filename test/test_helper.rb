require "rubygems" rescue LoadError
require "test/unit"
require "test/spec"
require "mocha"

require 'nzb'

APP_ROOT = File.expand_path('../../', __FILE__)
$:.unshift File.join(APP_ROOT, 'lib')

TMP_DIR = File.join(APP_ROOT, 'test', 'tmp')
NZB.output_directory = TMP_DIR

def fixture(name)
  File.join(APP_ROOT, 'test', 'fixtures', name)
end