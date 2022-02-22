require 'fiddle'
require 'fiddle/import'

module SketchUpAPI
  extend Fiddle::Importer

  case Sketchup.platform
  when :platform_osx
    tools_dir = Sketchup.find_support_file('Tools')
    sketchup_app = File.expand_path('../../../../Contents/MacOS/SketchUp', tools_dir)
  when :platform_win
    sketchup_app = Sketchup.find_support_file('SketchUp.exe')
  else
    raise NotImplemented, "#{Sketchup.platform} not supported"
  end

  dlload sketchup_app

  extern 'void SUGetAPIVersion(size_t*, size_t*)'
end

free = Fiddle::Function.new(Fiddle::RUBY_FREE, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
su_api_version_p = Fiddle::Pointer.malloc(Fiddle::SIZEOF_SIZE_T * 2, free)

SketchUpAPI.SUGetAPIVersion(su_api_version_p, su_api_version_p + Fiddle::SIZEOF_SIZE_T)
su_api_major, su_api_minor = su_api_version_p[0, Fiddle::SIZEOF_SIZE_T * 2].unpack('QQ')
puts "SUGetAPIVersion: #{su_api_major}.#{su_api_minor}"
