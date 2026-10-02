#!/usr/bin/env luajit
-- Cold native boot response; complete rescue acceptance remains a separate gate.
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local A=dofile(dir..'/lib/acceptance.lua');local QMP=dofile(dir..'/lib/qmp.lua')
R.main(function()
 local a=R.cli({runs='number',timeout='number',iso='value',name='value',firmware='value',fixtures='flag',probe_script='value'})
 a.runs=a.runs or 3;a.timeout=a.timeout or 120;a.name=a.name or 'native-fast-base';a.firmware=a.firmware or 'bios'
 assert(a.runs>=1 and a.runs%1==0 and a.timeout>0,'positive runs/timeout required');assert(a.name:match('^[%w_-]+$'))
 assert(a.firmware=='bios' or a.firmware=='uefi');assert(not a.fixtures or os.getenv('CI')=='true');assert(not a.probe_script or a.fixtures)
 local body=a.probe_script and R.read(a.probe_script);if body then assert(not body:find('AR_EXTERNAL_PROBE_END',1,true)) end
 local function first(paths) for _,p in ipairs(paths) do if R.exists(p) then return p end end;error('QEMU firmware not found') end
 local firmware=a.firmware=='uefi' and first({'/usr/share/OVMF/OVMF_CODE_4M.fd','/opt/homebrew/share/qemu/edk2-x86_64-code.fd'}) or first({'/usr/share/seabios/bios-256k.bin','/usr/share/qemu/bios-256k.bin','/opt/homebrew/share/qemu/bios-256k.bin'})
 local vars=a.firmware=='uefi' and first({'/usr/share/OVMF/OVMF_VARS_4M.fd','/opt/homebrew/share/qemu/edk2-i386-vars.fd'})
 local kernel=R.root..'/build/fast-source/build/native/vmlinuz';local artifact=a.iso and R.absolute(a.iso) or kernel;assert(R.exists(artifact))
 local out=R.root..'/build/bench/'..a.name..'-'..a.firmware;R.mkdir(out);local results=R.array()
 local required=a.fixtures and 'storage_rescue' or 'cli_smoke'
 for run=1,a.runs do
  local floor=os.getenv('ALPENGLOW_FAST_CONTINUATION')=='1' and 15 or 31.5;assert(R.free(R.root)>=floor*R.GIB,'Stop: approaching authorized floor')
  local socket_path=R.trim(R.capture({'mktemp','-d','/tmp/ar-qmp-XXXXXX'}));local qmp=socket_path..'/qmp.sock'
  local cmd={'qemu-system-x86_64','-machine','q35,accel=tcg','-cpu','max','-m','4096','-smp','1','-display','none','-serial','stdio','-monitor','none','-no-reboot','-nic','none','-qmp','unix:'..qmp..',server=on,wait=off'}
  local function add(t) for _,v in ipairs(t) do cmd[#cmd+1]=v end end
  if a.iso then add({'-drive','file='..artifact..',media=cdrom,format=raw,readonly=on','-boot','order=d'}) else add({'-kernel',kernel,'-append','quiet console=ttyS0 init=/init'}) end
  if vars then local p=out..'/run-'..run..'.vars.fd';R.copy(vars,p);add({'-drive','if=pflash,format=raw,readonly=on,file='..firmware,'-drive','if=pflash,format=raw,file='..p}) else add({'-bios',firmware}) end
  if a.fixtures then
   add({'-device','qemu-xhci,id=fixture-usb'})
   for index,t in ipairs({{'ext4','virtio-blk-pci'},{'btrfs','virtio-blk-pci'},{'xfs','ide-cd'},{'exfat','nvme'},{'ntfs','virtio-blk-pci'},{'luks','virtio-blk-pci'},{'fat','usb-storage'}}) do
    local path=R.root..'/build/fixtures/'..t[1]..'.img';assert(R.exists(path));local drive='fixture'..(index-1)
    add({'-drive','file='..path..',if=none,id='..drive..',format=raw,readonly=on'})
    local options=t[2]..',drive='..drive;if t[2]=='nvme' then options=options..',serial=AR_FIXTURE_NVME_'..(index-1) end;if t[2]=='usb-storage' then options=options..',bus=fixture-usb.0' end
    add({'-device',options})
   end
  end
  local log='';local markers=R.object();local start=R.now();local p=R.spawn(cmd);local logged=false;local next_probe=0;local probes=0;local smoke=false
  local function ingest(chunk)
   log=log..chunk;local elapsed=R.now()-start
   local checks={boot=log:find('Alpenglow boot',1,true),login=log:find('login:',1,true),base_console=A.line(log,'FAST_BASE_READY_OK'),shell_exec_failure=log:find('login: exec shell',1,true),cli_smoke=A.line(log,'CLI_SMOKE_OK'),storage_rescue=A.storage(log)}
   for k,v in pairs(checks) do if v and not markers[k] then markers[k]=elapsed end end
  end
  local ok,err=pcall(function()
   while R.now()-start<a.timeout and p:poll()==nil do
    local sig=R.interrupted();assert(not sig,'benchmark interrupted');ingest(p:read(20));local elapsed=R.now()-start
    if markers.shell_exec_failure then break end
    if markers.login and not logged then p:write('root\n');logged=true;next_probe=elapsed+.5 end
    if logged and elapsed>=next_probe and not markers.base_console then
     p:write('test "$(uname -r)" = 7.1.3 && test "$(cat /proc/1/comm)" = dinit && printf "%s%s\\n" FAST_BASE_ READY_OK\n');probes=probes+1;next_probe=elapsed+3
    end
    if markers.base_console and not smoke then
     local command=a.fixtures and '/usr/local/bin/rescue-smoke-storage; printf "STORAGE_SMOKE_EXIT=%s\\n" "$?"\n' or '/bin/toybox --version && /sbin/dinit --version && printf "%s%s\\n" CLI_SMOKE_ OK\n'
     if body then command="/usr/bin/oksh -s <<'AR_EXTERNAL_PROBE_END'\n"..body..'\nAR_EXTERNAL_PROBE_END\nprintf "STORAGE_SMOKE_EXIT=%s\\n" "$?"\n' end
     p:write(command);smoke=true
    end
    if markers[required] or (a.fixtures and A.line(log,'STORAGE_SMOKE_EXIT=%d+')) then break end
   end
  end)
  local screen_error=R.null;local screen_ok,se=pcall(function() local q=QMP(R,qmp);local success,err=pcall(q.call,q,'screendump',{filename=out..'/run-'..run..'.screen.ppm'});q:close();assert(success,err) end)
  if not screen_ok then screen_error=R.error_text(se) end
  p:stop();while p.output do local part=p:read(20);if part=='' then break end;ingest(part) end;p:close();os.remove(qmp);R.capture({'rmdir',socket_path})
  R.write(out..'/run-'..run..'.serial.log',log)
  local result={run=run,command=cmd,markers_seconds=markers,probe_attempts=probes,rescue_ready_seconds=markers.storage_rescue or R.null,network_ready_seconds=R.null,artifact_bytes=R.size(artifact),artifact_sha256=R.sha(artifact),firmware=a.firmware,firmware_sha256=R.sha(firmware),benchmark_script_sha256=R.sha(arg[0]),qemu_version=R.capture({'qemu-system-x86_64','--version'}):match('[^\n]+'),screen_error=screen_error,external_probe_sha256=body and R.sha_text(body) or R.null,scope=(a.fixtures and 'storage increment with synthetic read-only fixtures' or 'base console command proof only')..'; network disabled; no full rescue comparison',error=ok and R.null or R.error_text(err)}
  results[#results+1]=result;R.write_json(out..'/results.json',results);print(R.encode(result))
  if not ok or not markers[required] then return 1 end
 end
 print('artifact_sha256 '..R.sha(artifact));return 0
end)
