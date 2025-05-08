### 环境配置

推荐使用docker运行本项目,请参考docker官网安装docker,运行以下命令

```
docker pull mengdh/zksd
docker run -it mengdh/zksd /bin/bash

cd benchmarking
# ./script.sh [run_times]   [dirname]
./script.sh 1 128

```

* 由于docker环境问题,运行时间会比论文中久,请自行修改docker配置

也可自行构建项目环境:

```shell
# 操作系统:ubuntu20
# circom 配置:
# 下载rust编译器
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

## 文档

circom: https://docs.circom.io/getting-started/installation/

snarkjs: https://github.com/iden3/snarkjs
