Add-Content -Path "C:/Users/Denis/.ssh/config" -Value @"
Host $hostname
  HostName ${hostname}
  User ${user}
  IdentityFile ${identityfile}
"@
