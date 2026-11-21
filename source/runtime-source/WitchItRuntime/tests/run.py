"""Parse every owned Lua file and execute the two small engine-order checks."""
import ctypes
from pathlib import Path

lua = ctypes.CDLL('liblua5.4.so.0')
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
roots = [Path('candidate/runtime-source') / name for name in ('WitchItRuntime', 'Core')]
files = sorted(p for root in roots for p in root.rglob('*.lua'))
for path in files:
    state = lua.luaL_newstate()
    lua.luaL_openlibs(state)
    result = lua.luaL_loadfilex(state, str(path).encode(), None)
    if not result and path.parent.name == 'tests':
        result = lua.lua_pcallk(state, 0, 0, 0, 0, None)
    if result:
        raise SystemExit(f'{path}: {lua.lua_tolstring(state, -1, None).decode()}')
    lua.lua_close(state)
print(f'Parsed {len(files)} Lua files; engine-order checks passed.')
