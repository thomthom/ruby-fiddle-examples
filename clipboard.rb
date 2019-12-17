require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'

module Example

  module Win32API

    NULL = 0

    NO_ERROR = 0

    # https://docs.microsoft.com/en-gb/windows/win32/debug/system-error-codes
    ERROR_SUCCESS = 0x00
    ERROR_NOT_LOCKED = 0x9E
    ERROR_CLIPBOARD_NOT_OPEN = 0x58A

    module Kernel32

      GMEM_FIXED = 0x0000
      GMEM_MOVEABLE = 0x0002

      extend Fiddle::Importer

      dlload 'Kernel32'
      include Fiddle::Win32Types

      typealias 'LPVOID', 'void*'
      typealias 'HGLOBAL', 'void*'
      typealias 'SIZE_T', 'size_t'

      # https://docs.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-getlasterror
      #
      # DWORD GetLastError()
      extern 'DWORD GetLastError()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globallock
      #
      # A handle to the global memory object. This handle is returned by either
      # the GlobalAlloc or GlobalReAlloc function.
      #
      # Return: If the function succeeds, the return value is a pointer to the
      #         first byte of the memory block.
      #         If the function fails, the return value is NULL. To get extended
      #         error information, call GetLastError.
      #
      # LPVOID GlobalLock(
      #   HGLOBAL hMem
      # );
      extern 'LPVOID GlobalLock(HGLOBAL)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globallock
      #
      # A handle to the global memory object. This handle is returned by either
      # the GlobalAlloc or GlobalReAlloc function.
      #
      # Return: If the memory object is still locked after decrementing the lock
      #         count, the return value is a nonzero value. If the memory object
      #         is unlocked after decrementing the lock count, the function
      #         returns zero and GetLastError returns NO_ERROR.
      #
      #         If the function fails, the return value is zero and GetLastError
      #         returns a value other than NO_ERROR.
      #
      # BOOL GlobalUnlock(
      #   HGLOBAL hMem
      # );
      extern 'BOOL GlobalUnlock(HGLOBAL)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-globalalloc
      # DECLSPEC_ALLOCATOR HGLOBAL GlobalAlloc(
      #   UINT   uFlags,
      #   SIZE_T dwBytes
      # );
      extern 'HGLOBAL GlobalAlloc(UINT, SIZE_T)'

    end


    module User32

      # Copied from the WinUser.h header
      CF_TEXT = 1

      extend Fiddle::Importer

      dlload 'User32'
      include Fiddle::Win32Types

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard
      #
      # A handle to the window to be associated with the open clipboard. If this
      # parameter is NULL, the open clipboard is associated with the current task.
      #
      # Return: 0 = error; non-0 = success
      #
      # BOOL OpenClipboard(
      #   HWND hWndNewOwner
      # );
      extern 'BOOL OpenClipboard(HWND)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-closeclipboard
      # Return: 0 = error; non-0 = success
      #
      # BOOL CloseClipboard();
      extern 'BOOL CloseClipboard()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-emptyclipboard
      # Return: 0 = error; non-0 = success
      #
      # BOOL EmptyClipboard();
      extern 'BOOL EmptyClipboard()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclipboarddata
      # Return: NULL upon failure
      #
      # uFormat
      #   https://docs.microsoft.com/en-us/windows/win32/dataxchg/clipboard-formats
      #
      # HANDLE GetClipboardData(
      #   UINT uFormat
      # );
      extern 'HANDLE GetClipboardData(UINT)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setclipboarddata
      # Return: If the function succeeds, the return value is the handle to the
      #         data.
      #
      #         If the function fails, the return value is NULL. To get extended
      #         error information, call GetLastError.
      #
      # HANDLE SetClipboardData(
      #   UINT   uFormat,
      #   HANDLE hMem
      # );
      extern 'HANDLE SetClipboardData(UINT, HANDLE)'


    end

  end


  module Clipboard
    # Doing this to be able to hide internal methods from the Clipboard
    # public interface.
    class << self

      class ClipboardError < StandardError; end

      include Win32API

      def text
        open_clipboard do
          handle = User32.GetClipboardData(User32::CF_TEXT)
          raise ClipboardError, 'Unable to get clipboard data' if handle == NULL

          clipboard_text = global_lock(handle) do |address|

            pointer = Fiddle::Pointer.new(address)
            pointer.to_s # This read the pointer as a string until a NULL char.

          end

          # TODO: For some reason this seems to always return 1 - indicating it isn't
          #       decrementing the lock count.
          #
          # https://devblogs.microsoft.com/oldnewthing/20041108-00/?p=37363
          #
          # > Moveability semantics were preserved. Memory blocks still had a lock
          # > count, even though it didn’t really accomplish anything since Win32
          # > never compacted memory. (Recall that the purpose of the lock count was
          # > to prevent memory from moving during a compaction.)
          # ...
          # > Consequently, the charade of locking must be maintained just in case
          # > there’s some application that actually snoops at the lock count, or a
          # > program that expected the GlobalReAlloc function to fail on a locked
          # > block
          # lock_count = Kernel32.GlobalUnlock(handle)
          # if lock_count == 0
          #   code = Kernel32.GetLastError
          #   unless code == NO_ERROR
          #     warn "Clipboard data unlock error! (Error code: #{code})"
          #   end
          # else
          #   warn "Clipboard data not unlocked! (Count: #{lock_count})"
          # end

          clipboard_text
        end
      end

      def text=(clipboard_text)
        # https://docs.microsoft.com/en-gb/windows/win32/dataxchg/using-the-clipboard

        # StackOverflow Example:
        #
        # const char* output = "Test";
        # const size_t len = strlen(output) + 1;
        #
        # HGLOBAL hMem =  GlobalAlloc(GMEM_MOVEABLE, len);
        # memcpy(GlobalLock(hMem), output, len);
        # GlobalUnlock(hMem);
        #
        # OpenClipboard(0);
        # EmptyClipboard();
        # SetClipboardData(CF_TEXT, hMem);
        # CloseClipboard();

        # While in C you get a NULL terminated string from a char* literal,
        # it's not clear if Ruby provides this. Ruby can in some cases allow
        # NULL characters in its strings. The US-ASCII encoding for instance is
        # used to load binary data in Ruby.
        #
        # The Win32 clipboard assumes NULL means end of string. But with normal
        # UTF-8 encoded strings we should be fine because UTF-8 doesn't use
        # NULL bytes for anything other than code point 0.
        #
        # Note that we use `bytesize` here as `size` would return code points
        # and not the number of char* we need to provide.
        buffer_length = clipboard_text.bytesize

        mem = Kernel32.GlobalAlloc(Kernel32::GMEM_MOVEABLE, buffer_length)
        raise ClipboardError, 'Unable to allocate global data' if mem == NULL

        global_lock(mem) do |address|

          # C example:
          #   memcpy(address, output, buffer_length)
          #
          # This looks to be the Fiddle way to do the same as memcpy.
          # While we don't include the size + 1 to include the NULL character
          # (which we aren't sure Ruby gives us) it appear that the Win32 API
          # is handling this for us. When we get the text back from the
          # clipboard the Pointer#to_s method seems to correctly stop where it
          # should.
          pointer = Fiddle::Pointer.new(address)
          pointer[0, clipboard_text.bytesize] = clipboard_text

          open_clipboard do
            # https://docs.microsoft.com/en-gb/windows/win32/api/winuser/nf-winuser-setclipboarddata?redirectedfrom=MSDN
            #
            # > If an application calls OpenClipboard with hwnd set to NULL,
            # > EmptyClipboard sets the clipboard owner to NULL; this causes
            # > SetClipboardData to fail.
            #
            # This doesn't appear to be true. This code calls OpenClipboard with
            # NULL and SetClipboardData succeeds.
            assert_BOOL(User32.EmptyClipboard)

            handle = User32::SetClipboardData(User32::CF_TEXT, mem)
            assert_pointer(handle)
          end
        end
      end

      private

      # Utility method to ensure the clipboard is always closed even if errors
      # should be thrown within the block.
      #
      # hwnd = NULL # Associate the opened clipboard with the current task.
      def open_clipboard(hwnd = NULL, &block)
        assert_BOOL(User32.OpenClipboard(hwnd))
        block.call
      ensure
        assert_BOOL(User32.CloseClipboard)
      end

      # Utility method to ensure the lock is always released even if errors
      # are thrown within the block.
      def global_lock(mem, &block)
        address = Kernel32.GlobalLock(mem)
        assert_pointer(address)
        begin
          block.call(address)
        ensure
          lock_count = Kernel32.GlobalUnlock(mem)
          if lock_count == 0
            code = Kernel32.GetLastError
            unless code == NO_ERROR
              warn "Clipboard data unlock error! (Error code: #{code})"
            end
          else
            warn "Clipboard data not unlocked! (Count: #{lock_count})"
          end
        end
      end

      def assert_BOOL(win32bool)
        if win32bool == 0
          raise "BOOL == 0 - error: #{Kernel32.GetLastError}"
        end
        win32bool
      end

      def assert_pointer(win32pointer)
        if win32pointer == 0
          raise "pointer == NULL - error: #{Kernel32.GetLastError}"
        end
        win32pointer
      end

    end
  end
end

text = Example::Clipboard.text
puts "Clipboard text: #{text}"

Example::Clipboard.text = 'Copy me!'
