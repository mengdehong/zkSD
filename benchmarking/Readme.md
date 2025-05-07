```
chmod 777 ./script.sh
./script.sh [run_times]   [dirname]
```

每个dir应该包括以下8个文件

1. generate_witness.js
2. witness.wtns
3. main_0000.zkey
4. main.wasm
5. proof.json
6. public.json
7. good_input.json
8. verification_key.json

此外，main.r1cs留以备份。由以下命令产生

```
circom main.circom --r1cs --O2
```
