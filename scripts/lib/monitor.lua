-- MPL-2.0. Owned-container/process cleanup and fail-closed disk monitoring.
local R=dofile((debug.getinfo(1,'S').source:sub(2):match('^(.*)/'))..'/rescue.lua')
local M={R=R,LABEL='alpenglow-rescue.build=task15-fast-20261001',FLOOR=14*R.GIB,SOFT=15*R.GIB,CAP=4*R.GIB}
M.checked=function(a) return R.capture(a,{timeout=15}) end
M.free=R.free
function M.allocated(path)
 local text=R.capture({'du','-sk',path},{allow_failure=true,discard_stderr=true});return M.parse_allocated(text)
end
function M.parse_allocated(text) return assert(tonumber(text:match('^(%d+)%s')),'du did not return an allocation aggregate')*1024 end
function M.docker_free(cid)
 local a=cid and {'docker','exec',cid,'df','-Pk','/'} or {'docker','run','--rm','--pull=never','--platform','linux/amd64','--network','none','--read-only','--cpus=1','--memory=128m','--pids-limit=64','--label','alpenglow-rescue.audit=task15-continuation-20261001','debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251','df','-Pk','/'}
 local text=R.trim(M.checked(a));return assert(tonumber(R.words(text:match('[^\n]+$'))[4]),'invalid Docker df')*1024
end
function M.owned_usage()
 local list={'docker','ps','-q','--filter','label='..M.LABEL};local layer,available=0,nil
 for _,cid in ipairs(R.words(M.checked(list))) do
  local ok,e=pcall(function()
   local size_text=M.checked({'docker','inspect','--size','--format','{{.SizeRw}}',cid})
   layer=layer+assert(tonumber(R.trim(size_text)),'invalid Docker layer size')
   local current=M.docker_free(cid);available=available and math.min(available,current) or current
  end)
  if not ok then
   local live=false;for _,id in ipairs(R.words(M.checked(list))) do if id==cid then live=true end end
   if live then
    if type(e)~='table' or e.code~=127 or e.argv[1]~='docker' or e.argv[2]~='exec' then error(e,0) end
    local current=M.docker_free();available=available and math.min(available,current) or current
   end
  end
 end
 return layer,available
end
function M.violation(host,guest,growth,host_drop,guest_drop)
 if math.min(host,guest)<=M.SOFT then return 'Approaching 14 GiB host/Docker hard floor' end
 if math.max(growth,host_drop,guest_drop)>M.CAP then return '4 GiB continuation allocation/growth cap exceeded' end
end
function M.stop(p)
 local ok,e=pcall(function()
  for _,cid in ipairs(R.words(M.checked({'docker','ps','-q','--filter','label='..M.LABEL}))) do M.checked({'docker','stop','--timeout','10',cid}) end
 end)
 p:stop();if not ok then error(e,0) end
end
function M.run(stage,command,root,legacy)
 root=root or R.root;assert(stage:match('^[%w_-]+$'),'unsafe evidence stage');assert(#command>0)
 local out=root..'/build/evidence';R.mkdir(out)
 local control=out..(legacy and '/fast-build-control.json' or '/luajit-continuation-control.json')
 local host,guest=M.free(root),legacy and 0 or M.docker_free()
 if not R.exists(control) then
  assert(legacy and host>=36*R.GIB or (not legacy and math.min(host,guest)>=M.FLOOR+M.CAP),'Insufficient disk floor plus growth allowance')
  local rules=legacy and {start_free_bytes=host,floor_bytes=30*R.GIB,soft_stop_bytes=31.5*R.GIB,budget_bytes=6*R.GIB,source_subbudget_bytes=4.5*R.GIB,label=M.LABEL} or
   {host_start_free_bytes=host,docker_start_free_bytes=guest,source_start_allocated_bytes=M.allocated(root..'/build/fast-source'),floor_bytes=M.FLOOR,soft_stop_bytes=M.SOFT,additional_cap_bytes=M.CAP,authorization='2026-10-02 LuaJIT task: one job, 14 GiB floor; earlier checkpoints preserved.'}
  rules.at_utc=R.utc();R.write_json(control,rules)
 end
 local rules=R.read_json(control);local allocated=0;local layer,growth=0,0
 local function sample()
  host=M.free(root)
  if legacy then
   if R.exists(root..'/build/fast-source') then allocated=M.allocated(root..'/build/fast-source') end
   local reason
   if host<=rules.soft_stop_bytes then reason='Approaching 30 GiB hard floor' end
   if rules.start_free_bytes-host>rules.budget_bytes then reason='6 GiB observed-volume growth budget exceeded' end
   if allocated>rules.source_subbudget_bytes then reason='4.5 GiB generated-source subbudget exceeded' end
   return {free_bytes=host,source_allocated_bytes=allocated},reason
  end
  allocated=M.allocated(root..'/build/fast-source');local owned;layer,owned=M.owned_usage();guest=owned or M.docker_free()
  growth=math.max(0,allocated-rules.source_start_allocated_bytes)+layer
  return {host_free_bytes=host,docker_free_bytes=guest,source_allocated_bytes=allocated,owned_container_rw_bytes=layer,additional_allocation_bytes=growth},M.violation(host,guest,growth,math.max(0,rules.host_start_free_bytes-host),math.max(0,rules.docker_start_free_bytes-guest))
 end
 -- Check before starting any child, including when reusing an earlier checkpoint.
 if legacy then assert(host>rules.soft_stop_bytes,'Stop: approaching hard floor') else local _,reason=sample();assert(not reason,reason) end
 local log=assert(io.open(out..'/'..stage..'.log','wb'));local live=assert(io.open(out..'/'..stage..'.disk.jsonl','a'))
 local start=R.now();local samples=R.array();local stopped,cleanup=R.null,R.null
 local p=R.spawn(command,{cwd=root,env=legacy and {ALPENGLOW_BOUNDED_FAST='1'} or {ALPENGLOW_FAST_CONTINUATION='1'}});p:close_input()
 local ok,e=pcall(function()
  local next_sample=0
  while p:poll()==nil do
   local sig=R.interrupted();if sig then error('Interrupted by signal '..sig) end
   local chunk=p:read(100);if chunk~='' then assert(log:write(chunk));log:flush() end
   if R.now()>=next_sample then
    local s,reason=sample();s.elapsed_seconds=R.now()-start;samples[#samples+1]=s;assert(live:write(R.json.encode(s),'\n'));live:flush();next_sample=R.now()+2
    if reason then stopped=reason;break end
   end
  end
 end)
 if not ok then stopped='Supervisor failure: '..R.error_text(e) end
 if p:poll()==nil then local clean,ce=pcall(M.stop,p);if not clean then cleanup=R.error_text(ce) end end
 p:stop();while p.output do local s=p:read(20);if s=='' then break end;log:write(s) end;p:close();log:close();live:close()
 local report={stage=stage,command=command,exit_code=p.code,stopped_reason=stopped,cleanup_error=cleanup,duration_seconds=R.now()-start,samples=samples}
 if legacy then
  report.min_free_bytes=host;report.max_source_allocated_bytes=allocated
  for _,s in ipairs(samples) do report.min_free_bytes=math.min(report.min_free_bytes,s.free_bytes);report.max_source_allocated_bytes=math.max(report.max_source_allocated_bytes,s.source_allocated_bytes) end
 else
  report.min_host_free_bytes=host;report.min_docker_free_bytes=guest;report.max_additional_allocation_bytes=0
  for _,s in ipairs(samples) do report.min_host_free_bytes=math.min(report.min_host_free_bytes,s.host_free_bytes);report.min_docker_free_bytes=math.min(report.min_docker_free_bytes,s.docker_free_bytes);report.max_additional_allocation_bytes=math.max(report.max_additional_allocation_bytes,s.additional_allocation_bytes) end
 end
 R.write_json(out..'/'..stage..'-resource.json',report);local summary={};for k,v in pairs(report) do if k~='samples' then summary[k]=v end end;print(R.encode(summary))
 return (stopped~=R.null or cleanup~=R.null) and 1 or (p.code<0 and 128-p.code or p.code)
end
return M
