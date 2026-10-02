#!/usr/bin/env luajit
-- Historical full-image/baseline protocol; no fixture acceptance implied.
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local QMP=dofile(dir..'/lib/qmp.lua');local A=dofile(dir..'/lib/acceptance.lua')
R.main(function()
 assert(R.free('.')>=40*R.GIB,'Stop: less than 40 GiB host headroom')
 local a=R.cli({name='value',firmware='value',baseline='flag',runs='number',timeout='number'})
 local iso=R.absolute(assert(a.rest[1],'ISO required'));assert(a.name and a.name:match('^[%w_-]+$'));a.firmware=a.firmware or 'bios';a.runs=a.runs or 3;a.timeout=a.timeout or 240
 assert(a.firmware=='bios' or a.firmware=='uefi');assert(a.runs>=1 and a.runs%1==0 and a.timeout>0)
 local out=R.root..'/build/bench/'..a.name..'-'..a.firmware;R.mkdir(out);local results=R.array();local passed=true
 for run=1,a.runs do
  local tmp=R.trim(R.capture({'mktemp','-d','/tmp/ar-qmp-XXXXXX'}));local socket=tmp..'/qmp.sock'
  local cmd={'qemu-system-x86_64','-machine','q35,accel=tcg','-cpu','max','-smp','1','-m','4096','-display','none','-serial','stdio','-monitor','none','-qmp','unix:'..socket..',server=on,wait=off','-no-reboot','-device','e1000,romfile=,netdev=net0','-netdev','user,id=net0','-device','qemu-xhci,id=xhci','-device','usb-kbd,bus=xhci.0','-drive','file='..iso..',media=cdrom,format=raw,readonly=on','-boot','order=d'}
  if a.firmware=='uefi' then
   local code='/opt/homebrew/share/qemu/edk2-x86_64-code.fd';local template='/opt/homebrew/share/qemu/edk2-i386-vars.fd'
   if R.exists('/usr/share/OVMF/OVMF_CODE_4M.fd') then code='/usr/share/OVMF/OVMF_CODE_4M.fd';template='/usr/share/OVMF/OVMF_VARS_4M.fd' end
   local vars=out..'/vars-'..run..'.fd';R.copy(template,vars)
   for _,v in ipairs({'-drive','if=pflash,format=raw,readonly=on,file='..code,'-drive','if=pflash,format=raw,file='..vars}) do cmd[#cmd+1]=v end
  end
  local log='';local events=R.array();local markers={};local start=R.now();local p=R.spawn(cmd);local q;local edited=not a.baseline;local probe_at=0
  local function ingest() log=log..p:read(0);for k,marker in pairs({rescue='RESCUE_READY_OK',network='NETWORK_READY_OK'}) do if not markers[k] and A.line(log,marker) then markers[k]=R.now()-start end end end
  local ok,err=pcall(function()
   while R.now()-start<a.timeout and p:poll()==nil do
    local sig=R.interrupted();assert(not sig,'benchmark interrupted');ingest();local elapsed=R.now()-start
    if not q then local success,value=pcall(QMP,R,socket);if success then q=value;q.tick=ingest end end
    if q and a.baseline and not edited and elapsed>=(a.firmware=='bios' and 3 or 8) then
     if a.firmware=='bios' then q:key('down');q:key('tab');q:type(' console=tty0 console=ttyS0,115200');q:key('ret') else
      q:key('c');R.sleep(.2)
      p:write('linux (cd0)/arch/boot/x86_64/vmlinuz-linux-t2 archisobasedir=arch archisosearchuuid=2026-09-30-16-02-38-00 xe.enable_panel_replay=0 initramfs_async=0 omarchy.rescue=tty cow_spacesize=50% nomodeset console=tty0 console=ttyS0,115200\ninitrd (cd0)/arch/boot/x86_64/initramfs-linux-t2.img\nboot\n')
     end
     edited=true;events[#events+1]={event='selected-basic-console-with-serial',seconds=R.now()-start}
    end
    if edited and q and elapsed>=probe_at and elapsed>8 then
     q:type('cryptsetup --version >/dev/null&&btrfs version >/dev/null&&lsblk >/dev/null&&test -n "$TMUX"&&printf "\\nRESCUE_READY_OK\\n" >/dev/console\n')
     q:type('ip -4 addr show scope global|grep -q inet&&ping -c1 -W2 10.0.2.2 >/dev/null&&printf "\\nNETWORK_READY_OK\\n" >/dev/console\n')
     probe_at=R.now()-start+2
    end
    if markers.rescue and markers.network then break end;R.sleep(.02)
   end
   if q then q:call('screendump',{filename=out..'/run-'..run..'.ppm'}) end
  end)
  if q then q:close() end;p:stop();ingest();p:close();os.remove(socket);R.capture({'rmdir',tmp})
  R.write(out..'/run-'..run..'.serial',log)
  local item={run=run,rescue_ready_seconds=markers.rescue or R.null,network_ready_seconds=markers.network or R.null,events=events,command=cmd,error=ok and R.null or R.error_text(err)}
  results[#results+1]=item;print(R.encode(item));R.write_json(out..'/results.json',{iso=iso,bytes=R.size(iso),sha256=R.sha(iso),firmware=a.firmware,runs=results,probe_runtime='LuaJIT; serial sampled during each QMP keyboard call',scope='historical partial probe; no filesystem fixture acceptance'})
  if not ok or not markers.rescue or not markers.network then passed=false;break end
 end
 return passed and 0 or 1
end)
