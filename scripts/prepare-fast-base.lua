#!/usr/bin/env luajit
local R=dofile((arg[0]:match('^(.*)/') or '.')..'/lib/rescue.lua')
R.main(function()
 local a=R.cli({check='flag'});local root=R.root;local source=root..'/vendor/alpenglow';local pins=R.read_json(root..'/pins.json')
 local continuation=os.getenv('ALPENGLOW_FAST_CONTINUATION')=='1'
 local increment=os.getenv('ALPENGLOW_RESCUE_INCREMENT') or 'fast-base'
 assert(increment=='fast-base' or increment=='storage-1')
 if increment=='storage-1' then assert(os.getenv('CI')=='true','Storage compilation is CI-only while local Docker is below floor') end
 local floor=continuation and 14680064 or 31457280
 assert(R.trim(R.capture({'git','-C',source,'rev-parse','HEAD'}))==pins.alpenglow,'source pin mismatch')
 local paths={'scripts/boot-native.sh','system/backends/appliance/scripts/build-kernel-fast.sh','scripts/lib/assemble-rootfs.sh'}
 local adapted={}
 local function span(s,first,last) local i=assert(s:find(first,1,true));local j=assert(s:find(last,i,true));return s:sub(i,j-1) end
 for index,name in ipairs(paths) do
  local original=R.read(source..'/'..name);local t=original
  if index==3 then
   t=R.replace(t,'root:x:0:0:root:/root:/bin/toybox sh','root:x:0:0:root:/root:/bin/sh');assert(not t:find('/root:/bin/toybox sh',1,true))
  else
   if index==1 then
    local n=assert(t:match('\n(NPROC=[^\n]+)'));t=R.replace(t,n,'NPROC="1"',1)
    t=R.replace(t,'make -j$(nproc) LDFLAGS="-static"','CPUS=1 make -j1 CFLAGS="-D_GNU_SOURCE -include string.h" LDFLAGS="-static"')
   end
   t=R.replace(t,'tar -xzf /tmp/toybox.tar.gz -C /tmp','sha256sum /tmp/toybox.tar.gz > /out/toybox-source.sha256\n    tar -xzf /tmp/toybox.tar.gz -C /tmp')
   t=R.replace(t,'tar -xf /tmp/dinit.tar.xz -C /tmp','sha256sum /tmp/dinit.tar.xz > /out/dinit-source.sha256\n    tar -xf /tmp/dinit.tar.xz -C /tmp')
   if increment=='storage-1' and index==1 then
    t=R.replace(t,'    tar -xzf /tmp/toybox.tar.gz -C /tmp','    tar -xzf /tmp/toybox.tar.gz -C /tmp\n    cp /tmp/toybox-*/LICENSE /out/toybox-LICENSE')
    t=R.replace(t,'    tar -xf /tmp/dinit.tar.xz -C /tmp','    tar -xf /tmp/dinit.tar.xz -C /tmp\n    cp /tmp/dinit-*/LICENSE /out/dinit-LICENSE')
   end
   if index==2 then t=R.replace(t,'      tar -xf k.tar.xz','      echo "'..pins.fast_native.kernel_sha256..'  k.tar.xz" > kernel-download.sha256\n      sha256sum -c kernel-download.sha256\n      tar -xf k.tar.xz') end
   t=R.replace(t,'cpio -o -H newc','cpio -o -H newc -R 0:0');t=R.replace(t,'$(nproc)','1');t=R.replace(t,'zstd -6 -T0','zstd -6 -T1')
   t=R.replace(t,'docker run --rm --platform','docker run --rm --cpus=1 --pids-limit=512 --memory=2g --label alpenglow-rescue.build=task15-fast-20261001 --platform')
   t=R.replace(t,'alpine:3.21 sh','alpine:3.21@'..pins.fast_toolchain.alpine_3_21..' sh')
   t=R.replace(t,'debian:bookworm-slim sh','debian:bookworm-slim@'..pins.fast_toolchain.debian_bookworm_slim..' sh')
   local guard='    for rescue_path in / /out; do\n      [ "$(df -Pk "$rescue_path" | awk "END {print \\$4}")" -ge '..floor..' ] || exit 1\n    done\n'
   t=R.replace(t,"sh -c '\n","sh -c '\n"..guard)
   assert(not t:find('$(nproc)',1,true) and not t:find('-T0',1,true));assert(t:find('--cpus=1',1,true) and t:find(tostring(floor),1,true))
   if index==1 then
    for _,bounds in ipairs({{'if [ "${FAST}" = "1" ]; then','for arg in "$@"; do'},{'# Compose rootfs','# Oil (native package manager)'}}) do assert(span(original,unpack(bounds))==span(t,unpack(bounds)),'native composition changed') end
    for _,s in ipairs({'KERNEL_PROFILE=fast sh','ZIG_INIT=1','lz4 -l -9 -c'}) do assert(t:find(s,1,true)) end
   else
    assert(t:find('CONFIG_INITRAMFS_SOURCE "/out/initramfs.cpio.lz4"',1,true) and t:find('INITRAMFS_COMPRESSION_LZ4',1,true))
    assert(span(original,'# Profile-specific trimming','make ARCH=x86_64 olddefconfig')==span(t,'# Profile-specific trimming','make ARCH=x86_64 olddefconfig'))
   end
   if increment=='storage-1' then
    local anchor,hook
    if index==1 then
     anchor='# Build initramfs\n'
     hook=[=[# First rescue payload, before the native embedded-LZ4 build.
docker run --rm --cpus=1 --pids-limit=512 --memory=2g \
  --label alpenglow-rescue.build=task15-fast-20261001 --platform linux/amd64 \
  -v "${OUT_DIR}:/out" -v "${ROOT_DIR}/rescue-recipe:/recipe:ro" \
  ]=]..pins.alpine_image..' sh /recipe/scripts/add-storage-payload.sh\n'
    else
     anchor='    echo "→ compiling bzImage (this can take several minutes)..."'
     hook=[=[    # Restore storage/UEFI after every FAST-only disable, then resolve.
    ./scripts/kconfig/merge_config.sh -m .config /kcfg/storage-x86_64.fragment
    make -j1 ARCH=x86_64 olddefconfig >/dev/null
    while IFS= read -r rescue_setting; do
      case "$rescue_setting" in CONFIG_*=*) grep -qx "$rescue_setting" .config || { echo "Unresolved: $rescue_setting"; exit 1; };; esac
    done < /kcfg/storage-x86_64.fragment
    cp .config /out/storage-evidence/kernel.config
]=]
    end
    local count;t,count=R.replace(t,anchor,hook..anchor);assert(count==1,'ambiguous rescue hook')
   end
  end
  R.syntax(t);adapted[name]=t
 end
 if a.check then print('pinned Alpenglow fast recipe adaptation: passed (no source export or build created)');return end
 local minimum=continuation and 18 or (os.getenv('ALPENGLOW_BOUNDED_FAST')=='1' and 31.5 or 36)
 assert(R.free(root)>=minimum*R.GIB,'Stop: insufficient floor plus build allowance')
 local dest=root..'/build/fast-source'
 if R.exists(dest) then assert(R.trim(R.read(dest..'/.source-pin'))==pins.alpenglow) else
  R.mkdir(dest)
  -- Only the verified public source commit is archived; no WIP enters staging.
  local archive=os.tmpname();R.run({'git','-C',source,'archive','--output='..archive,pins.alpenglow})
  local ok,e=pcall(R.run,{'tar','-xf',archive,'-C',dest});os.remove(archive);assert(ok,e)
 end
 R.write(dest..'/.source-pin',pins.alpenglow..'\n')
 for name,t in pairs(adapted) do R.write(dest..'/'..name,t) end
 if increment=='storage-1' then
  local recipe=dest..'/rescue-recipe';R.mkdir(recipe..'/scripts');R.copy(root..'/packages-storage.txt',recipe..'/packages-storage.txt')
  for _,name in ipairs({'add-storage-payload.sh','smoke-storage.sh'}) do R.copy(root..'/scripts/'..name,recipe..'/scripts/'..name) end
  R.copy(root..'/kernel/storage-x86_64.fragment',dest..'/system/backends/appliance/kernel/storage-x86_64.fragment')
 end
 R.mkdir(root..'/build/evidence');local hashes={};for name,t in pairs(adapted) do hashes[name]=R.sha_text(t) end
 R.write_json(root..'/build/evidence/fast-recipe-adaptation.json',{source=pins.alpenglow,purpose=increment,container_floor_kib=floor,build_jobs=1,adapted_file_sha256=hashes})
 print(dest)
end)
