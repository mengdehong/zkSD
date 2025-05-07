## Workflow

0 预处理

```
python Prepare.py image_0045.jpg image_data.json
复制image的32×32矩阵到commmit.js中
node commit.js
```

1 编译电路

```
circom main.circom --r1cs --wasm 
```

2 生成见证

```bash
cd ../main_js
node generate_witness.js main.wasm ../../workdir/commit_1024.json witness.wtns

# Debug
snarkjs wtns export json witness.wtns witness.json
```

3 Setup

接下来6条指令一直到prove都是setup步骤

前三条指令只需要执行一次

后面三条指令 更新一次电路,就需要重新执行一次

```
方案一
#从https://github.com/iden3/snarkjs下载电路所需要的ptau文件

cd ..
snarkjs powersoftau new bn128 19 pot19_0000.ptau -v

snarkjs powersoftau contribute pot19_0000.ptau pot19_0001.ptau --name="First contribution" -v
# Enter a random text. (Entropy): 123456789

# 这一步非常慢!
snarkjs powersoftau prepare phase2 pot19_0001.ptau pot19_final.ptau -v
```

```
snarkjs groth16 setup main.r1cs pot19_final.ptau main_0000.zkey

snarkjs zkey contribute main_0000.zkey main_0001.zkey --name="1st Contributor Name" -v
# Entropy:输入123456789

snarkjs zkey export verificationkey main_0001.zkey verification_key.json
```

4 prove

```
snarkjs groth16 prove main_0001.zkey ./main_js/witness.wtns proof.json public.json
```

测试

```
hyperfine "snarkjs groth16 prove main_0001.zkey ./main_js/witness.wtns proof.json public.json"
```

5 verify

```
snarkjs groth16 verify verification_key.json public.json proof.json
```

6 导出SC

```
snarkjs zkey export solidityverifier main_0001.zkey verifier.sol
```

hyperfine : 测试程序执行时间的工具

安装：

```
 sudo apt update
 wget https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb
 sudo dpkg -i hyperfine_1.18.0_amd64.deb
 hyperfine --version
```

```
snarkjs wtns export json witness.wtns witness.json
```
