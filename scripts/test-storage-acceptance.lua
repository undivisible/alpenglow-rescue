#!/usr/bin/env luajit
local dir=arg[0]:match('^(.*)/') or '.'
local R=dofile(dir..'/lib/rescue.lua');local A=dofile(dir..'/lib/acceptance.lua')
R.main(function()
 local bad='\nset: bad -e\nRESCUE_FIXTURE_PASS AR_ SEC_TYPE="msdos"\nRESCUE_STORAGE_READY_OK\nSTORAGE_SMOKE_EXIT=0\n';assert(not A.storage(bad))
 local lines={};for _,label in ipairs(A.labels) do lines[#lines+1]='RESCUE_FIXTURE_PASS AR_'..label..' /dev/vda' end
 lines[#lines+1]='RESCUE_TMUX_PASS';lines[#lines+1]='RESCUE_STORAGE_READY_OK';lines[#lines+1]='STORAGE_SMOKE_EXIT=0'
 local good='\n'..table.concat(lines,'\n')..'\n';assert(A.storage(good));assert(A.storage(good:gsub('\n','\r\n')))
 for missing=1,#lines do local copy={};for i,l in ipairs(lines) do if i~=missing then copy[#copy+1]=l end end;assert(not A.storage('\n'..table.concat(copy,'\n')..'\n')) end
 for _,code in ipairs({1,125,126,127}) do assert(not A.storage(R.replace(good,'STORAGE_SMOKE_EXIT=0','STORAGE_SMOKE_EXIT='..code))) end
 for _,path in ipairs(R.files(R.root..'/evidence/storage-validation-strict-failed/build/bench')) do if path:match('%.serial%.txt$') then assert(not A.storage(R.read(path)),path) end end
 for _,path in ipairs(R.files(R.root..'/evidence/storage-validation-rejected/build/bench')) do if path:match('%.serial%.txt$') then assert(not A.storage(R.read(path)),path) end end
 print('LuaJIT storage acceptance: LF/CRLF success, missing markers, exit1/125/126/127 and all retained failures checked')
end)
