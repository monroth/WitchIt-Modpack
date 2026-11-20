-- Marker colours: the panel's seven swatches.
local M={}
M.PALETTE={
    {R=.33834901452064514,G=0,B=.921999990940094,A=1},
    {R=1,G=.8192780017852783,B=.09399999678134918,A=1},
    {R=0,G=.5219209790229797,B=.8999999761581421,A=1},
    {R=.2274789959192276,G=.9734449982643127,B=.05315500125288963,A=1},
    {R=.6927080154418945,G=.08415199816226959,B=0,A=1},
    {R=1,G=.2,B=.44,A=1},{R=1,G=1,B=1,A=1}}
M.NAMES={'Purple','Yellow','Blue','Green','Orange','Pink','White'}
M.PINK=M.PALETTE[6]   -- (the marker colour mods start with)
return M
