# Collection of Ruby Fiddle Examples/Experiments

## clipboard.rb

Using Win32 API to copy/paste plain text to/from the clipboard.

```ruby
text = Example::Clipboard.text
puts "Clipboard text: #{text}"

Example::Clipboard.text = 'Copy me!'
```
