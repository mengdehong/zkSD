# phash.circom的python实现，只是为了更方便的处理图片
# 与phash.circom功能完全一致
from PIL import Image
import numpy as np
import math
import json
import sys
import os

"""生成与Circom中相同的DCT系数矩阵"""
def generate_dct_coefficients(size, scale):
    coeff = np.zeros((size, size))
    for j in range(size):
        for k in range(size):
            alpha = math.sqrt(1 / size) if j == 0 else math.sqrt(2 / size)
            coeff[j][k] = round(alpha * math.cos(math.pi * (2 * k + 1) * j / (2 * size)) * scale)
    return coeff.tolist()

def apply_dct1d(input_array, coeff):
    """实现类似Circom中的DCT1D模板"""
    n = len(input_array)
    out = np.zeros(n)
    
    # 计算乘积项
    prods = [[0 for _ in range(n)] for _ in range(n)]
    for j in range(n):
        for k in range(n):
            prods[j][k] = input_array[k] * coeff[j][k]
    
    # 计算累加和
    for j in range(n):
        out[j] = sum(prods[j])
    
    return out

def bitonic_sort64(arr):
    """实现64元素双调排序网络"""
    # 复制数组以避免修改原数组
    a = arr.copy()
    n = len(a)
    
    # 实现双调排序
    for p in range(6, 0, -1):
        n_val = 1 << p
        for q in range(p-1, -1, -1):
            d = 1 << q
            for i in range(64):
                j = i ^ d
                if j > i:
                    dir_val = (i & n_val) == 0
                    if ((a[i] > a[j]) and dir_val) or ((a[i] < a[j]) and not dir_val):
                        a[i], a[j] = a[j], a[i]
    
    return a

def phash_circom(image_path, output_hash_path=None):
    """模拟Circom中的PHash实现"""
    # 1. 处理图像
    img = Image.open(image_path).convert('L')
    img_resized = img.resize((32, 32), Image.Resampling.LANCZOS)
    img_array = np.array(img_resized).tolist()
    
    # 2. 生成DCT系数
    size = 32
    hash_size = 8
    scale = 2**64
    coeff_row = generate_dct_coefficients(size, scale)
    coeff_col = generate_dct_coefficients(size, scale)
    
    # 3. 对每一行应用1D DCT
    temp = np.zeros((32, 32))
    for i in range(32):
        temp[i] = apply_dct1d(img_array[i], coeff_row)
    
    # 4. 对每一列应用1D DCT
    dct_scaled = np.zeros((32, 32))
    for j in range(32):
        col = temp[:, j]
        result = apply_dct1d(col, coeff_col)
        for i in range(32):
            dct_scaled[i][j] = result[i]
    
    # 5. 提取低频8x8区块
    lowfreq = dct_scaled[:hash_size, :hash_size]
    
    # 6. 将8x8区块展平为一维数组
    flat = lowfreq.flatten()
    
    # 7. 排序64个值
    sorted_values = bitonic_sort64(flat)
    
    # 8. 计算中值阈值（取排序后的中间两个值的和）
    median_sum = sorted_values[31] + sorted_values[32]
    
    # 9. 生成哈希值
    hash_array = np.zeros((hash_size, hash_size), dtype=int)
    for i in range(hash_size):
        for j in range(hash_size):
            # 2*值与中值和比较，大于时为1，否则为0
            hash_array[i][j] = 1 if 2 * lowfreq[i][j] > median_sum else 0
    
    # 10. 可选：保存哈希值
    if output_hash_path:
        with open(output_hash_path, 'w') as f:
            json.dump(hash_array.tolist(), f, indent=2)
    
    return hash_array

def hex_hash(hash_array):
    """将二进制哈希转换为十六进制字符串表示"""
    hash_str = ""
    for i in range(8):
        byte_val = 0
        for j in range(8):
            byte_val = (byte_val << 1) | hash_array[i][j]
        hash_str += f"{byte_val:02x}"
    return hash_str

def main():
    if len(sys.argv) < 2:
        print("用法: python phash_simulator.py <输入图片路径> [输出哈希JSON路径]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    output_hash_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        hash_array = phash_circom(image_path, output_hash_path)
        hash_hex = hex_hash(hash_array)
        
        print(f"图像: {os.path.basename(image_path)}")
        print(f"pHash值: {hash_hex}")
        if output_hash_path:
            print(f"哈希数据已保存到: {output_hash_path}")
        
        # 显示二进制哈希矩阵
        print("\n二进制哈希矩阵:")
        for row in hash_array:
            print(''.join(str(int(bit)) for bit in row))
            
    except Exception as e:
        print(f"处理过程中出错: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()