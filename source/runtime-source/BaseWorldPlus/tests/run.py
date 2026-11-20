import ctypes,sys
from pathlib import Path
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ssize_t,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
paths=sys.argv[1:] or sorted(str(p) for p in Path('candidate/runtime-source/BaseWorldPlus').rglob('*.lua'))
for path in paths:
 s=lib.luaL_newstate();lib.luaL_openlibs(s)
 status=lib.luaL_loadfilex(s,path.encode(),None)
 if not status and sys.argv[1:]:status=lib.lua_pcallk(s,0,-1,0,0,None)
 if status:raise SystemExit(f'{path}: {lib.lua_tolstring(s,-1,None).decode()}')
 lib.lua_close(s)
print(f'Lua 5.4: {len(paths)} files passed')
