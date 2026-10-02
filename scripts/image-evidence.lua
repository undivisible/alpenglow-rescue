#!/usr/bin/env luajit
-- Manifest operations formerly embedded in shell and Actions Python blocks.
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local E=dofile(dir..'/lib/evidence.lua')
R.main(function()
 assert(R.ffi.C.chdir(R.root)==0);local mode=assert(arg[1],'manifest operation required');R.mkdir('build/evidence')
 local function revision() return R.trim(R.capture({'git','rev-parse','HEAD'})) end
 local path='build/ci/output/alpenglow-rescue-storage-1-x86_64.iso'
 local manifest='build/ci/output/manifest.json'
 if mode=='verify' or mode=='correction-base' then
  local m=R.read_json(manifest);E.verify(path,m,R)
  if mode=='verify' then R.write_json('build/evidence/image-manifest.json',m) else R.copy(path,'build/correction/base.iso');R.write_json('build/correction/base-manifest.json',m) end
  print(R.encode(m))
 elseif mode=='fixtures' then
  local files=R.object();for _,p in ipairs(R.files('build/fixtures')) do if p:match('%.img$') then files[p:match('[^/]+$')]=E.file(p,R) end end
  R.write_json('build/evidence/fixture-manifest.json',{scope='synthetic regular CI files; no host mounts; QEMU backend read-only',files=files})
 elseif mode=='base' then
  local name=assert(os.getenv('ALPENGLOW_IMAGE_NAME'));assert(name:match('^[%w_-]+$'))
  path='build/ci/output/'..name..'.iso';local pins=R.read_json('pins.json');local f=E.file(path,R)
  local m={scope='Native FAST base proof only; rescue clients, payload, restored drivers and network readiness absent',project_commit=revision(),alpenglow_commit=pins.alpenglow,kernel=pins.fast_native,image_bytes=f.bytes,image_sha256=f.sha256,tested_firmware=R.null,native_artifacts={}}
  if os.getenv('ALPENGLOW_RESCUE_INCREMENT')=='storage-1' then
   m.scope='Native storage-1 partial rescue: built-in storage/filesystems/EFI and signed APK tools; no network/firmware/AI parity claim';m.kernel_config_sha256=R.sha('build/ci/output/kernel.config')
   m.kernel.base_firmware='none; storage/EFI restoration recorded separately; broad physical coverage pending'
  end
  for _,n in ipairs({'vmlinuz','initramfs.cpio.lz4','alpenglow-init','toybox','dinit'}) do m.native_artifacts[n]=E.file('build/fast-source/build/native/'..n,R) end
  R.write_json(manifest,m);R.write(path..'.sha256',f.sha256..'  '..name..'.iso\n')
 elseif mode=='correction' then
  local m=R.read_json('build/correction/base-manifest.json')
  assert(R.sha('build/correction/iso-root/boot/vmlinuz')==m.native_artifacts.vmlinuz.sha256,'native kernel changed')
  m.base_project_commit=m.project_commit;m.base_image_sha256=m.image_sha256;m.project_commit=revision()
  m.scope='Native storage-1a partial rescue; exact embedded native kernel plus small supplemental shell/terminfo/probe initramfs. No networking/firmware/AI/full parity claim.'
  local f=E.file(path,R);m.image_sha256=f.sha256;m.image_bytes=f.bytes
  m.supplemental_initramfs=E.file('build/correction/iso-root/boot/storage-correction.cpio.gz',R)
  local o=m.supplemental_initramfs;o.shell='/bin/sh -> /usr/bin/oksh';o.probe_sha256=R.sha('scripts/smoke-storage.sh');o.terminfo_package='ncurses-terminfo-base=6.5_p20251123-r0';o.terminfo_archive_sha256=R.sha('build/correction/terminfo.tar')
  R.write_json(manifest,m);R.write(path..'.sha256',f.sha256..'  '..path:match('[^/]+$')..'\n');print(R.encode(m))
 else error('unknown manifest operation: '..mode) end
end)
