require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'

module Example

  module Win32API

    NULL = 0

    module Kernel32

      GMEM_FIXED = 0x0000
      GMEM_MOVEABLE = 0x0002

      extend Fiddle::Importer

      dlload 'Kernel32'
      include Fiddle::Win32Types

      typealias 'LPVOID', 'void*'
      typealias 'HGLOBAL', 'void*'
      typealias 'SIZE_T', 'size_t'

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

    include Win32API

    # TODO: Hide private methods: https://stackoverflow.com/a/35012552/486990

    # @private
    def self.assert_BOOL(win32bool)
      if win32bool == 0
        raise 'BOOL == 0'
        # TODO: Get error
      end
      win32bool
    end

    # @private
    def self.assert_pointer(win32pointer)
      if win32pointer == 0
        raise 'pointer == NULL'
        # TODO: Get error
      end
      win32pointer
    end


    def self.text
      # https://stackoverflow.com/a/14763025/486990

      hwnd = NULL
      assert_BOOL(User32.OpenClipboard(hwnd))

      # TODO: Enumerate clipboard data to check if text is available.

      handle = User32.GetClipboardData(User32::CF_TEXT)

      address = Kernel32.GlobalLock(handle)
      assert_pointer(address)

      pointer = Fiddle::Pointer.new(address)
      text = pointer.to_s

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
      lock_count = Kernel32.GlobalUnlock(handle)
      if lock_count == 0
        # TODO: Check GetLastError - if it returns NO_ERROR then everything is OK.
      else
        warn "clipboard data not unlocked! (Count: #{lock_count})"
      end

      assert_BOOL(User32.CloseClipboard)

      text
    end

    def self.text=(text)
      # MS Example:
      # https://docs.microsoft.com/en-gb/windows/win32/dataxchg/using-the-clipboard
      # TODO: Use as reference for error handling.


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

      output = Fiddle::Pointer[text]
      len = text.bytesize + 1

      mem = Kernel32.GlobalAlloc(Kernel32::GMEM_MOVEABLE, len)
      address = Kernel32.GlobalLock(mem)

      # memcpy(address, output, len)
      # This looks to be the Fiddle way to do the same as memcpy. Not sure if
      # the Ruby string pointer is NULL terminated, so not using `len` here.
      # TODO: Might the last byte be non-NULL as a result of doing this?
      pointer = Fiddle::Pointer.new(address)
      pointer[0, text.bytesize] = text

      lock_count = Kernel32.GlobalUnlock(mem)
      p [:lock_count, lock_count] # TODO: This appear to decrement to 0 as expected.

      hwnd = NULL
      assert_BOOL(User32.OpenClipboard(hwnd))

      # https://docs.microsoft.com/en-gb/windows/win32/api/winuser/nf-winuser-setclipboarddata?redirectedfrom=MSDN
      #
      # > If an application calls OpenClipboard with hwnd set to NULL,
      # > EmptyClipboard sets the clipboard owner to NULL; this causes
      # > SetClipboardData to fail.
      #
      # This doesn't appear to be true. This code calls OpenClipboard with NULL
      # and SetClipboardData succeeds.
      assert_BOOL(User32.EmptyClipboard)

      handle = User32::SetClipboardData(User32::CF_TEXT, mem)
      assert_pointer(handle)

      assert_BOOL(User32.CloseClipboard)
    end

  end
end

text = Example::Clipboard.text
puts "Clipboard text: #{text}"

# Example::Clipboard.text = 'Copy me!'
