# 使用 Ubuntu 20.04 作为基础镜像
FROM ubuntu:20.04

# 设置环境变量，避免 apt 安装过程中的交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# --- 安装 Python 3.10 和基础编译工具 ---
# 安装基础的编译工具、项目依赖的软件以及 Python 3.10
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    bash \
    coreutils \
    bc \
    # For GPG key management
    gnupg \
    dirmngr \
    software-properties-common && \
    apt-get update && apt-get install -y --reinstall ca-certificates && \
    mkdir -p /root/.gnupg && \
    chmod 700 /root/.gnupg && \
    gpgconf --launch dirmngr && \
    mkdir -p /usr/share/keyrings && \
    (gpg --no-default-keyring --keyring /usr/share/keyrings/deadsnakes-archive-keyring.gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 || \
     gpg --no-default-keyring --keyring /usr/share/keyrings/deadsnakes-archive-keyring.gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776) && \
    echo "deb [signed-by=/usr/share/keyrings/deadsnakes-archive-keyring.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" > /etc/apt/sources.list.d/deadsnakes.list && \
    # (Optional) Add source PPA if needed
    # echo "deb-src [signed-by=/usr/share/keyrings/deadsnakes-archive-keyring.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" >> /etc/apt/sources.list.d/deadsnakes.list && \
    # 4. Update package lists with the new PPA
    apt-get update && \
    # 安装 Python 3.10 和 python3.10-dev
    apt-get install -y \
    python3.10 \
    python3.10-dev && \
    # 下载并使用 get-pip.py 安装 pip for Python 3.10
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10 && \
    # 将 python3.10 设置为默认的 python3
    # Ubuntu 20.04 默认的 python3.8 仍然存在
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2 && \
    update-alternatives --set python3 /usr/bin/python3.10 && \
    # 安装 python-is-python3, 使 /usr/bin/python 指向 /usr/bin/python3 (即 python3.10)
    apt-get install -y python-is-python3 && \
    # 升级 pip 到最新版本 (针对 Python 3.10)
    python3 -m pip install --upgrade pip && \
    # 清理 apt 缓存
    rm -rf /var/lib/apt/lists/*

# 验证 Python 和 pip 版本
RUN echo "Verifying Python and pip versions:" && \
    python --version && \
    python3 --version && \
    pip3 --version

# --- 安装 Rust 和 Cargo ---
# 设置 Rust 和 Cargo 的安装路径，并将其添加到 PATH
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static \
    RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup

# 下载并安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    rustc --version && \
    cargo --version

# --- 安装 Node.js (v18.x) 和 npm ---
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs --reinstall ca-certificates && \
    node -v && \
    npm -v && \
    rm -rf /var/lib/apt/lists/*

# --- 安装 circom ---
# 配置 Cargo 使用国内镜像
RUN mkdir -p $CARGO_HOME/.cargo && \
    echo '[source.crates-io]' > $CARGO_HOME/.cargo/config.toml && \
    echo 'replace-with = "ustc"' >> $CARGO_HOME/.cargo/config.toml && \
    echo '[source.ustc]' >> $CARGO_HOME/.cargo/config.toml && \
    echo 'registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"' >> $CARGO_HOME/.cargo/config.toml

# 克隆、编译和安装 circom
RUN git clone --depth 1 https://github.com/iden3/circom.git /tmp/circom && \
    cd /tmp/circom && \
    cargo build --release && \
    # 使用 cargo install --path <path_to_crate> 来安装本地 crate
    # circom 的 Cargo.toml 在 circom 子目录中
    cargo install --path circom && \
    cd / && \
    rm -rf /tmp/circom

# --- 全局安装 snarkjs ---
RUN npm install -g snarkjs@latest

# 设置工作目录
WORKDIR /app

# 首先复制 Python 依赖文件 (requirements.txt)
COPY requirements.txt ./

# 安装 Python 依赖 (现在会使用 Python 3.10 的 pip)
RUN if [ -f "requirements.txt" ]; then \
        echo "Installing Python requirements from requirements.txt using pip3..." && \
        pip3 install --no-cache-dir -r requirements.txt; \
    fi

# 复制项目中的所有其他文件到工作目录
COPY . .

# 安装项目特定的 Node.js 依赖
RUN if [ -f "package.json" ]; then \
        echo "Installing Node.js dependencies from package.json..." && \
        npm install; \
    fi

# 容器启动时执行的默认命令
CMD ["/bin/bash"]
