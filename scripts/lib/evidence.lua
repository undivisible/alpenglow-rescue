local E={}
function E.apk(text,R)
 local packages=R.array()
 for record in (text..'\n\n'):gmatch('(.-)\n\n') do
  local f={};for line in record:gmatch('[^\n]+') do local k,v=line:match('^(%a):(.*)$');if k then f[k]=v end end
  if f.P then packages[#packages+1]={name=f.P,version=assert(f.V),license=f.L or R.null,origin=f.o or R.null,
   installed_bytes=assert(tonumber(f.I or '0')),apk_checksum=f.C or R.null,aports_commit=f.c or R.null,homepage=f.U or R.null,
   source_recipe_tree='https://gitlab.alpinelinux.org/alpine/aports/-/tree/'..(f.c or 'None'),source_recipe_origin=f.o or R.null} end
 end
 table.sort(packages,function(a,b)return a.name<b.name end);return packages
end
function E.config(text) local t={} for k,v in ('\n'..text):gmatch('\nCONFIG_([%w_]+)=([^\n]+)') do t[k]=v end;return t end
function E.mismatches(requested,actual,R)
 local m=R.object();local n=0;for k,v in pairs(requested) do n=n+1;local resolved=actual[k] or 'n';if resolved~=v and not(v=='m' and resolved=='y') then m[k]={requested=v,resolved=resolved} end end;return m,n
end
function E.verify(path,m,R) assert(R.size(path)==m.image_bytes,'image size mismatch');assert(R.sha(path)==m.image_sha256,'image SHA256 mismatch') end
function E.file(path,R) return {bytes=R.size(path),sha256=R.sha(path)} end
return E
