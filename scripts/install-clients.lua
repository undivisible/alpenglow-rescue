#!/usr/bin/env luajit
-- Official npm payloads only; SHA512 checked before safe libarchive extraction.
local R=dofile((arg[0]:match('^(.*)/') or '.')..'/lib/rescue.lua')
R.main(function()
 assert(R.ffi.C.chdir(R.root)==0);assert(R.free('.')>=40*R.GIB,'Stop: less than 40 GiB host headroom')
 local pins=R.read_json('pins.json');local root='build/rootfs'
 local packages={claude={'@anthropic-ai/claude-code-linux-x64-musl',pins.claude.version},codex={'@openai/codex',pins.codex.version..'-linux-x64'},opencode={'opencode-linux-x64-baseline-musl',pins.opencode.version}}
 R.mkdir('build/evidence');R.mkdir('build/downloads');R.mkdir(root..'/usr/local/bin')
 for _,name in ipairs({'claude','codex','opencode'}) do
  local package,version=unpack(packages[name]);local raw=R.capture({'curl','--proto','=https','-fsSL','--max-time','60','https://registry.npmjs.org/'..package..'/'..version},{timeout=65})
  local meta,_,err=R.json.decode(raw,1,R.null);assert(not err,err);R.write_json('build/evidence/'..name..'-npm.json',meta)
  assert(meta.dist.tarball:match('^https://registry%.npmjs%.org/'),'unexpected npm payload origin')
  local archive='build/downloads/'..name..'-'..version..'.tgz'
  if not R.exists(archive) then R.run({'curl','--proto','=https','-fL','--max-time','300',meta.dist.tarball,'-o',archive},{timeout=305}) end
  local digest=R.capture({'openssl','dgst','-sha512','-binary',archive})
  local actual='sha512-'..R.trim(R.capture({'openssl','base64','-A'},{input=digest}))
  assert(actual==meta.dist.integrity,name..': integrity mismatch')
  -- libarchive's default extraction rejects .. and symlink traversal. Reject
  -- absolute/parent member paths explicitly too, before writing any member.
  for member in R.capture({'bsdtar','-tf',archive}):gmatch('[^\n]+') do
   assert(member:sub(1,1)~='/' and not ('/'..member..'/'):find('/../',1,true),'unsafe archive member')
  end
  local dest=root..'/opt/'..name;R.mkdir(dest)
  R.run({'bsdtar','--no-same-owner','--no-same-permissions','-xf',archive,'-C',dest})
  local choices={};for _,path in ipairs(R.files(dest)) do
   if (name=='codex' and path:match('/x86_64%-unknown%-linux%-musl/codex/codex$')) or
      (name~='codex' and (path:sub(-#('/bin/'..name))=='/bin/'..name or path:sub(-#('/bin/'..name..'.exe'))=='/bin/'..name..'.exe')) then choices[#choices+1]=path end
  end
  assert(#choices==1,name..': executable not unique');R.run({'chmod','755',choices[1]})
  local link=root..'/usr/local/bin/'..name;os.remove(link);R.run({'ln','-s',choices[1]:sub(#root+1),link})
  print(name..' '..version..': '..R.size(archive)..' compressed bytes, '..R.size(choices[1])..' executable bytes')
 end
end)
