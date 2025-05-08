import os
import sys
import json
import numpy as np
from PIL import Image
from phash import phash_circom, hex_hash
import argparse # Added import

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
    actual_found_images = len(image_files)
    if actual_found_images > max_images:
        print(f"警告：找到了 {actual_found_images} 张图片，但只处理前 {max_images} 张")
        image_files = image_files[:max_images]
    else:
        print(f"找到了 {actual_found_images} 张图片，将全部处理")
    
    # 计算每个图像的pHash
    db_phashs = []
    processed_image_count = 0
    for i, img_path in enumerate(image_files):
        try:
            # 使用与Circom电路匹配的phash_circom实现
            hash_array = phash_circom(img_path)
            # hash_hex = hex_hash(hash_array) # hash_hex is not used, can be removed if not needed elsewhere
            
            # 将hash_array转换为嵌套数组格式
            db_phashs.append(hash_array.tolist())
            processed_image_count += 1
        except Exception as e:
            print(f"处理图像 {img_path} 时出错: {str(e)}")
    
    # 创建符合电路输入要求的JSON结构
    circuit_input = {
        "dbPhashs": db_phashs
    }
    
    # 如果数据库大小小于预期的N(max_images)，用零填充
    # This padding should be up to max_images, which is the expected circuit input size
    while len(circuit_input["dbPhashs"]) < max_images:
        empty_phash = [[0 for _ in range(8)] for _ in range(8)]
        circuit_input["dbPhashs"].append(empty_phash)
    
    # 将结果写入JSON文件
    os.makedirs(os.path.dirname(output_json_path), exist_ok=True) # Ensure output directory exists
    with open(output_json_path, 'w') as f:
        json.dump(circuit_input, f, indent=2)
    
    print(f"\n成功创建输入文件: {output_json_path}")
    print(f"处理了 {processed_image_count} 个图像 (来自找到的 {actual_found_images} 个)，总条目 (填充后): {len(circuit_input['dbPhashs'])}")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="为一组图像创建JSON见证输入。")
    parser.add_argument("images_dir", type=str, help="包含图像的目录路径。")
    parser.add_argument("--max_images", type=int, default=128, help="要处理的最大图像数量 (默认为 128)。电路输入将填充到此大小。")
    
    args = parser.parse_args()

    if not os.path.isdir(args.images_dir):
        print(f"错误: 目录 '{args.images_dir}' 不存在或不是一个有效的目录。")
        sys.exit(1)

    # 确定项目根目录 (假设此脚本位于 /home/wenmou/code/zkSD/src/scripts/)
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    # 构建输出目录路径
    output_base_dir = os.path.join(project_root, "workdir")
    
    # 从输入目录路径获取基本名称
    input_dir_name = os.path.basename(os.path.normpath(args.images_dir))
    
    # 构建输出JSON文件名
    output_json_filename = f"dbphashs_{input_dir_name}.json"
    output_json_path = os.path.join(output_base_dir, output_json_filename)

    print(f"输入图像目录: {args.images_dir}")
    print(f"最大处理图像数: {args.max_images}")
    print(f"输出JSON文件路径: {output_json_path}")

    if not create_witness_input(args.images_dir, output_json_path, args.max_images):
        sys.exit(1)
    
    print("脚本执行完毕。")
