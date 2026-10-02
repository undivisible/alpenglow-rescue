-- MPL-2.0. Small POSIX runner shared by the LuaJIT build and test tools.
assert(jit and jit.version_num >= 20100, 'LuaJIT 2.1 is required')
local ffi = require('ffi')
ffi.cdef[[
int pipe(int [2]); int fork(void); int dup2(int,int); int close(int);
int execvp(const char *, char *const *); void _exit(int); int setsid(void);
int chdir(const char *); char *getcwd(char *, size_t); int setenv(const char *,const char *,int);
int waitpid(int,int *,int); int kill(int,int); int fcntl(int,int,...);
long read(int,void *,size_t); long write(int,const void *,size_t);
struct pollfd { int fd; short events; short revents; }; int poll(struct pollfd *, unsigned long,int);
struct timespec { long tv_sec; long tv_nsec; }; int clock_gettime(int,struct timespec *);
int nanosleep(const struct timespec *,struct timespec *);
int socket(int,int,int); int connect(int,const void *,unsigned int);
int open(const char *,int,...); void *signal(int,void *);
int sigemptyset(void *); int sigaddset(void *,int); int sigismember(const void *,int);
int sigprocmask(int,const void *,void *); int sigpending(void *); int sigwait(const void *,int *);
]]
local C=ffi.C
local R={GIB=1024^3, ffi=ffi}
local signal_mask,original_mask
function R.trap_signals()
 if signal_mask then return end
 signal_mask=ffi.new('unsigned long[16]');original_mask=ffi.new('unsigned long[16]')
 C.sigemptyset(signal_mask);C.sigaddset(signal_mask,2);C.sigaddset(signal_mask,15)
 assert(C.sigprocmask(ffi.os=='OSX' and 1 or 0,signal_mask,original_mask)==0)
end
function R.interrupted()
 if not signal_mask then return end
 local pending=ffi.new('unsigned long[16]');assert(C.sigpending(pending)==0)
 if C.sigismember(pending,2)==1 or C.sigismember(pending,15)==1 then
  local sig=ffi.new('int[1]');assert(C.sigwait(signal_mask,sig)==0);return tonumber(sig[0])
 end
end
function R.restore_signals()
 if signal_mask then C.sigprocmask(ffi.os=='OSX' and 3 or 2,original_mask,nil);signal_mask=nil;original_mask=nil end
end
local lib=debug.getinfo(1,'S').source:sub(2):match('^(.*)/')
R.json=dofile(lib..'/vendor/dkjson.lua'); R.null=R.json.null
function R.array(t) return setmetatable(t or {},{__jsontype='array'}) end
function R.object(t) return setmetatable(t or {},{__jsontype='object'}) end
function R.trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
function R.words(s) local t={} for w in s:gmatch('%S+') do t[#t+1]=w end return t end
function R.lines(s) local t={} for l in (s..'\n'):gmatch('(.-)\n') do t[#t+1]=l end return t end
function R.read(p) local f=assert(io.open(p,'rb')); local s=f:read('*a'); f:close(); return s end
function R.write(p,s) local f=assert(io.open(p,'wb')); assert(f:write(s)); assert(f:close()) end
function R.exists(p) local f=io.open(p,'rb'); if f then f:close(); return true end return false end
function R.size(p) local f=assert(io.open(p,'rb')); local n=assert(f:seek('end')); f:close(); return n end
function R.absolute(p)
 if p:sub(1,1)~='/' then local b=ffi.new('char[4096]'); assert(C.getcwd(b,4096)~=nil); p=ffi.string(b)..'/'..p end
 local a={} for part in p:gmatch('[^/]+') do if part=='..' then table.remove(a) elseif part~='.' then a[#a+1]=part end end
 return '/'..table.concat(a,'/')
end
R.root=R.absolute(lib..'/../..')
function R.now() local t=ffi.new('struct timespec'); assert(C.clock_gettime(ffi.os=='OSX' and 6 or 1,t)==0); return tonumber(t.tv_sec)+tonumber(t.tv_nsec)/1e9 end
function R.sleep(s) local t=ffi.new('struct timespec',{math.floor(s),math.floor(s%1*1e9)}); C.nanosleep(t,nil) end
function R.utc() return os.date('!%Y-%m-%dT%H:%M:%SZ') end
function R.quote(s) assert(not s:find('\0',1,true)); return "'"..s:gsub("'","'\\''").."'" end
local function pipe() local p=ffi.new('int[2]'); assert(C.pipe(p)==0,'pipe failed'); C.fcntl(p[0],2,ffi.new('int',1)); C.fcntl(p[1],2,ffi.new('int',1)); return p end
local function status(s) local signal=s%128; return signal==0 and math.floor(s/256)%256 or -signal end
-- SIGPIPE becomes an ordinary checked write error; child restores default.
C.signal(13,ffi.cast('void *',1))
function R.spawn(argv,opts)
 opts=opts or {}; assert(#argv>0)
 local args=ffi.new('char *[?]',#argv+1); for i,v in ipairs(argv) do assert(not v:find('\0',1,true)); args[i-1]=ffi.cast('char *',v) end
 local input,output=pipe(),pipe()
 local pid=C.fork(); assert(pid>=0,'fork failed')
 if pid==0 then
  C.signal(13,nil)
  if original_mask~=nil then C.sigprocmask(ffi.os=='OSX' and 3 or 2,original_mask,nil) end
  if C.setsid()<0 then C._exit(126) end
  if opts.cwd and C.chdir(opts.cwd)~=0 then C._exit(126) end
  for k,v in pairs(opts.env or {}) do if C.setenv(k,v,1)~=0 then C._exit(126) end end
  if C.dup2(input[0],0)<0 or C.dup2(output[1],1)<0 or C.dup2(output[1],2)<0 then C._exit(126) end
  if opts.discard_stderr then local fd=C.open('/dev/null',1);if fd<0 or C.dup2(fd,2)<0 then C._exit(126) end;C.close(fd) end
  C.close(input[0]);C.close(input[1]);C.close(output[0]);C.close(output[1])
  C.execvp(argv[1],args); C._exit(127)
 end
 C.close(input[0]);C.close(output[1])
 local p={pid=tonumber(pid),input=tonumber(input[1]),output=tonumber(output[0])}
 assert(C.fcntl(p.input,4,ffi.new('int',require('bit').bor(C.fcntl(p.input,3),ffi.os=='OSX' and 4 or 2048)))==0)
 function p:poll()
  if self.code~=nil then return self.code end
  local s=ffi.new('int[1]'); local n=C.waitpid(self.pid,s,1)
  if n==self.pid then self.code=status(s[0]) elseif n<0 and ffi.errno()~=4 then error('waitpid failed') end
  return self.code
 end
 local function raw_read(self,ms)
  if not self.output then return '' end
  local f=ffi.new('struct pollfd[1]',{{self.output,1,0}})
  if C.poll(f,1,ms or 0)<=0 then return '' end
  local b=ffi.new('char[65536]'); local n=C.read(self.output,b,65536)
  if n==0 then C.close(self.output);self.output=nil;return '' end
  if n<0 then assert(ffi.errno()==4,'read failed');return '' end
  return ffi.string(b,n)
 end
 function p:read(ms)
  if self.backlog then local s=self.backlog;self.backlog=nil;return s end
  return raw_read(self,ms)
 end
 function p:write(s)
  local off=0;local deadline=R.now()+(opts.timeout or 60)
  while off<#s do
   local sig=R.interrupted();assert(not sig,'child write interrupted');assert(R.now()<deadline,'child stdin timeout')
   local n=tonumber(C.write(self.input,s:sub(off+1),#s-off))
   if n>0 then off=off+n else
    local errno=ffi.errno();assert(errno==4 or errno==(ffi.os=='OSX' and 35 or 11),'child stdin write failed')
    local chunk=raw_read(self,20);if chunk~='' then self.backlog=(self.backlog or '')..chunk end
   end
  end
 end
 function p:close_input() if self.input then C.close(self.input);self.input=nil end end
 function p:stop()
  if self:poll()==nil then
   C.kill(-self.pid,15); local deadline=R.now()+15
   while self:poll()==nil and R.now()<deadline do R.sleep(.02) end
   if self:poll()==nil then C.kill(-self.pid,9);local s=ffi.new('int[1]');assert(C.waitpid(self.pid,s,0)==self.pid);self.code=status(s[0]) end
  end
  self:close_input();return self.code
 end
 function p:close() self:stop();if self.output then C.close(self.output);self.output=nil end end
 return p
end
function R.capture(argv,opts)
 opts=opts or {};local p=R.spawn(argv,opts);local pieces={};local start=R.now();local timed=false
 local ok,err=pcall(function()
  if opts.input then p:write(opts.input) end;p:close_input()
  while p:poll()==nil do
   local sig=R.interrupted();if sig then error('Interrupted by signal '..sig) end
   pieces[#pieces+1]=p:read(20)
   if R.now()-start>(opts.timeout or 60) then timed=true;p:stop();break end
  end
  while p.output do local part=p:read(20);pieces[#pieces+1]=part;if part=='' then break end end
 end)
 p:close();if not ok then error(err) end
 local output=table.concat(pieces);local code=timed and 124 or p.code
 if code~=0 and not opts.allow_failure then error({code=code,argv=argv,output=output},0) end
 return output,code
end
function R.run(argv,opts) local out,code=R.capture(argv,opts);if out~='' then io.write(out) end;return code end
function R.mkdir(p) R.capture({'mkdir','-p',p}) end
function R.copy(a,b) R.capture({'cp',a,b}) end
function R.sha(p) local cmd=ffi.os=='OSX' and {'shasum','-a','256',p} or {'sha256sum',p};return assert(R.capture(cmd):match('^([0-9a-f]+)')) end
function R.sha_text(s) local p=os.tmpname();R.write(p,s);local ok,v=pcall(R.sha,p);os.remove(p);assert(ok,v);return v end
function R.read_json(p) local v,pos,err=R.json.decode(R.read(p),1,R.null);assert(not err,err);assert(not R.read(p):sub(pos):match('%S'),'trailing JSON data');return v end
function R.encode(t) return assert(R.json.encode(t,{indent=true})) end
function R.write_json(p,t) R.write(p,R.encode(t)..'\n') end
function R.files(p) local out=R.capture({'find',p,'-type','f'});local t={} for f in out:gmatch('[^\n]+') do t[#t+1]=f end;table.sort(t);return t end
function R.free(p) local out=R.capture({'df','-Pk',p});local last=R.trim(out):match('([^\n]+)$');local fields=R.words(last);return assert(tonumber(fields[4]),'invalid df')*1024 end
function R.replace(s,old,new,count)
 local i,n=1,0;local parts={}
 while not count or n<count do local a,b=s:find(old,i,true);if not a then break end;parts[#parts+1]=s:sub(i,a-1);parts[#parts+1]=new;i=b+1;n=n+1 end
 parts[#parts+1]=s:sub(i);return table.concat(parts),n
end
function R.syntax(s) local p=os.tmpname();R.write(p,s);local ok,v=pcall(R.capture,{'sh','-n',p});os.remove(p);assert(ok,v) end
function R.cli(spec,argv)
 local a={rest={}};argv=argv or arg;local i=1
 while i<=#argv do local k=argv[i];if k=='--' then for j=i+1,#argv do a.rest[#a.rest+1]=argv[j] end;break
 elseif k:sub(1,2)=='--' then local name=k:sub(3):gsub('-','_');local ty=assert(spec[name],'unknown option '..k);if ty=='flag' then a[name]=true else i=i+1;a[name]=assert(argv[i],'missing '..k);if ty=='number' then a[name]=assert(tonumber(a[name]),'invalid '..k) end end
 else a.rest[#a.rest+1]=k end;i=i+1 end
 return a
end
function R.error_text(e) if type(e)=='table' then return 'command exit '..tostring(e.code)..': '..table.concat(e.argv or {},' ')..'\n'..(e.output or '') end return tostring(e) end
function R.main(fn) R.trap_signals();local ok,code=pcall(fn);R.restore_signals();if not ok then io.stderr:write(R.error_text(code),'\n');os.exit(1) end;os.exit(code or 0) end
return R
