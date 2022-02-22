require 'fiddle'
require 'fiddle/import'

module SketchUpAPI
  extend Fiddle::Importer

  sketchup_app = Sketchup.find_support_file('Sketchup.exe')
  dlload sketchup_app

  extern 'void SUGetAPIVersion(size_t*, size_t*)'
end

free = Fiddle::Function.new(Fiddle::RUBY_FREE, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
su_api_major_p = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, free)
su_api_minor_p = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, free)

SketchUpAPI.SUGetAPIVersion(su_api_major_p, su_api_minor_p)
su_api_major = su_api_major_p[0, Fiddle::SIZEOF_SIZE_T].unpack('Q').first
su_api_minor = su_api_minor_p[0, Fiddle::SIZEOF_SIZE_T].unpack('Q').first
puts "SUGetAPIVersion: #{su_api_major}.#{su_api_minor}"
