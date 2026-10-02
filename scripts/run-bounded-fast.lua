#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local M=dofile(dir..'/lib/monitor.lua');local R=M.R
R.main(function() local a=R.cli({stage='value'});return M.run(assert(a.stage,'--stage required'),a.rest,nil,true) end)
