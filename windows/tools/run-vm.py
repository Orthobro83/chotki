#!/usr/bin/env python3
"""Run a PowerShell script over SSH using ignored, local VM credentials."""
import base64
import os
from pathlib import Path
import subprocess
import sys
import zipfile
import hashlib
import json

root = Path(__file__).resolve().parents[1]
values = dict(line.split(': ', 1) for line in (root / 'connection.local.md').read_text().splitlines() if ': ' in line)
upload = len(sys.argv) == 3 and sys.argv[1] == '--upload'
if upload:
    source = Path(sys.argv[2]).resolve()
    source.relative_to(root)
    script = '# upload'
elif len(sys.argv) == 2:
    relative = Path(sys.argv[1]).resolve().relative_to(root)
    # Shared WebDAV reads may serve stale files. Transfer only public build inputs
    # through SSH, then expand them onto native C: before invoking the script.
    archive = root / 'source-sync.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for name in ('Package.swift','README.md','AGENTS.md','BUILD-ENVIRONMENT.md','PORT.md'):
            if (root/name).exists(): bundle.write(root/name,name)
        for name in ('Sources','shared-core','Fonts','tools'):
            for item in (root/name).rglob('*'):
                if item.is_file() and not any(part in ('Assets','.build','.swiftpm','__pycache__') for part in item.relative_to(root/name).parts):
                    bundle.write(item, str(item.relative_to(root)))
        fingerprint=root/'Sources/ChotkiWindows/Assets/catalog.sha256'
        if fingerprint.exists(): bundle.write(fingerprint,'assets-required.sha256')
        bundle.writestr('source-manifest.json',json.dumps(bundle.namelist()))
    subprocess.run([sys.executable,__file__,'--upload',str(archive)],check=True)
    archive_hash=hashlib.sha256(archive.read_bytes()).hexdigest().upper()
    guest_script = "C:\\workspace-build\\" + str(relative).replace("/", "\\")
    script = "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; if ((Get-FileHash 'C:\\workspace-build\\source-sync.zip' -Algorithm SHA256).Hash -ne '" + archive_hash + "') { throw 'Source transfer checksum mismatch' }; Expand-Archive 'C:\\workspace-build\\source-sync.zip' 'C:\\workspace-build' -Force; $env:CHOTKI_SYNCHRONIZED_ARCHIVE='1'; & 'C:\\workspace-build\\tools\\sync-sources-vm.ps1'; & '" + guest_script.replace("'", "''") + "'; exit $LASTEXITCODE"
else:
    script = sys.stdin.read()
if not script.strip():
    raise SystemExit('Supply a PowerShell script file or pipe a script on stdin.')
env = os.environ.copy()
env['CHOTKI_VM_PASSWORD'] = values['Password']
env['CHOTKI_VM_DESTINATION'] = values['Username'] + '@' + values['Host']
env['CHOTKI_VM_COMMAND'] = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' + base64.b64encode(script.encode('utf-16le')).decode()
env['CHOTKI_VM_KNOWN_HOSTS'] = str(root / 'known_hosts.local')
if upload:
    env['CHOTKI_VM_UPLOAD'] = str(source)
    env['CHOTKI_VM_UPLOAD_DESTINATION'] = values['Username'] + '@' + values['Host'] + ':C:/workspace-build/' + source.name
expect = r'''
set timeout 600
if {[info exists env(CHOTKI_VM_UPLOAD)]} {
    spawn -noecho scp -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$env(CHOTKI_VM_KNOWN_HOSTS) -o ConnectTimeout=10 $env(CHOTKI_VM_UPLOAD) $env(CHOTKI_VM_UPLOAD_DESTINATION)
} else {
    spawn -noecho ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$env(CHOTKI_VM_KNOWN_HOSTS) -o ConnectTimeout=10 -o NumberOfPasswordPrompts=1 $env(CHOTKI_VM_DESTINATION) $env(CHOTKI_VM_COMMAND)
}
expect {
    -re "(?i)password:" { send -- "$env(CHOTKI_VM_PASSWORD)\r"; exp_continue }
    timeout { puts stderr "SSH command timed out"; exit 124 }
    eof { set result [wait]; exit [lindex $result 3] }
}
'''
raise SystemExit(subprocess.run(['/usr/bin/expect', '-c', expect], env=env).returncode)
