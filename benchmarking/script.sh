#!/bin/bash

# 设置要运行命令的次数（从第一个参数获取）
num_times="$1"

# 初始化总时间变量
total_time=0

# 多次运行 witness 生成命令并累加耗时
for (( i=1; i<=$num_times; i++ ))
do
    # 记录开始时间（秒，支持小数）
    start_time=$(date +%s.%N)
    # 调用 generate_witness.js 生成 witness.wtns
    node "$2"/generate_witness.js "$2"/main.wasm "$2"/good_input.json "$2"/witness.wtns
    # 记录结束时间
    end_time=$(date +%s.%N)

    # 计算本次执行时间并累加到 total_time
    execution_time=$(echo "$end_time - $start_time" | bc -l)
    total_time=$(echo "$total_time + $execution_time" | bc -l)
done

# 计算并打印平均 witness 生成时间（保留四位小数）
average_time=$(echo "scale=4; $total_time / $num_times" | bc -l)
echo "Average witness generation time: ${average_time} seconds"

# 重置总时间变量，用于下一阶段 benchmark
total_time=0

# 多次运行 proof 生成命令并累加耗时
for (( i=1; i<=$num_times; i++ ))
do
    # 记录开始时间
    start_time=$(date +%s.%N)
    # 调用 snarkjs groth16 prove 生成 proof.json 和 public.json
    snarkjs groth16 prove "$2"/main_0000.zkey "$2"/witness.wtns "$2"/proof.json "$2"/public.json
    # 记录结束时间
    end_time=$(date +%s.%N)

    # 计算本次执行时间并累加到 total_time
    execution_time=$(echo "$end_time - $start_time" | bc -l)
    total_time=$(echo "$total_time + $execution_time" | bc -l)
done

# 计算并打印平均 proof 生成时间（保留四位小数）
average_time=$(echo "scale=4; $total_time / $num_times" | bc -l)
echo "Average proof generation time: ${average_time} seconds"

# 重置总时间变量，用于下一阶段 benchmark
total_time=0

# 多次运行 verify 并累加耗时
for (( i=1; i<=$num_times; i++ ))
do
    # 记录开始时间
    start_time=$(date +%s.%N)
    # 调用 snarkjs groth16 verify，注意各参数之间的空格和引号
    snarkjs groth16 verify \
      "$2"/verification_key.json \
      "$2"/public.json \
      "$2"/proof.json
    # 记录结束时间
    end_time=$(date +%s.%N)

    # 计算本次执行时间并累加到 total_time
    execution_time=$(echo "$end_time - $start_time" | bc -l)
    total_time=$(echo "$total_time + $execution_time" | bc -l)
done


# 计算并打印平均 verify 生成时间（保留四位小数）
average_time=$(echo "scale=4; $total_time / $num_times" | bc -l)
echo "Average verify generation time: ${average_time} seconds"

