-- Copyright (c) 2009-2013 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- This program is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

--[[--
 Zmacs Lisp Evaluator.

 Extends the base ZLisp Interpreter with a func-table symbol type,
 that can be called like a regular function, but also contains its own
 metadata.  Additionally, like ELisp, we keep variables in their own
 namespace, and give each buffer it's own local list of variables for
 the various buffer-local variables we want to provide.

 Compared to the basic ZLisp Interpreter, this evaluator has to do
 a lot more work to keep an undo list, allow recording of keyboard
 macros and, again like Emacs, differentiate between interactive and
 non-interactive calls.

 @module zmacs.eval
]]


local lisp = require "zmacs.zlisp"
local Cons, fetch = lisp.Cons, lisp.fetch



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


local Defun, marshaller, namer -- forward declarations

--- Define a command in the execution environment for the evaluator.
-- @string name command name
-- @tparam table argtypes a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @func func function to call after marshalling arguments
function Defun (name, argtypes, doc, interactive, func)

  --- Command table.
  -- The data associated with a given command.
  -- @table command
  -- @string name command name
  -- @tfield table a list of type strings that arguments must match
  -- @string doc docstring
  -- @bool interactive `true` if this command can be called interactively
  -- @func func function to call after marshalling arguments
  local command = {
    name        = name,
    argtypes    = argtypes,
    doc         = texi (doc:chomp ()),
    interactive = interactive,
    func        = func,
  }

  lisp.define (name,
    setmetatable (command, {
      __call     = marshaller,
      __tostring = namer,
    })
  )
end


--- Argument marshalling and type-checking for zlisp commands.
-- Used as the `__call` metamethod for commands.
-- @local
-- @tparam command command data
-- @tparam zile.Cons arglist arguments for this command
-- @return result of calling this command
function marshaller (command, arglist)
  local args, i = {}, 1

  while arglist and arglist.car do
    local val, ty = arglist.car, command.argtypes[i]
    if ty == "number" then
      val = tonumber (val.value, 10)
    elseif ty == "boolean" then
      val = val.value ~= "nil"
    elseif ty == "string" then
      val = tostring (val.value)
    end
    table.insert (args, val)
    arglist = arglist.cdr
    i = i + 1
  end

  current_prefix_arg, prefix_arg = prefix_arg, false

  return command.func (unpack (args)) or true
end


--- Easy command name access with @{tostring}.
-- Used as the `__tostring` metamethod of commands.
-- @local
-- @tparam command command data
-- @treturn string name of this command
function namer (command)
  return command.name
end



--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


--- Variable docs and other metadata.
local metadata = {}


--- Convert a '-' delimited symbol-name to be '_' delimited.
-- @function name_to_key
-- @string name a '-' delimited symbol-name
-- @treturn string `name` with all '-' transformed into '_'.
local name_to_key = memoize (function (name)
  return string.gsub (name, "-", "_")
end)


--- Mapping between variable names and values.
-- Make a proxy table for main variables stored according to canonical
-- "_" delimited format, along with metamethods that access the proxy
-- while transparently converting to and from zlisp "-" delimited
-- format.
-- @table main_vars
main_vars = setmetatable ({values = {}}, {
  __index = function (self, name)
    return rawget (self.values, name_to_key (name))
  end,

  __newindex = function (self, name, value)
    return rawset (self.values, name_to_key (name), value)
  end,

  __pairs = function (self)
    return function (t, k)
	     local v, j = next (t, k and name_to_key (k) or nil)
	     return v and v:gsub ("_", "-") or nil, j
	   end, self.values, nil
  end,
})


--- Define a new variable.
-- Store the value and docstring for a variable for later retrieval.
-- @string name variable name
-- @param value value to store in variable `name`
-- @string doc variable's docstring
local function Defvar (name, value, doc)
  local key = name_to_key (name)
  main_vars[key] = value
  metadata[key] = { doc = texi (doc:chomp ()) }
end


--- Set a variable's buffer-local behaviour.
-- Any variable marked this way becomes a buffer-local version of the
-- same when set in any way.
-- @string name variable name
-- @tparam bool bool `true` to mark buffer-local, `false` to unmark.
-- @treturn bool the new buffer-local status
function set_variable_buffer_local (name, bool)
  return rawset (metadata[name_to_key (name)], "islocal", not not bool)
end


--- Return the value of a variable in a particular buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
function get_variable (name, bp)
  return ((bp or cur_bp or {}).vars or main_vars)[name_to_key (name)]
end


--- Coerce a variable value to a number.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @treturn number the number value of `name` from buffer `bp`
function get_variable_number (name, bp)
  return tonumber (get_variable (name, bp), 10)
end


--- Coerce a variable value to a boolean.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @treturn bool the bool value of `name` from buffer `bp`
function get_variable_bool (name, bp)
  return get_variable (name, bp) ~= "nil"
end


--- Return the docstring for a variable.
-- @string name variable name
-- @treturn string the docstring for `name` if any, else ""
function get_variable_doc (name)
  local t = metadata[name_to_key (name)]
  return t and t.doc or ""
end


--- Return a table of all variables
-- @treturn table all variables and their values in a table
function get_variable_table ()
  return main_vars
end


--- Assign a value to variable in a given buffer.
-- @string name variable name
-- @param value value to assign to `name`
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the new value of `name` from buffer `bp`
function set_variable (name, value, bp)
  local key = name_to_key (name)
  local t = metadata[key]
  if t and t.islocal then
    bp = bp or cur_bp
    bp.vars = bp.vars or {}
    bp.vars[key] = value
  else
    main_vars[key]= value
  end

  return value
end

--- Initialise buffer local variables.
-- @tparam buffer bp a buffer
function init_buffer (bp)
  bp.vars = setmetatable ({}, {
    __index    = main_vars.values,

    __newindex = function (self, name, value)
	           local key = name_to_key (name)
		   local t = metadata[key]
		   if t and t.islocal then
		     return rawset (self, key, value)
		   else
		     return rawset (main_vars, key, value)
		   end
                 end,
  })

  if get_variable_bool ("auto_fill_mode", bp) then
    bp.autofill = true
  end
end



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


--- Execute a function non-interactively.
-- @tparam command|string cmd_or_name command or name of command to execute
-- @param[opt=nil] uniarg a single non-table argument for `cmd_or_name`
local function execute_function (cmd_or_name, uniarg)
  local cmd, ok = cmd_or_name, false

  if type (cmd_or_name) ~= "table" then
    cmd = fetch (cmd_or_name)
  end

  if uniarg ~= nil and type (uniarg) ~= "table" then
    uniarg = Cons ({value = uniarg and tostring (uniarg) or nil})
  end

  command.attach_label (nil)
  ok = cmd and cmd (uniarg)
  command.next_label ()

  return ok
end

--- Call a zlisp command with arguments, interactively.
-- @tparam command cmd a value already passed to @{Defun}
-- @tparam zile.Cons arglist arguments for `name`
-- @return the result of calling `name` with `arglist`, or else `nil`
local function call_command (cmd, arglist)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = execute_function (cmd, arglist)
  command.interactive_exit ()

  -- Only add keystrokes if we were already in macro defining mode
  -- before the function call, to cope with start-kbd-macro.
  if lastflag.defining_macro and thisflag.defining_macro then
    add_cmd_to_macro ()
  end

  if cur_bp and not command.was_labelled (":undo") then
    cur_bp.next_undop = cur_bp.last_undop
  end

  lastflag = thisflag

  return ok
end


--- Evaluate a single command expression.
-- @tparam zile.Cons list a cons list, where the first element is a
--   command name.
-- @return the result of evaluating `list`, or else `nil`
local function evaluate_command (list)
  return list and list.car and call_command (list.car.value, list.cdr) or nil
end


--- Evaluate one arbitrary expression.
-- This function is required to implement ZLisp special forms, such as
-- `setq`, where some nodes of the AST are evaluated and others are not.
-- @tparam zile.Cons node a node of the AST from @{zmacs.zlisp.parse}.
-- @treturn zile.Cons the result of evaluating `node`
local function evaluate_expression (node)
  if fetch (node.value) ~= nil then
    return node.quoted and node or evaluate_command (node)
  elseif node.value == "t" or node.value == "nil" then
    return node
  end
  return Cons (get_variable (node.value) or node)
end


--- Evaluate a string of zlisp code.
-- @function loadstring
-- @string s zlisp source
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_string (s)
  local ok, list = pcall (lisp.parse, s)
  if not ok then return nil, list end

  while list do
    evaluate_command (list.car.value)
    list = list.cdr
  end
  return true
end


--- Evaluate a file of zlisp.
-- @function loadfile
-- @param file path to a file of zlisp code
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_file (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = evaluate_string (s)
  end

  return s, errmsg
end


------
-- Fetch the value of a defined symbol name.
-- @function fetch
-- @string name the symbol name
-- @return the associated symbol value if any, else `nil`


------
-- Symbol table iterator, for use with `for` loops.
--     for name, value in zlisp.symbols() do
-- @function commands
-- @treturn function iterator
-- @treturn table symbol table


--- @export
return {
  Defun               = Defun,
  Defvar              = Defvar,
  call_command        = call_command,
  evaluate_expression = evaluate_expression,
  fetch               = fetch,
  loadfile            = evaluate_file,
  loadstring          = evaluate_string,
  execute_function    = execute_function,

  -- Copy some commands into our namespace directly.
  commands             = lisp.symbols,
}
