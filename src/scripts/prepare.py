# NFT发布者运行,根据他的图片生成电路所需要的输入数据,用json存储
# 然后NFT发布者使用snarkjs将图片对于的json文件输入到phash电路,计算图片的phash值
from PIL import Image
from phash import generate_dct_coefficients
import numpy as np
import json
import sys
import os

def process_image(image_path):
    # 打开并转换为灰度图
    img = Image.open(image_path).convert('L')
    
    # 调整图像大小为32x32，使用LANCZOS重采样以获得更好的质量
    img_resized = img.resize((32, 32), Image.Resampling.LANCZOS)
    
    # 转换为numpy数组，范围0-255
    img_array = np.array(img_resized)
    
    return img_array.tolist()

def format_integer(number):
    """确保数字以整数格式表示，没有科学计数法"""
    return int(number)  # 强制转换为int再转为str，避免科学计数法

def main():
    # 检查命令行参数
    if len(sys.argv) != 2:
        print("使用方法: python prepare.py <图片路径>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    # 检查文件是否存在
    if not os.path.exists(image_path):
        print(f"错误: 文件 {image_path} 不存在")
        sys.exit(1)
    
    # 处理图像
    try:
        print(f"正在处理图像: {image_path}")
        img_array = process_image(image_path)
        
        # 使用phash.py中的函数生成DCT系数，保持相同的缩放因子
        size = 32
        scale = 2**64  # 与phash.py中的scale保持一致
        dct_coefficients = generate_dct_coefficients(size, scale)
        
        # 将DCT系数转换为整数表示的字符串（没有科学计数法）
        dct_coefficients_str = []
        for row in dct_coefficients:
            dct_coefficients_str.append([format_integer(val) for val in row])
        
        # 创建输出数据
        output_data = {
            "image": img_array,
            "dct_coefficients": dct_coefficients_str
        }
        
        # 定义输出目录和文件名
        output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "workdir")
        # 创建输出目录（如果不存在）
        os.makedirs(output_dir, exist_ok=True)
        
        base_name = os.path.splitext(os.path.basename(image_path))[0]
        output_filename = os.path.join(output_dir, f"{base_name}.json")
        
        with open(output_filename, "w") as f:
            json.dump(output_data, f, indent=2)
        
        print(f"数据已保存到: {output_filename}")
        
        # 打印一些统计信息
        print(f"图像大小: 32x32")
        print(f"DCT矩阵大小: 32x32")
        print(f"缩放因子: 2^64")
        
    except Exception as e:
        print(f"处理图像时出错: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()