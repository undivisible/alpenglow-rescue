#!/bin/sh
# Called only inside a bounded CI container, with task-owned /out mounted.
set -eu
for path in / /out; do
  test "$(df -Pk "$path" | awk 'END {print $4}')" -ge 22020096
done
test -f /out/rootfs/bin/toybox
test -f /out/rootfs/sbin/dinit
mkdir -p /out/storage-payload /out/storage-evidence
# Verify Alpine signatures and solve dependencies; execute no package scripts.
apk --root /out/storage-payload --arch x86_64 --initdb --no-scripts \
  --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories \
  add --no-cache $(sed '/^#/d;/^$/d' /recipe/packages-storage.txt)
cp /out/storage-payload/lib/apk/db/installed /out/storage-evidence/apk-installed.txt
cp /etc/apk/repositories /out/storage-evidence/repositories.txt
cp -a /etc/apk/keys /out/storage-evidence/verification-keys
# Retain native init, PID 1, local login and service configuration. Import only
# package executables, libraries and shared data, not Alpine boot/auth services.
for dir in bin sbin lib usr; do
  cp -a "/out/storage-payload/$dir/." "/out/rootfs/$dir/"
done
for applet in sh login getty; do ln -snf /bin/toybox "/out/rootfs/bin/$applet"; done
ln -snf /bin/toybox /out/rootfs/sbin/getty
mkdir -p /out/rootfs/usr/local/bin /out/rootfs/usr/share/alpenglow-rescue
cp /recipe/scripts/smoke-storage.sh /out/rootfs/usr/local/bin/rescue-smoke-storage
chmod 755 /out/rootfs/usr/local/bin/rescue-smoke-storage
printf '%s\n' PUBLIC_SYNTHETIC_FIXTURE_KEY_NOT_A_SECRET > /out/rootfs/usr/share/alpenglow-rescue/fixture.key
printf '%s\n' 'NAME="Alpenglow Rescue"' 'ID=alpenglow' 'VERSION_ID=storage-1-dev' \
  'PRETTY_NAME="Alpenglow Rescue storage increment (partial)"' > /out/rootfs/etc/os-release
grep -qx 'root:x:0:0:root:/root:/bin/sh' /out/rootfs/etc/passwd
sha256sum /out/rootfs/init /out/rootfs/bin/toybox /out/rootfs/sbin/dinit > /out/storage-evidence/native-core.sha256
test "$(df -Pk /out | awk 'END {print $4}')" -ge 22020096
