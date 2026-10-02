#!/usr/bin/env luajit
local R=dofile((arg[0]:match('^(.*)/') or '.')..'/lib/rescue.lua')
R.main(function()
 assert(R.ffi.C.chdir(R.root)==0)
 local pins=R.read_json('pins.json');assert(R.trim(R.capture({'git','-C','vendor/alpenglow','rev-parse','HEAD'}))==pins.alpenglow)
 for _,base in ipairs({'scripts','overlay/usr/local/bin'}) do for _,path in ipairs(R.files(base)) do
  if path:match('%.sh$') or base=='overlay/usr/local/bin' then R.capture({'sh','-n',path}) end
  if path:match('%.lua$') then assert(loadfile(path)) end
  assert(not path:match('%.py$'),'owned Python script remains: '..path)
 end end
 assert(R.sha('scripts/lib/vendor/dkjson.lua')=='197cb50834c642f84b4cf99fe724932c50e6d9c92faec7ad89aa25e91df4d481','vendored JSON source changed')
 local packages=R.read('packages.txt')
 for _,name in ipairs({'linux-lts','linux-firmware','btrfs-progs','cryptsetup','lvm2','mdadm','ddrescue','testdisk','iwd','tmux','borgbackup'}) do assert(('\n'..packages):find('\n'..name..'\n',1,true),'missing essential '..name) end
 assert(not ('\n'..packages):find('\npython3\n',1,true))
 for _,path in ipairs(R.files('scripts')) do if path:match('%.sh$') then
  local text=R.read(path);assert(not text:find('python3',1,true),path);assert(not text:find('--cpus=2',1,true),path);assert(not text:find('CPUS=2',1,true),path)
 end end
 for _,path in ipairs(R.files('.github/workflows')) do assert(not R.read(path):find('python3',1,true),path) end
 local hybrid=R.read('scripts/build-hybrid.sh');assert(hybrid:find('--cpus=1',1,true) and not hybrid:find('--privileged',1,true));assert(hybrid:find('41943040',1,true))
 assert(R.read('scripts/build.sh'):find('build-fast-base.sh',1,true))
 R.run({'luajit','scripts/prepare-fast-base.lua','--check'})
 R.run({'luajit','scripts/prepare-fast-base.lua','--check'},{env={CI='true',ALPENGLOW_RESCUE_INCREMENT='storage-1',ALPENGLOW_FAST_CONTINUATION='1'}})
 for _,test in ipairs({'test-fast-monitor','test-storage-acceptance','test-luajit'}) do R.run({'luajit','scripts/'..test..'.lua'}) end
 local pack=R.read('scripts/pack.sh');assert(pack:find('-T1',1,true) and pack:find('bios-install',1,true) and pack:find('--efi-boot',1,true))
 print('LuaJIT recipe checks: passed; no build or QEMU execution')
end)
