-- QEMU's private task-owned Unix socket; no network endpoint.
return function(R,path)
 local ffi=R.ffi;local C=ffi.C;local fd=C.socket(1,1,0);assert(fd>=0,'QMP socket failed');C.fcntl(fd,2,ffi.new('int',1))
 assert(#path<104,'QMP socket path too long');local address=ffi.new('unsigned char[128]')
 if ffi.os=='OSX' then address[0]=#path+3;address[1]=1 else ffi.cast('unsigned short *',address)[0]=1 end
 ffi.copy(address+2,path,#path);local connected=C.connect(fd,address,#path+3)
 if connected~=0 then C.close(fd);error('QMP connect failed') end
 local q={fd=fd,buffer=''}
 function q:close() if self.fd then C.close(self.fd);self.fd=nil end end
 function q:line()
  local deadline=R.now()+15
  while not self.buffer:find('\n',1,true) do
   if self.tick then self.tick() end
   assert(R.now()<deadline,'QMP response timeout');local sig=R.interrupted();assert(not sig,'QMP interrupted')
   local poll=ffi.new('struct pollfd[1]',{{self.fd,1,0}})
   if C.poll(poll,1,100)>0 then local b=ffi.new('char[65536]');local n=C.read(self.fd,b,65536);assert(n>0,'QMP EOF');self.buffer=self.buffer..ffi.string(b,n) end
  end
  local line,rest=self.buffer:match('^(.-)\n(.*)$');self.buffer=rest
  local value,_,err=R.json.decode(line);assert(not err,err);return value
 end
 function q:call(command,arguments)
  local data=R.json.encode({execute=command,arguments=arguments or R.object()})..'\n';local offset=0
  while offset<#data do local n=tonumber(C.write(self.fd,data:sub(offset+1),#data-offset));assert(n>0,'QMP write failed');offset=offset+n end
  while true do local message=self:line();assert(not message.error,R.json.encode(message.error));if message['return']~=nil then return message['return'] end end
 end
 function q:key(key) if self.tick then self.tick() end;self:call('human-monitor-command',{['command-line']='sendkey '..key..' 1'});R.sleep(.005);if self.tick then self.tick() end end
 function q:type(value)
  local map={[' ']='spc',['=']='equal',[',']='comma',['-']='minus',['/']='slash',['\n']='ret',['"']='shift-apostrophe',["'"]='apostrophe',['\\']='backslash',['$']='shift-4',['>']='shift-dot',['<']='shift-comma',['&']='shift-7',['|']='shift-backslash',[';']='semicolon',['_']='shift-minus',[':']='shift-semicolon',['.']='dot',['!']='shift-1',['?']='shift-slash'}
  for c in value:gmatch('.') do local key=map[c] or c:lower();if c:match('%u') then key='shift-'..key end;self:key(key) end
 end
 local ok,e=pcall(function() q:line();q:call('qmp_capabilities') end);if not ok then q:close();error(e) end
 return q
end
