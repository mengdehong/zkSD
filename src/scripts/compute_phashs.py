import os
import sys
import json
import numpy as np
from PIL import Image
from phash import phash_circom, hex_hash

def create_witness_input(images_dir, output_json_path, max_images=500):
    """为一组图像创建JSON见证输入，使用与Circom电路匹配的phash算法
    
    递归遍历文件夹，处理所有子文件夹中的图像
    """
    # 支持的图像扩展名
    image_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp']
    
    # 递归扫描目录及其子目录中的所有图像
    image_files = []
    
    def scan_directory(directory):
        for entry in os.scandir(directory):
            if entry.is_file() and any(entry.name.lower().endswith(ext) for ext in image_extensions):
                image_files.append(entry.path)
            elif entry.is_dir():
                scan_directory(entry.path)
    
    # 开始扫描
    scan_directory(images_dir)
    
    # 确保有图像文件
    if not image_files:
        print(f"在 {images_dir} 及其子目录中没有找到图像文件")
        return False
    
    # 限制处理的图像数量
    if len(image_files) > max_images:
        print(f"警告：找到了 {len(image_files)} 张图片，但只处理前 {max_images} 张")
        image_files = image_files[:max_images]
    else:
        print(f"找到了 {len(image_files)} 张图片，将全部处理")
    
    # 计算每个图像的pHash
    db_phashs = []
    for i, img_path in enumerate(image_files):
        try:
            # 使用与Circom电路匹配的phash_circom实现
            hash_array = phash_circom(img_path)
            hash_hex = hex_hash(hash_array)
            
            # 将hash_array转换为嵌套数组格式
            db_phashs.append(hash_array.tolist())
        except Exception as e:
            print(f"处理图像 {img_path} 时出错: {str(e)}")
    
    # 创建符合电路输入要求的JSON结构
    circuit_input = {
        "dbPhashs": db_phashs
    }
    
    # 如果数据库大小小于预期的N(500)，用零填充
    while len(circuit_input["dbPhashs"]) < max_images:
        empty_phash = [[0 for _ in range(8)] for _ in range(8)]
        circuit_input["dbPhashs"].append(empty_phash)
    
    # 将结果写入JSON文件
    with open(output_json_path, 'w') as f:
        json.dump(circuit_input, f, indent=2)
    
    print(f"\n成功创建输入文件: {output_json_path}")
    print(f"处理了 {len(image_files)} 个图像，总条目: {len(circuit_input['dbPhashs'])}")
    return True

if __name__ == "__main__":

    images_dir = "/home/wenmou/code/zkp/Database/512"
    output_json = "/home/wenmou/code/zkp/workdir/dbphashs_512.json"
    max_images = 512

    
    if not os.path.isdir(images_dir):
        print(f"错误: 目录 '{images_dir}' 不存在")
        sys.exit(1)
    
    if not create_witness_input(images_dir, output_json, max_images):
        sys.exit(1)