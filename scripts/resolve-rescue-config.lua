#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local E=dofile(dir..'/lib/evidence.lua')
R.main(function()
 local base='/project/vendor/alpenglow/system/backends/appliance';local kernel='/out/linux-7.1.3';local fast='/out/config-fast';local rescue='/out/config-rescue'
 R.mkdir(fast);R.mkdir(rescue);local text=R.read(base..'/kernel/alpenglow-qemu-minimal.config')
 for _,name in ipairs({'lz4.config','virt.config','fast.config'}) do text=text..R.read(base..'/kernel/'..name) end;R.write(fast..'/.config',text)
 local function resolve(p) R.run({'make','-j1','ARCH=x86_64','O='..p,'olddefconfig'},{cwd=kernel,timeout=300}) end
 resolve(fast);text=R.read(base..'/scripts/build-kernel-fast.sh');local start=assert(text:find('# Profile-specific trimming',1,true));text=text:sub(start,assert(text:find('if [ "${PROFILE}" = "minimal" ]',start,true))-1)
 local cmd={kernel..'/scripts/config','--file',fast..'/.config'};local count=0
 for symbol in text:gmatch('%-%-disable ([A-Z][A-Z0-9_]*)') do cmd[#cmd+1]='--disable';cmd[#cmd+1]=symbol;count=count+1 end
 R.run(cmd);resolve(fast);R.copy(fast..'/.config',rescue..'/.config')
 R.run({kernel..'/scripts/kconfig/merge_config.sh','-m','-O',rescue,rescue..'/.config','/project/kernel/rescue-x86_64.fragment'},{cwd=kernel});resolve(rescue)
 local mismatches,n=E.mismatches(E.config(R.read('/project/kernel/rescue-x86_64.fragment')),E.config(R.read(rescue..'/.config')),R)
 local report={kernel='7.1.3',scope='Kconfig resolution only; no rescue modules/kernel compiled',requested=n,fast_disable_symbols=count,mismatches=mismatches,fast_config='build/fast-source/build/native/config-fast/.config',rescue_config='build/fast-source/build/native/config-rescue/.config'}
 R.write_json('/out/rescue-config-resolution.json',report);print(R.encode(report));return next(mismatches) and 1 or 0
end)
