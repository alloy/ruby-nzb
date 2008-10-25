require "rubygems" rescue LoadError
require "test/unit"
require "test/spec"
require "mocha"

APP_ROOT = File.expand_path('../../', __FILE__)
$:.unshift File.join(APP_ROOT, 'lib')

def fixture(name)
  File.join(APP_ROOT, 'test', 'fixtures', name)
end