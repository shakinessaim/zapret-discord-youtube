#!/bin/bash

checkmodule -M -m -o ./module/zapret.mod ./module/zapret.te
semodule_package -o ./module/zapret.pp -m ./module/zapret.mod
sudo semodule -i ./module/zapret.pp

sudo semanage fcontext -a -t bin_t "/opt/zapret/init.d/sysv/zapret"
sudo restorecon -v /opt/zapret/init.d/sysv/zapret

sudo systemctl enable --now zapret
