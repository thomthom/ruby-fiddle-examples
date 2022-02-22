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
    raise NotImplementedError, "#{Sketchup.platform} not supported"
  end

  dlload sketchup_app

  extern 'void SUGetAPIVersion(size_t*, size_t*)'
end

module CTypes

  FIDDLE_RUBY_FREE = Fiddle::Function.new(Fiddle::RUBY_FREE, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)

  class CType

    def initialize
      raise NotImplementedError
    end

    def to_ptr
      @ptr
    end

    def to_ruby
      raise NotImplementedError
    end

    def to_s
      to_ruby.to_s
    end

  end

  class CSimpleType < CType

    def to_ruby
      @ptr[0, @@TYPE_SIZE].unpack(@@PACK_FORMAT).first
    end

    private

    def type_check(value)
      raise NotImplementedError
    end

    class << self
      def define(type_size, pack_format, &block)
        class_eval do
          @@TYPE_SIZE = type_size
          @@PACK_FORMAT = pack_format
          @@PRECONDITIONS = block
  
          def initialize(value)
            @@PRECONDITIONS.call(value)
            @ptr = Fiddle::Pointer.malloc(@@TYPE_SIZE, FIDDLE_RUBY_FREE)
            @ptr[0, @@TYPE_SIZE] = [value].pack(@@PACK_FORMAT)
          end
  
        end
      end
    end

  end

  class SizeT < CSimpleType

    define(Fiddle::SIZEOF_SIZE_T, 'Q') do |value|
      raise TypeError, "expected integer type" unless value.is_a?(Integer)
      raise ArgumentError, "expected positive integer value" if value < 0
    end

    alias :to_i :to_ruby

  end

end # module

su_api_major = CTypes::SizeT.new(0)
su_api_minor = CTypes::SizeT.new(0)
SketchUpAPI.SUGetAPIVersion(su_api_major, su_api_minor)
puts "SUGetAPIVersion: #{su_api_major}.#{su_api_minor}"
