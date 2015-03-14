lua_utils
=========

A collection of utility Lua scripts usable in conjunction with MTA San Andreas.


### classlib.lua
This script helps out on the usage of classes and OOP in Lua. Additionally it allows an easily accessable per-element storage for MTA's elements similar to the following.
```lua
local player = getPlayerFromName("sbx320");
player.someVariableIWantToStore = "Hello World!";
```

Documentation for classlib.lua can be found here: https://github.com/sbx320/lua_utils/wiki/classlib

### async.lua
Async.lua is a wrapper around coroutines which allows coroutines to be paused and resumed a lot easier. In conjunction with MTA's dbQuery and dbPoll functions asyncronous SQL queries get very easy to handle.
