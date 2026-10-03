#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local M=dofile(dir..'/lib/monitor.lua');local R=M.R
R.main(function()
 local g=R.GIB;local tests=0
 local function test(name,fn) fn();tests=tests+1;print('PASS '..name) end
 local function patched(target,values,fn)
  local old={};for k,v in pairs(values) do old[k]=target[k];target[k]=v end
  local ok,e=pcall(fn);for k in pairs(values) do target[k]=old[k] end;assert(ok,R.error_text(e))
 end
 test('du race preserves valid stdout aggregate',function() assert(M.parse_allocated('1234 /build\n')==1234*1024) end)
 test('missing du aggregate fails closed',function() assert(not pcall(M.parse_allocated,'')) end)
 test('both disk floors and all growth limits',function()
  assert(not M.violation(18*g,18*g,3*g,0,0));assert(M.violation(14*g,18*g,0,0,0));assert(M.violation(18*g,14*g,0,0,0))
  for _,x in ipairs({{5*g,0,0},{0,5*g,0},{0,0,5*g}}) do assert(M.violation(18*g,18*g,unpack(x)):find('cap')) end
 end)
 local checked=function(a) if a[2]=='ps' then return 'owned-cid\n' elseif a[2]=='inspect' then return '1234\n' else error('unexpected call') end end
 test('live inspect handles output and exit status separately',function()
  patched(M,{checked=function(a)
   if a[2]=='ps' then return 'owned-cid\n',0 end
   if a[2]=='inspect' then return '1234\n',0 end
   error('unexpected call')
  end,docker_free=function(cid) assert(cid=='owned-cid');return 18*g end},function()
   local layer,free=M.owned_usage();assert(layer==1234 and free==18*g)
  end)
 end)
 test('live df exit127 uses fresh immutable probe',function()
  local count=0
  patched(M,{checked=checked,docker_free=function(cid) count=count+1;if cid then error({code=127,argv={'docker','exec',cid,'df'}}) end;return 18*g end},function() local layer,free=M.owned_usage();assert(layer==1234 and free==18*g and count==2) end)
 end)
 test('other live probe failure remains fatal',function()
  patched(M,{checked=checked,docker_free=function() error({code=1,argv={'docker','exec','owned-cid','df'}}) end},function() assert(not pcall(M.owned_usage)) end)
 end)
 local function stage(failure)
  local tmp=R.trim(R.capture({'mktemp','-d','/tmp/ar-monitor-test-XXXXXX'}));R.mkdir(tmp..'/build/fast-source')
  local stopped=0;local p={pid=1,poll=function() return nil end,read=function() return '' end,close_input=function()end,close=function()end,stop=function(self) self.code=-15 end}
  local reads=0
  patched(M,{free=function() reads=reads+1;return reads<=1 and 38*g or 31*g end,allocated=function() if failure then error('test outage') end;return 1024 end,stop=function(child)assert(child==p);stopped=stopped+1;child:stop()end},function()
   local spawn=R.spawn
   patched(R,{spawn=function(argv,opts) if argv[1]=='owned-test-job' then return p end;return spawn(argv,opts) end},function() assert(M.run(failure and 'failure' or 'floor',{'owned-test-job'},tmp,true)==1) end)
  end)
  local report=R.read_json(tmp..'/build/evidence/'..(failure and 'failure' or 'floor')..'-resource.json')
  assert(stopped==1);assert(report.stopped_reason:find(failure and 'Supervisor failure' or 'budget',1,true))
  if not failure then assert(R.size(tmp..'/build/evidence/floor.disk.jsonl')>0) end
  -- This exact newly-created synthetic directory contains no user data.
  for _,path in ipairs(R.files(tmp)) do assert(os.remove(path)) end
  R.run({'rmdir',tmp..'/build/fast-source',tmp..'/build/evidence',tmp..'/build',tmp})
 end
 test('unexpected error cleans up and persists report',function()stage(true)end)
 test('growth stop persists sample and cleans up',function()stage(false)end)
 print(tests..' LuaJIT monitor regression tests passed')
end)
