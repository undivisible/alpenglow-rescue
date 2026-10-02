#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local E=dofile(dir..'/lib/evidence.lua')
R.main(function()
 local root=R.root;local native=root..'/build/fast-source/build/native';local evidence=native..'/storage-evidence'
 local packages=E.apk(R.read(evidence..'/apk-installed.txt'),R);local missing=R.array();local total=0;local lock={}
 for _,p in ipairs(packages) do total=total+p.installed_bytes;lock[#lock+1]=p.name..'='..p.version..'\n';if p.license==R.null or p.license=='' then missing[#missing+1]=p.name end end
 local report={scope='Signed Alpine v3.23 package solution for storage-1; native kernel/init retained; no AI clients/firmware',signature_verification='apk default verification; no --allow-untrusted; no package scripts',packages=packages,licenses_without_metadata=missing,kernel_config_sha256=R.sha(evidence..'/kernel.config'),source_repository_caveat='First resolution uses the official v3.23 indexes at build time. Exact versions/build commits recorded; source archiving/distribution audit required before a final release.'}
 local output=root..'/build/ci/output';R.mkdir(output);R.write_json(output..'/package-license-inventory.json',report);R.write(output..'/packages.lock',table.concat(lock))
 for _,name in ipairs({'kernel.config','apk-installed.txt','native-core.sha256','repositories.txt'}) do R.copy(evidence..'/'..name,output..'/'..name) end
 local iso=root..'/build/ci/iso-root';R.mkdir(iso);R.write_json(iso..'/PACKAGE-LICENSES.json',report)
 local small=root..'/build/evidence';R.mkdir(small)
 for _,path in ipairs(R.files(output)) do if not path:match('%.iso$') then R.copy(path,small..'/storage-'..path:match('[^/]+$')) end end
 R.mkdir(iso..'/licenses')
 for name,source in pairs({['linux-COPYING']='linux-7.1.3/COPYING',['linux-GPL-2.0']='linux-7.1.3/LICENSES/preferred/GPL-2.0',['toybox-LICENSE']='toybox-LICENSE',['dinit-LICENSE']='dinit-LICENSE'}) do if R.exists(native..'/'..source) then R.copy(native..'/'..source,iso..'/licenses/'..name) end end
 print(R.encode({packages=#packages,installed_bytes=total,missing_license_metadata=missing}))
end)
