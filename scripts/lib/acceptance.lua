local A={labels={'EXT4','BTRFS','XFS','FAT','EXFAT','NTFS','LUKS'}}
function A.line(log,line) return log:find('\n'..line..'\r?\n')~=nil end
function A.storage(log)
 for _,label in ipairs(A.labels) do if not A.line(log,'RESCUE_FIXTURE_PASS AR_'..label..' /dev/%S+') then return false end end
 return A.line(log,'RESCUE_TMUX_PASS') and A.line(log,'RESCUE_STORAGE_READY_OK') and A.line(log,'STORAGE_SMOKE_EXIT=0')
end
function A.network_console(log)
 return A.line(log,'RESCUE_VIRTUAL_DHCP_OK') and A.line(log,'NETWORK_SMOKE_EXIT=0') and A.line(log,'TTY1_COMMAND_OK')
end
return A
