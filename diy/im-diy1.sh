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

readonly SCRIPT_START=$(date +%s)
readonly PKG_DIR="$(pwd)/package/custom"          # 绝对路径，中途 cd 不失效
readonly PKGINFO="tmp/.packageinfo"

# ================================================================
# 主流程
# ================================================================

mkdir -p "$PKG_DIR"

# luci-app-nikki
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"

# luci-app-hon
git clone https://github.com/QiuSimons/luci-app-honk.git  "$PKG_DIR/honk"  "" --depth=1
# ------------------------------------------------------------------
# 预放 honk-core.bin：--if-needed 检测到无 stamp 的产物会直接复用，
# 跳过 zig/bpf-linker/cargo 工具链校验和源码编译
# ------------------------------------------------------------------
HONK_DIR="$PKG_DIR/honk/honk"
HONK_OUT="$HONK_DIR/files/honk-core.bin"
if [ -s "$HONK_OUT" ]; then
    log " ↷ honk-core.bin 已存在，跳过预放"
else
    group "预放 honk-core.bin（免 zig 工具链）"
    curl -fsSL --retry 3 -o /tmp/honk-core.tar.gz \
      "https://github.com/daeuniverse/honk/releases/download/v0.1.0-beta.6/honk-core-v0.1.0-beta.6-aarch64-unknown-linux-musl-stock-native-api.tar.gz"
    echo "be9152ee2034be834200af2abb1bbc9616210d94b948eafa8680f77d87be88a7  /tmp/honk-core.tar.gz" | sha256sum -c -
    rm -rf /tmp/honkpkg && mkdir -p /tmp/honkpkg
    tar -xzf /tmp/honk-core.tar.gz -C /tmp/honkpkg
    core="$(find /tmp/honkpkg -type f -name honk-core -print -quit)"
    [ -n "$core" ] || die "tarball 内未找到 honk-core，release 结构可能已变"
    mkdir -p "$HONK_DIR/files"
    cp "$core" "$HONK_OUT"
    log " ✅ 已预放 honk-core.bin ($(du -h "$HONK_OUT" | cut -f1))"
    endgroup

merge_package v5 https://github.com/sbwml/openwrt_helloworld package/dae v2ray-geodata

# bpf - add host clang-15/18/20 support
sed -i 's/clang-13/clang-15 clang-18 clang-20/g' include/bpf.mk

echo "========================="
echo " DIY1 配置完成……"
