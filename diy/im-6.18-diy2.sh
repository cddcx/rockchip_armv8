#!/bin/bash

# 拉取仓库文件夹
merge_package() {
	# 参数1是分支名,参数2是库地址,参数3是所有文件下载到指定路径。
	# 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
	# 示例:
	# merge_package master https://github.com/WYC-2020/openwrt-packages package/openwrt-packages luci-app-eqos luci-app-openclash luci-app-ddnsto ddnsto 
	# merge_package master https://github.com/lisaac/luci-app-dockerman package/lean applications/luci-app-dockerman
	if [[ $# -lt 3 ]]; then
		echo "Syntax error: [$#] [$*]" >&2
		return 1
	fi
	trap 'rm -rf "$tmpdir"' EXIT
	branch="$1" curl="$2" target_dir="$3" && shift 3
	rootdir="$PWD"
	localdir="$target_dir"
	[ -d "$localdir" ] || mkdir -p "$localdir"
	tmpdir="$(mktemp -d)" || exit 1
	git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
	cd "$tmpdir"
	git sparse-checkout init --cone
	git sparse-checkout set "$@"
	# 使用循环逐个移动文件夹
	for folder in "$@"; do
		mv -f "$folder" "$rootdir/$localdir"
	done
	cd "$rootdir"
}

drop_package(){
	find package/ -follow -name $1 -not -path "package/custom/*" | xargs -rt rm -rf
}

merge_feed(){
	./scripts/feeds update $1
	./scripts/feeds install -a -p $1
}

echo "开始 DIY2 配置……"
echo "========================="

#chmod +x ${GITHUB_WORKSPACE}/function.sh
#source ${GITHUB_WORKSPACE}/function.sh

# 修改内核
sed -i 's/PATCHVER:=*.*/PATCHVER:=6.18/g' target/linux/rockchip/Makefile 

# 默认IP
#sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 修改密码
sed -i 's/root:::0:99999:7:::/root:$1$SOP5eWTA$fJV8ty3QohO0chErhlxCm1:18775:0:99999:7:::/g' package/base-files/files/etc/shadow

# 使用测试版内核
echo "CONFIG_TESTING_KERNEL=y" >> .config

# 最大连接数修改为65535
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# luci-compat - 修复上移下移按钮翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

# luci-compat - remove extra line breaks from description
sed -i '/<br \/>/d' feeds/luci/modules/luci-compat/luasrc/view/cbi/full_valuefooter.htm

# 修复procps-ng-top导致首页cpu使用率无法获取
sed -i 's#top -n1#\/bin\/busybox top -n1#g' feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci

# 修复编译时提示 freeswitch 缺少 libpcre 依赖
#sed -i 's/+libpcre \\$/+libpcre2 \\/g' package/feeds/telephony/freeswitch/Makefile

# 精简 UPnP 菜单名称
sed -i 's#\"title\": \"UPnP IGD \& PCP/NAT-PMP\"#\"title\": \"UPnP\"#g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json
# 移动 UPnP 到 “网络” 子菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json

# nginx
#rm -rf feeds/packages/net/nginx
#git clone https://github.com/sbwml/feeds_packages_net_nginx -b openwrt-25.12 feeds/packages/net/nginx

## 删除软件
#rm -rf feeds/luci/themes/luci-theme-bootstrap
rm -rf feeds/luci/applications/{luci-app-adguardhome,luci-app-alist,luci-app-daed,luci-app-filebrowser,luci-app-filemanager,luci-app-v2raya,luci-app-microsocks,luci-app-passwall,luci-app-shadowsocks-libev,luci-app-openclash}
rm -rf feeds/packages/net/{adguardhome,alist,daed,v2raya,v2ray-core,v2ray-geodata,v2ray-plugin,microsocks,shadowsocks-libev}

## 修改target.mk
#sed -i 's/dnsmasq/dnsmasq-full/g' include/target.mk
sed -i "s/kmod-nft-offload/kmod-nft-offload kmod-nft-tproxy/" include/target.mk
#sed -i "s/odhcp6c/ipv6-helper/" include/target.mk
sed -i "s/DEFAULT_PACKAGES.router:=/DEFAULT_PACKAGES.router:=bash default-settings-chn vmlinux-btf luci-app-firewall /" include/target.mk

# 删除luci-app-cpufreq
#sed -i '#luci-app-cpufreq \#d' include/target.mk
#rm -rf package/emortal/cpufreq

## 修改target/linux/rockchip/Makefile
sed -i 's/DEFAULT_PACKAGES += /DEFAULT_PACKAGES += luci-app-quickfile /g' target/linux/rockchip/Makefile

# 更新 golang 版本
#rm -rf feeds/packages/lang/golang
#git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# nanopc-t6
echo '# 启用 eBPF 支持
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y
' >>  ./.config

# 自定义默认配置
#sed -i '/exit 0$/d' package/emortal/default-settings/files/99-default-settings
#cat ${GITHUB_WORKSPACE}/default-settings >> package/emortal/default-settings/files/99-default-settings

./scripts/feeds install -a

echo "========================="
echo " DIY2 配置完成……"
