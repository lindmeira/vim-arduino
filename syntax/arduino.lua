-- Language:    Arduino
-- Translated to Lua

if vim.fn.exists 'b:current_syntax' == 1 then
  return
end

-- Read the C++ syntax to start with
vim.cmd [[runtime! syntax/cpp.lua]]
-- fallback if cpp.lua doesn't exist (it usually is cpp.vim)
if vim.fn.exists 'b:current_syntax' == 0 then
  vim.cmd [[runtime! syntax/cpp.vim]]
end

local function keyword(group, words)
  vim.cmd('syn keyword ' .. group .. ' ' .. table.concat(words, ' '))
end

keyword('arduinoConstant', {
  'BIN',
  'CHANGE',
  'DEC',
  'DEFAULT',
  'EXTERNAL',
  'FALLING',
  'HALF_PI',
  'HEX',
  'HIGH',
  'INPUT',
  'INPUT_PULLUP',
  'INTERNAL',
  'INTERNAL1V1',
  'INTERNAL2V56',
  'LOW',
  'LSBFIRST',
  'MSBFIRST',
  'OCT',
  'OUTPUT',
  'PI',
  'RISING',
  'TWO_PI',
})

keyword('arduinoFunc', {
  'analogRead',
  'analogReference',
  'analogWrite',
  'attachInterrupt',
  'bit',
  'bitClear',
  'bitRead',
  'bitSet',
  'bitWrite',
  'delay',
  'delayMicroseconds',
  'detachInterrupt',
  'digitalRead',
  'digitalWrite',
  'highByte',
  'interrupts',
  'lowByte',
  'micros',
  'millis',
  'noInterrupts',
  'noTone',
  'pinMode',
  'pulseIn',
  'shiftIn',
  'shiftOut',
  'tone',
  'yield',
})

keyword('arduinoMethod', {
  'available',
  'availableForWrite',
  'begin',
  'charAt',
  'compareTo',
  'concat',
  'end',
  'endsWith',
  'equals',
  'equalsIgnoreCase',
  'find',
  'findUntil',
  'flush',
  'getBytes',
  'indexOf',
  'lastIndexOf',
  'length',
  'loop',
  'parseFloat',
  'parseInt',
  'peek',
  'print',
  'println',
  'read',
  'readBytes',
  'readBytesUntil',
  'readString',
  'readStringUntil',
  'replace',
  'setCharAt',
  'setTimeout',
  'setup',
  'startsWith',
  'substring',
  'toCharArray',
  'toInt',
  'toLowerCase',
  'toUpperCase',
  'trim',
  'word',
})

keyword('arduinoModule', {
  'Keyboard',
  'Mouse',
  'Serial',
  'Serial1',
  'Serial2',
  'Serial3',
  'SerialUSB',
})

keyword('arduinoStdFunc', {
  'abs',
  'accept',
  'acos',
  'asin',
  'atan',
  'atan2',
  'ceil',
  'click',
  'constrain',
  'cos',
  'degrees',
  'exp',
  'floor',
  'isPressed',
  'log',
  'map',
  'max',
  'min',
  'move',
  'pow',
  'press',
  'radians',
  'random',
  'randomSeed',
  'release',
  'releaseAll',
  'round',
  'sin',
  'sq',
  'sqrt',
  'tan',
})

keyword('arduinoType', {
  'boolean',
  'byte',
  'null',
  'String',
  'word',
})

vim.cmd [[
hi def link arduinoType Type
hi def link arduinoConstant Constant
hi def link arduinoStdFunc Function
hi def link arduinoFunc Function
hi def link arduinoMethod Function
hi def link arduinoModule Identifier
]]

vim.b.current_syntax = 'arduino'
