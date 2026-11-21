local M=dofile('candidate/runtime-source/Core/mapdata.lua')
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local function unhex(h) return (h:gsub('%x%x',function(x) return string.char(tonumber(x,16)) end)) end

-- No footer: everything is the game's.
local game,records=M.split('\1\2\3')
assert(game=='\1\2\3' and next(records)==nil,'bytes without a tail')
assert(M.join('\1\2\3',{})=='\1\2\3','no records, no tail')

-- Round trip, sorted ids, other records kept byte for byte.
local block=M.join('\0\1',{['monroth.fap']={version=1,data='{"kind":"respawn"}'},['anium.imp']={version=2,data='\199\29\255'}})
game,records=M.split(block)
assert(game=='\0\1','game bytes stay in front')
assert(records['monroth.fap'].version==1 and records['monroth.fap'].data=='{"kind":"respawn"}','own record')
assert(records['anium.imp'].version==2 and records['anium.imp'].data=='\199\29\255','foreign record')
records['monroth.fap']=nil
local _,after=M.split(M.join(game,records))
assert(after['anium.imp'].data=='\199\29\255' and after['monroth.fap']==nil,'rewriting keeps the other module')

-- The map record holds a record list.
local whole=M.list({manifest={version=1,data='{"needs":{},"modes":[]}'},['monroth.bwp']={version=1,data='{}'}})
local _,inner=M.read_list(whole)
assert(inner.manifest.data=='{"needs":{},"modes":[]}' and inner['monroth.bwp'].data=='{}','map record list')

-- Broken tails are reported, not guessed.
assert(M.split('\1'..string.pack('<I4',99)..'WIP1')==nil,'tail longer than the bytes')
assert(not pcall(M.list,{['Bad Id']={version=1,data=''}}),'ids are lowercase ascii')

-- Same bytes as the converter's Python codec.
local pipe=io.popen([[python3 -c "
import sys;sys.path.insert(0,'tooling/LayoutExporter');import mapdata as m
print(m.join(bytes([0,1]),{'monroth.fap':(1,b'{\"kind\":\"respawn\"}'),'anium.imp':(2,bytes([199,29,255]))}).hex())"]])
local python=pipe:read('*a'):match('%x+');pipe:close()
assert(python==hex(block),'Lua and Python write the same tail')
game,records=M.split(unhex(python))
assert(game=='\0\1' and records['anium.imp'].data=='\199\29\255','Lua reads the Python tail')
print('PASS map data tail codec')
