cat <<EOF > /etc/systemd/system/wireguard-install.service
[Unit]
Description=Setup WireGuard
After=network.target
[Service]
Type=oneshot
ExecStart=/etc/wireguard-setup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/wireguard-module.service
[Unit]
Description=WireGuard module loading
Before=network-pre.target
Wants=network-pre.target
DefaultDependencies=no
Requires=torcx.target local-fs.target
After=torcx.target local-fs.target
[Service]
Type=oneshot
EnvironmentFile=/run/metadata/torcx
ExecStartPre=-/sbin/modprobe ip6_udp_tunnel
ExecStartPre=-/sbin/modprobe udp_tunnel
ExecStart=-/sbin/insmod \${TORCX_UNPACKDIR}/WireGuard/lib/modules/%v/extra/wireguard.ko
RemainAfterExit=yes
[Install]
WantedBy=network.target
EOF

cat <<EOF > /etc/wireguard-setup
#!/bin/bash
set -ex
source /etc/os-release
HOME="/home/core"
PKG="/var/lib/torcx/store/\${VERSION_ID}/WireGuard:CoreOS_\${VERSION_ID}.torcx.tgz"
BIN="/var/run/torcx/bin/wg"
if [ -f "\${BIN}" ]
then
  exit 0
fi
cd \$HOME
mkdir -p "/var/lib/torcx/store/\${VERSION_ID}"
URL="https://github.com/miguelangel-nubla/WireGuard-CoreOS/releases/download/latest-all/WireGuard.CoreOS_\${VERSION_ID}.torcx.tgz"
if [[ \$(curl -s -o /dev/null -I -w "%{http_code}" "\$URL") = 302 ]]
then
  wget "\$URL" -O "\${PKG}"
else
  TMP_DIR=\$(mktemp -d -t tmp-wireguard-XXXXXXXXXX --tmpdir=/home/core)
  git clone https://github.com/miguelangel-nubla/WireGuard-CoreOS.git \$TMP_DIR
  cd \$TMP_DIR
  source /usr/share/coreos/update.conf
  ./run.sh "\$GROUP" "\$VERSION_ID"
  mv -f ".tmp/WireGuard.CoreOS_\${VERSION_ID}.torcx.tgz" "\${PKG}"
fi
jq '.value.images += [{ "name": "WireGuard", "reference": "'CoreOS_\${VERSION_ID}'" }]' /usr/share/torcx/profiles/vendor.json > /etc/torcx/profiles/wg.json
echo wg > /etc/torcx/next-profile
reboot
EOF

chmod 500 /etc/wireguard-setup

cat <<EOF > /etc/profile.d/torcx-path.sh
export PATH="/var/run/torcx/bin:\${PATH}"
EOF

chmod 400 /etc/profile.d/torcx-path.sh

systemctl enable wireguard-install
systemctl enable wireguard-module

reboot
