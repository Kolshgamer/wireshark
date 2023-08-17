# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

#[=======================================================================[.rst:
FindLua
-------

Locate Lua library.

.. versionadded:: 3.18
  Support for Lua 5.4.

This module defines:

``LUA_FOUND``
  if false, do not try to link to Lua
``LUA_LIBRARIES``
  both lua and lualib
``LUA_INCLUDE_DIR``
  where to find lua.h
``LUA_VERSION_STRING``
  the version of Lua found
``LUA_VERSION_MAJOR``
  the major version of Lua
``LUA_VERSION_MINOR``
  the minor version of Lua
``LUA_VERSION_PATCH``
  the patch version of Lua

Note that the expected include convention is

::

  #include "lua.h"

and not

::

  #include <lua/lua.h>

This is because, the lua location is not standardized and may exist in
locations other than lua/
#]=======================================================================]

cmake_policy(PUSH)  # Policies apply to functions at definition-time
cmake_policy(SET CMP0012 NEW)  # For while(TRUE)

INCLUDE(FindWSWinLibs)
FindWSWinLibs("lua-5*" "LUA_HINTS")

unset(_lua_include_subdirs)
unset(_lua_library_names)
unset(_lua_append_versions)

# this is a function only to have all the variables inside go away automatically
function(_lua_get_versions)
  set(LUA_VERSIONS5 ${LUA_FIND_VERSIONS})
  list(FILTER LUA_VERSIONS5 INCLUDE REGEX "5\.[21]")
  set(_lua_append_versions ${LUA_VERSIONS5})
  message(STATUS "Considering the following Lua versions: ${_lua_append_versions}")

  set(_lua_append_versions "${_lua_append_versions}" PARENT_SCOPE)
endfunction()

function(_lua_set_version_vars)
  set(_lua_include_subdirs_raw "lua")

  foreach (ver IN LISTS _lua_append_versions)
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)$" _ver "${ver}")
    list(APPEND _lua_include_subdirs_raw
        lua${CMAKE_MATCH_1}${CMAKE_MATCH_2}
        lua${CMAKE_MATCH_1}.${CMAKE_MATCH_2}
        lua-${CMAKE_MATCH_1}.${CMAKE_MATCH_2}
        )
  endforeach ()

  # Prepend "include/" to each path directly after the path
  set(_lua_include_subdirs "include")
  foreach (dir IN LISTS _lua_include_subdirs_raw)
    list(APPEND _lua_include_subdirs "${dir}" "include/${dir}")
  endforeach ()

  set(_lua_include_subdirs "${_lua_include_subdirs}" PARENT_SCOPE)
endfunction(_lua_set_version_vars)

function(_lua_get_header_version)
  unset(LUA_VERSION_STRING PARENT_SCOPE)
  set(_hdr_file "${LUA_INCLUDE_DIR}/lua.h")

  if (NOT EXISTS "${_hdr_file}")
    return()
  endif ()

  # At least 5.[012] have different ways to express the version
  # so all of them need to be tested. Lua 5.2 defines LUA_VERSION
  # and LUA_RELEASE as joined by the C preprocessor, so avoid those.
  file(STRINGS "${_hdr_file}" lua_version_strings
       REGEX "^#define[ \t]+LUA_(RELEASE[ \t]+\"Lua [0-9]|VERSION([ \t]+\"Lua [0-9]|_[MR])).*")

  string(REGEX REPLACE ".*;#define[ \t]+LUA_VERSION_MAJOR[ \t]+\"([0-9])\"[ \t]*;.*" "\\1" LUA_VERSION_MAJOR ";${lua_version_strings};")
  if (LUA_VERSION_MAJOR MATCHES "^[0-9]+$")
    string(REGEX REPLACE ".*;#define[ \t]+LUA_VERSION_MINOR[ \t]+\"([0-9])\"[ \t]*;.*" "\\1" LUA_VERSION_MINOR ";${lua_version_strings};")
    string(REGEX REPLACE ".*;#define[ \t]+LUA_VERSION_RELEASE[ \t]+\"([0-9])\"[ \t]*;.*" "\\1" LUA_VERSION_PATCH ";${lua_version_strings};")
    set(LUA_VERSION_STRING "${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}.${LUA_VERSION_PATCH}")
  else ()
    string(REGEX REPLACE ".*;#define[ \t]+LUA_RELEASE[ \t]+\"Lua ([0-9.]+)\"[ \t]*;.*" "\\1" LUA_VERSION_STRING ";${lua_version_strings};")
    if (NOT LUA_VERSION_STRING MATCHES "^[0-9.]+$")
      string(REGEX REPLACE ".*;#define[ \t]+LUA_VERSION[ \t]+\"Lua ([0-9.]+)\"[ \t]*;.*" "\\1" LUA_VERSION_STRING ";${lua_version_strings};")
    endif ()
    string(REGEX REPLACE "^([0-9]+)\\.[0-9.]*$" "\\1" LUA_VERSION_MAJOR "${LUA_VERSION_STRING}")
    string(REGEX REPLACE "^[0-9]+\\.([0-9]+)[0-9.]*$" "\\1" LUA_VERSION_MINOR "${LUA_VERSION_STRING}")
    string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.([0-9]).*" "\\1" LUA_VERSION_PATCH "${LUA_VERSION_STRING}")
  endif ()
  foreach (ver IN LISTS _lua_append_versions)
    if (ver STREQUAL "${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}")
      set(LUA_VERSION_MAJOR ${LUA_VERSION_MAJOR} PARENT_SCOPE)
      set(LUA_VERSION_MINOR ${LUA_VERSION_MINOR} PARENT_SCOPE)
      set(LUA_VERSION_PATCH ${LUA_VERSION_PATCH} PARENT_SCOPE)
      set(LUA_VERSION_STRING ${LUA_VERSION_STRING} PARENT_SCOPE)
      return()
    endif ()
  endforeach ()
endfunction(_lua_get_header_version)

function(_lua_find_header)
  _lua_set_version_vars()

  # Initialize as local variable
  set(CMAKE_IGNORE_PATH ${CMAKE_IGNORE_PATH})
  while (TRUE)
    # Find the next header to test. Check each possible subdir in order
    # This prefers e.g. higher versions as they are earlier in the list
    # It is also consistent with previous versions of FindLua
    foreach (subdir IN LISTS _lua_include_subdirs)
      find_path(LUA_INCLUDE_DIR lua.h
        HINTS ${LUA_HINTS} ENV LUA_DIR
        PATH_SUFFIXES ${subdir}
        )
      if (LUA_INCLUDE_DIR)
        break()
      endif()
    endforeach()
    # Did not found header -> Fail
    if (NOT LUA_INCLUDE_DIR)
      return()
    endif()
    _lua_get_header_version()
    # Found accepted version -> Ok
    if (LUA_VERSION_STRING)
      if (LUA_Debug)
        message(STATUS "Found suitable version ${LUA_VERSION_STRING} in ${LUA_INCLUDE_DIR}/lua.h")
      endif()
      return()
    endif()
    # Found wrong version -> Ignore this path and retry
    if (LUA_Debug)
      message(STATUS "Ignoring unsuitable version in ${LUA_INCLUDE_DIR}")
    endif()
    list(APPEND CMAKE_IGNORE_PATH "${LUA_INCLUDE_DIR}")
    unset(LUA_INCLUDE_DIR CACHE)
    unset(LUA_INCLUDE_DIR)
    unset(LUA_INCLUDE_DIR PARENT_SCOPE)
  endwhile ()
endfunction()

_lua_get_versions()
_lua_find_header()
_lua_get_header_version()
unset(_lua_append_versions)

if (LUA_VERSION_STRING)
  set(_lua_library_names
    lua${LUA_VERSION_MAJOR}${LUA_VERSION_MINOR}
    lua${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}
    lua-${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}
    lua.${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}
    )
endif ()

find_library(LUA_LIBRARY
  NAMES ${_lua_library_names} lua
  NAMES_PER_DIR
  HINTS
    ${LUA_HINTS}
    ENV LUA_DIR
  PATH_SUFFIXES lib
)
unset(_lua_library_names)

if (LUA_LIBRARY)
  # include the math library for Unix
  if (UNIX AND NOT APPLE AND NOT BEOS)
    find_library(LUA_MATH_LIBRARY m)
    mark_as_advanced(LUA_MATH_LIBRARY)
    set(LUA_LIBRARIES "${LUA_LIBRARY};${LUA_MATH_LIBRARY}")

    # include dl library for statically-linked Lua library
    get_filename_component(LUA_LIB_EXT ${LUA_LIBRARY} EXT)
    if(LUA_LIB_EXT STREQUAL CMAKE_STATIC_LIBRARY_SUFFIX)
      list(APPEND LUA_LIBRARIES ${CMAKE_DL_LIBS})
    endif()

  # For Windows and Mac, don't need to explicitly include the math library
  else ()
    set(LUA_LIBRARIES "${LUA_LIBRARY}")
  endif ()
endif ()

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LUA_FOUND to TRUE if
# all listed variables are TRUE
FIND_PACKAGE_HANDLE_STANDARD_ARGS(Lua
                                  REQUIRED_VARS LUA_LIBRARIES LUA_INCLUDE_DIR
                                  VERSION_VAR LUA_VERSION_STRING)

mark_as_advanced(LUA_INCLUDE_DIR LUA_LIBRARY)

cmake_policy(POP)

IF(Lua_FOUND)
  SET( LUA_INCLUDE_DIRS ${LUA_INCLUDE_DIR} )
  if (WIN32)
    set ( LUA_DLL_DIR "${LUA_HINTS}" CACHE PATH "Path to Lua DLL")
    file( GLOB _lua_dll RELATIVE "${LUA_DLL_DIR}" "${LUA_DLL_DIR}/lua*.dll")
    set ( LUA_DLL ${_lua_dll} CACHE FILEPATH "Lua DLL file name")
    mark_as_advanced( LUA_DLL_DIR LUA_DLL )
  endif()
  if(LUA_DLL_DIR MATCHES ".*/lua-.*-unicode-.*")
    # Do we have Lua with Unicode for Windows patches?
    # https://github.com/Lekensteyn/lua-unicode
    # XXX Would be better if it was possible to
    # detect a Lua-unicode build from C and Lua code
    # but upstream rejected patches for that so we do
    # it here.
    set(HAVE_LUA_UNICODE True)
  endif()
ELSE(Lua_FOUND)
  SET( LUA_LIBRARIES )
  SET( LUA_INCLUDE_DIRS )
  SET( LUA_DLL_DIR )
  SET( LUA_DLL )
ENDIF(Lua_FOUND)
