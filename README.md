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
