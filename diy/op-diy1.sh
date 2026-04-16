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

echo "开始 DIY1 配置……"
echo "========================="

# luci-app-homeproxy
#git clone https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy           ####### homeproxy的默认版本(二选一) 
#git clone -b dev https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy
#merge_package v5 https://github.com/sbwml/openwrt_helloworld  package/luci-app-homeproxy chinadns-ng sing-box
#sed -i "s@ImmortalWrt@OpenWrt@g" package/luci-app-homeproxy/po/zh_Hans/homeproxy.po
#sed -i "s@ImmortalWrt proxy@OpenWrt proxy@g" package/luci-app-homeproxy/htdocs/luci-static/resources/view/homeproxy/{client.js,server.js}

## luci-app-passwall
#merge_package main https://github.com/xiaorouji/openwrt-passwall package luci-app-passwall

# luci-app-nikki和luci-app-momo
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git;main" >> "feeds.conf.default"
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git;main" >> "feeds.conf.default"

# luci-app-daed
git clone https://github.com/sbwml/package_kernel_vmlinux-btf package/kernel/vmlinux-btf
#merge_package v5 https://github.com/sbwml/openwrt_helloworld package/dae daed luci-app-daed
git clone https://github.com/QiuSimons/luci-app-daed package/dae

# luci-app-fancontrol 风扇控制
#merge_package main https://github.com/rockjake/luci-app-fancontrol.git package luci-app-fancontrol
#merge_package main https://github.com/rockjake/luci-app-fancontrol.git package fancontrol
#sed -i 's/风扇通用控制小程序/风扇控制/g' package/luci-app-fancontrol/po/zh_Hans/fancontrol.po
#sed -i 's/services/system/g' package/luci-app-fancontrol/root/usr/share/luci/menu.d/luci-app-fancontrol.json

# luci-app-openclash
#merge_package master https://github.com/vernesong/OpenClash package luci-app-openclash

# bpf - add host clang-15/18/20 support
#sed -i 's/clang-13/clang-15 clang-18 clang-20/g' include/bpf.mk

# Realtek driver - R8168 & R8125 & R8126 & R8152 & R8101 & r8127
#rm -rf package/kernel/{r8168,r8101,r8125,r8126,r8127}
#git clone https://github.com/sbwml/package_kernel_r8168 package/kernel/r8168
#git clone https://github.com/sbwml/package_kernel_r8152 package/kernel/r8152
#git clone https://github.com/sbwml/package_kernel_r8101 package/kernel/r8101
#git clone https://github.com/sbwml/package_kernel_r8125 package/kernel/r8125
#git clone https://github.com/sbwml/package_kernel_r8126 package/kernel/r8126
#git clone https://github.com/sbwml/package_kernel_r8127 package/kernel/r8127

# luci-theme-kucat
#git clone -b js https://github.com/sirpdboy/luci-theme-kucat.git package/luci-theme-kucat
#sed -i '/set luci.main.mediaurlbase*/d' package/luci-theme-kucat/root/etc/uci-defaults/30_luci-kucat

## autocore automount default-settings
merge_package master https://github.com/immortalwrt/immortalwrt package/emortal package/emortal/default-settings

echo "========================="
echo " DIY1 配置完成……"
