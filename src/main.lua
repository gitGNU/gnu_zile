-- Program invocation, startup and shutdown
--
-- Copyright (c) 2010-2012 Free Software Foundation, Inc.
--
-- This file is part of Zee.
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

-- Derived constants
VERSION_STRING = PACKAGE_NAME .. " " .. VERSION

local COPYRIGHT_STRING = "Copyright (C) 2012 Free Software Foundation, Inc."

prog = {
  name = posix.basename (arg[0] or PACKAGE),
  banner = VERSION_STRING .. " by Reuben Thomas <rrt@sc3d.org>",
  purpose = "An editor.",
  notes = COPYRIGHT_STRING .. "\n" ..
    PACKAGE_NAME .. " comes with ABSOLUTELY NO WARRANTY.\n" ..
    "You may redistribute copies of " .. PACKAGE_NAME .. "\n" ..
    "under the terms of the GNU General Public License.\n" ..
    "For more information about these matters, see the file named COPYING.\n" ..
    "Report bugs to " .. PACKAGE_BUGREPORT .. ".",
}


-- Runtime constants

-- Display attributes
display = {}

-- Keyboard handling

GETKEY_DEFAULT = -1
GETKEY_DELAYED = 2000

-- Global variables
main_vars = {}
function X (name, default_value, local_when_set, docstring)
  main_vars[name] = {val = default_value, islocal = local_when_set, doc = texi (docstring)}
end
require "tbl_vars"
X = nil


-- Global flags, stored in thisflag and lastflag.
-- need_resync:    a resync is required.
-- quit:           the user has asked to quit.
-- set_uniarg:     the last command modified the universal arg variable `uniarg'.
-- uniarg_empty:   current universal arg is just C-u's with no number.
-- defining_macro: we are defining a macro.


-- Default waitkey pause in ds
WAITKEY_DEFAULT = 20

-- The current window
cur_wp = nil

-- The current buffer
cur_bp = nil

-- The global editor flags.
thisflag = {}
lastflag = {}


options = {
  Option {{"no-init-file", 'q'}, "do not load ~/." .. PACKAGE},
  Option {{"funcall", 'f'}, "call function FUNC with no arguments", "Req", "FUNC"},
  Option {{"load", 'l'}, "load Lua FILE using the load function", "Req", "FILE"},
  Option {{"line", 'n'}, "start editing at line LINE", "Req", "LINE"},
}

local function segv_sig_handler (signo)
  io.stderr:write (prog.name .. ": " .. PACKAGE_NAME ..
                   " crashed.  Please send a bug report to <" ..
                   PACKAGE_BUGREPORT .. ">.\r\n")
  editor_exit (true)
end

local function other_sig_handler (signo)
  local msg = prog.name .. ": terminated with signal " .. signo .. ".\n" .. debug.traceback ()
  io.stderr:write (msg:gsub ("\n", "\r\n"))
  editor_exit (false)
end

local function signal_init ()
  -- Set up signal handling
  posix.signal(posix.SIGSEGV, segv_sig_handler)
  posix.signal(posix.SIGBUS, segv_sig_handler)
  posix.signal(posix.SIGHUP, other_sig_handler)
  posix.signal(posix.SIGINT, other_sig_handler)
  posix.signal(posix.SIGTERM, other_sig_handler)
end

function main ()
  signal_init ()
  getopt.processArgs ()

  local file
  if #arg ~= 1 then
    getopt.usage ()
    os.exit (1)
  else
    file = normalize_path (arg[1])
  end

  os.setlocale ("")
  term_init ()
  init_default_bindings ()
  create_window ()

  if not getopt.opt["no-init-flag"] then
    -- local s = os.getenv ("HOME")
    -- if s then
    --   lisp_loadfile (s .. "/." .. PACKAGE)
    -- end
  end

  -- Load file
  local ok = find_file (file)
  if ok then
    execute_function ("edit-goto-line", getopt.opt.line and getopt.opt.line[#getopt.opt.line] or 1)
    lastflag.need_resync = true
  end

  -- Load Lua files and run functions given on the command line.
  -- FIXME: Just have one option to run Lua expressions.
  for _, f in ipairs (getopt.opt.funcall or {}) do
    ok = execute_function (f)
    if ok == nil then
      minibuf_error (string.format ("Function `%s' not defined", f))
    end
    if thisflag.quit then
      break
    end
  end
  if not thisflag.quit then
    for _, f in ipairs (getopt.opt.load or {}) do
      ok = execute_function ("load", normalize_path (f))
      if not ok then
        minibuf_error (string.format ("Cannot open load file: %s\n", f))
      end
      if thisflag.quit then
        break
      end
    end
  end

  lastflag.need_resync = true

  -- Reinitialise the buffer to catch settings
  init_buffer (cur_bp)

  -- Refresh minibuffer in case there was an error that couldn't be
  -- written during startup
  minibuf_refresh ()

  -- Run the main loop.
  while not thisflag.quit do
    if lastflag.need_resync then
      window_resync (cur_wp)
    end
    get_and_run_command ()
  end

  -- Tidy and close the terminal.
  term_finish ()
end
