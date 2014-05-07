-- Zi color terminal theme
--
-- Copyright (c) 2011 Free Software Foundation, Inc.
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

{
  settings = {
    selection = 'blue',
  },
  {
    scope = 'modeline',
    settings = { background = 'green', foreground = 'black' },
  },
  {
    scope = 'comment',
    settings = { fontStyle = 'bold' },
  },
  {
    scope = 'constant.language',
    settings = { fontStyle = 'bold', foreground = 'magenta' },
  },
  {
    scope = 'constant.other',
    settings = 'red',
  },
  {
    scope = 'constant',
    settings = 'magenta',
  },
  {
    scope = 'entity.name.function',
    settings = { fontStyle = 'bold', foreground = 'blue' },
  },
  {
    scope = 'entity.name.function.scope',
    settings = 'blue',
  },
  {
    scope = 'keyword',
    settings = { fontStyle = 'bold', foreground = 'green' },
  },
  {
    scope = 'keyword.operator',
    settings = 'yellow',
  },
  {
    scope = 'string',
    settings = 'white',
  },
  {
    scope = 'support.function',
    settings = 'cyan',
  },
  {
    scope = 'invalid',
    settings = { fontStyle = 'reverse', foreground = 'red' },
  },
  {
    scope = 'storage',
    settings = { fontstyle = 'bold', foreground = 'yellow' },
  },
  {
    scope = 'storage.modifier',
    settings = 'yellow',
  },
  {
    scope = 'variable',
    settings = 'blue',
  },
  {
    scope = 'variable.other',
    settings = { fontStyle = 'bold', foreground = 'blue' },
  },
}
