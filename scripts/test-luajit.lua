#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local E=dofile(dir..'/lib/evidence.lua')
R.main(function()
 local tmp=R.trim(R.capture({'mktemp','-d','/tmp/ar-lua-test-XXXXXX'}));local tests=0
 local function test(name,fn) fn();tests=tests+1;print('PASS '..name);io.stdout:flush() end
 test('literal argv does not execute shell syntax',function()
  local literal="spaces ' ; $(touch "..tmp.."/unexpected) `false`"
  assert(R.capture({'printf','%s',literal})==literal);assert(not R.exists(tmp..'/unexpected'))
 end)
 test('exit status125 and missing executable127 survive',function()
  local _,code=R.capture({'sh','-c','exit 125'},{allow_failure=true});assert(code==125)
  local ok,e=pcall(R.capture,{'/definitely-not-an-executable'});assert(not ok and e.code==127)
 end)
 test('timeout terminates and reaps child',function()
  local start=R.now();local _,code=R.capture({'sleep','30'},{timeout=.08,allow_failure=true});assert(code==124 and R.now()-start<3)
 end)
 test('binary stdin and SHA512 helper pipe preserve bytes',function()
  local s='a\0b\255';assert(R.capture({'cat'},{input=s})==s)
 end)
 test('full duplex stdin exceeds pipe capacity without deadlock',function()
  local s=string.rep('0123456789',30000);assert(R.capture({'cat'},{input=s,timeout=3})==s)
 end)
 test('SHA256 matches known digest and does not load large images',function()
  R.write(tmp..'/file','abc');assert(R.sha(tmp..'/file')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
 end)
 test('JSON null/false/empty arrays/objects and malformed data',function()
  R.write_json(tmp..'/data.json',{array=R.array(),object=R.object(),value=false,n=R.null})
  local t=R.read_json(tmp..'/data.json');assert(t.value==false and t.n==R.null and getmetatable(t.array).__jsontype=='array' and getmetatable(t.object).__jsontype=='object')
  R.write(tmp..'/invalid.json','{');assert(not pcall(R.read_json,tmp..'/invalid.json'))
  R.write(tmp..'/invalid.json','{} trailing');assert(not pcall(R.read_json,tmp..'/invalid.json'))
 end)
 test('all86 recorded package fields survive APK parsing equivalently',function()
  local old=R.read_json(R.root..'/evidence/storage-built-image/storage-package-license-inventory.json').packages
  local entries={};for _,p in ipairs(old) do
   local row={};for field,key in pairs({P='name',V='version',L='license',o='origin',I='installed_bytes',C='apk_checksum',c='aports_commit',U='homepage'}) do if p[key]~=R.null then row[#row+1]=field..':'..tostring(p[key]) end end
   entries[#entries+1]=table.concat(row,'\n')
  end
  local parsed=E.apk(table.concat(entries,'\n\n'),R);assert(#parsed==86)
  for i,p in ipairs(old) do for key,value in pairs(p) do assert(parsed[i][key]==value,p.name..' '..key) end end
 end)
 test('missing licenses stay null and invalid installed size fails',function()
  local p=E.apk('P:test\nV:1\nI:0\n',R)[1];assert(p.license==R.null)
  assert(not pcall(E.apk,'P:test\nV:1\nI:not-a-number\n',R))
 end)
 test('Kconfig builtins satisfy module requests; missing symbols fail',function()
  local mismatch,n=E.mismatches({EXT4_FS='m',MISSING='y',OFF='n'},{EXT4_FS='y'},R)
  assert(n==3 and not mismatch.EXT4_FS and not mismatch.OFF and mismatch.MISSING.resolved=='n')
 end)
 test('image verify rejects byte/hash mismatch before packaging',function()
  local m={image_bytes=3,image_sha256=R.sha(tmp..'/file')};E.verify(tmp..'/file',m,R)
  m.image_bytes=4;assert(not pcall(E.verify,tmp..'/file',m,R));m.image_bytes=3;m.image_sha256=string.rep('0',64);assert(not pcall(E.verify,tmp..'/file',m,R))
 end)
 test('QMP Unix transport preserves keyboard and rejects protocol errors',function()
  local socket=tmp..'/qmp.sock';local script=tmp..'/qmp-server.lua'
  R.write(script,string.format([=[local R=dofile(%q);local f=R.ffi;local C=f.C
f.cdef'int bind(int,const void *,unsigned int);int listen(int,int);int accept(int,void *,void *);'
local path=%q;local fd=C.socket(1,1,0);local a=f.new('unsigned char[128]')
if f.os=='OSX' then a[0]=#path+3;a[1]=1 else f.cast('unsigned short *',a)[0]=1 end
f.copy(a+2,path,#path);assert(C.bind(fd,a,#path+3)==0,'bind errno '..f.errno());assert(C.listen(fd,1)==0);R.write(%q,'ready')
local peer=C.accept(fd,nil,nil);assert(peer>=0)
local function send(s) assert(tonumber(C.write(peer,s,#s))==#s) end
send('{"QMP":{}}\n');local text='';local commands={}
while true do
 local b=f.new('char[4096]');local n=C.read(peer,b,4096);if n<=0 then break end;text=text..f.string(b,n)
 while text:find('\n',1,true) do
  local line,rest=text:match('^(.-)\n(.*)$');text=rest;local m=R.json.decode(line);commands[#commands+1]=m
  if m.execute=='fault' then send('{"error":{"desc":"synthetic failure"}}\n') else send('{"return":');R.sleep(.001);send('{}}\n') end
 end
end
C.close(peer);C.close(fd);R.write_json(%q,commands)
]=],R.absolute(dir..'/lib/rescue.lua'),socket,tmp..'/qmp.ready',tmp..'/qmp-commands.json'))
  local p=R.spawn({'luajit',script});p:close_input();local deadline=R.now()+3
  local startup='';while not R.exists(tmp..'/qmp.ready') and R.now()<deadline do startup=startup..p:read(20) end
  if not R.exists(tmp..'/qmp.ready') then p:close();error('QMP fixture did not start: '..startup) end
  local q=dofile(dir..'/lib/qmp.lua')(R,socket);q:type('A_\n');assert(not pcall(q.call,q,'fault'));q:close()
  while p:poll()==nil and R.now()<deadline do p:read(20) end;assert(p:poll()==0);p:close();os.remove(socket)
  local commands=R.read_json(tmp..'/qmp-commands.json')
  assert(commands[1].execute=='qmp_capabilities' and commands[2].arguments['command-line']=='sendkey shift-a 1')
  assert(commands[3].arguments['command-line']=='sendkey shift-minus 1' and commands[4].arguments['command-line']=='sendkey ret 1')
 end)
 test('SIGTERM makes supervisor clean up real child and preserve failure',function()
  local root=tmp..'/supervisor';R.mkdir(root..'/build/fast-source')
  local script=tmp..'/signal.lua'
  R.write(script,string.format([=[local M=dofile(%q);local R=M.R
M.free=function()return 38*R.GIB end;M.allocated=function()return 0 end;M.checked=function()return '' end
R.main(function()return M.run('signal',{'sh','-c','echo started; exec sleep 30'},%q,true)end)
]=],R.absolute(dir..'/lib/monitor.lua'),root))
  local p=R.spawn({'luajit',script});p:close_input();local deadline=R.now()+5;local logfile=root..'/build/evidence/signal.log'
  while (not R.exists(logfile) or not R.read(logfile):find('started',1,true)) and R.now()<deadline do p:read(20) end
  assert(R.exists(logfile) and R.read(logfile):find('started',1,true),'supervisor did not start');assert(R.ffi.C.kill(p.pid,15)==0)
  while p:poll()==nil and R.now()<deadline do p:read(20) end
  assert(p:poll()==1,'supervisor did not fail after signal');p:close()
  local report=R.read_json(root..'/build/evidence/signal-resource.json');assert(report.exit_code==-15 and report.stopped_reason:find('Interrupted by signal',1,true))
 end)
 for _,p in ipairs(R.files(tmp)) do os.remove(p) end
 R.run({'rmdir',tmp..'/supervisor/build/fast-source',tmp..'/supervisor/build/evidence',tmp..'/supervisor/build',tmp..'/supervisor',tmp})
 print(tests..' LuaJIT runtime/equivalence/error-path tests passed')
end)
