## 文档

circom: https://docs.circom.io/getting-started/installation/

snarkjs: https://github.com/iden3/snarkjs

### 环境配置

```shell
# ubuntu20
# circom 配置:
# circom 底层为Rust,需要下载rust编译器
# 镜像配置,可选
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup

# 下载rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# circom安装
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom

# snarkjs
node -v
npm install -g snarkjs@latest

# js环境,切换到项目根目录
npm install 

# python依赖
conda env create -f environment.yml
```

```shell
# rust下载配置
sudo vim ~/.cargo/configsd .
# 添加以下内容
# 放到 `$HOME/.cargo/config` 文件中
[source.crates-io]
#registry = "https://github.com/rust-lang/crates.io-index"

# 替换成你偏好的镜像源
replace-with = 'ustc'
#replace-with = 'sjtu'

# 清华大学
[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

# 中国科学技术大学
[source.ustc]
registry = "git://mirrors.ustc.edu.cn/crates.io-index"

# 上海交通大学
[source.sjtu]
registry = "https://mirrors.sjtug.sjtu.edu.cn/git/crates.io-index"

# rustcc社区
[source.rustcc]
registry = "git://crates.rustcc.cn/crates.io-index"
```