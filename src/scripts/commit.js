const ethers = require("ethers");
const fs = require("fs");
const path = require("path");
const poseidonModule = require("./poseidon.cjs");

const poseidonHash = poseidonModule.poseidon;

function packPhash(phash) {
    let packed = 0n;
    let idx = 0;
    for (let i = 0; i < 8; i++) {
        for (let j = 0; j < 8; j++) {
            if (idx < 64) {
                packed += (1n << BigInt(idx)) * BigInt(phash[i][j]);
                idx++;
            }
        }
    }
    return packed;
}

// 下一个大于等于n的2的幂
function nextPowerOf2(n) {
    let m = n - 1;
    m |= m >> 1;
    m |= m >> 2;
    m |= m >> 4;
    m |= m >> 8;
    m |= m >> 16;
    return m + 1;
}

// 构建Merkle树并返回根哈希
function buildMerkleTree(leaves) {
    const numLeaves = nextPowerOf2(leaves.length);

    // 计算树的深度
    let depth = 0;
    let temp = numLeaves;
    while (temp > 1) {
        temp = temp >> 1;
        depth++;
    }

    // 创建节点数组, 结构与Circom相同
    let nodes = Array(depth + 1).fill().map(() => Array(numLeaves).fill(0n));

    // 初始化叶子节点层
    for (let i = 0; i < numLeaves; i++) {
        if (i < leaves.length) {
            nodes[0][i] = leaves[i];
        } else {
            nodes[0][i] = 0n; // 用0填充
        }
    }
    let nodeIdx = 0;

    // 逐层构建树 - 完全匹配Circom实现
    for (let level = 0; level < depth; level++) {
        const nodesInLevel = numLeaves >> level;
        const nodesInNextLevel = nodesInLevel >> 1;

        for (let i = 0; i < nodesInNextLevel; i++) {
            const left = nodes[level][2 * i].toString();
            const right = nodes[level][2 * i + 1].toString();

            // 使用poseidon哈希
            const hashResult = poseidonHash([left, right]);
            nodes[level + 1][i] = BigInt(hashResult);
            nodeIdx++;
        }
    }

    console.log("计算得到的根哈希:", nodes[depth][0].toString());
    return nodes[depth][0];
}

// 验证数据库完整性
function commitDbPhashs(dbPhashs) {
    const dbPhashPacked = dbPhashs.map(phash => packPhash(phash));
    const rootHash = buildMerkleTree(dbPhashPacked);
    return rootHash;
}

// 提交图像承诺，与 Circom 中的图像承诺计算对应
function commitImage(image, r2) {
    // console.log("Committing image");

    let blockHashes = [];
    for (let b = 0; b < 64; b++) {
        const x = Math.floor(b / 8) * 4;
        const y = (b % 8) * 4;
        let block = [];
        for (let i = 0; i < 4; i++) {
            for (let j = 0; j < 4; j++) {
                block.push(BigInt(image[x + i][y + j]).toString());
            }
        }
        const blockHash = poseidonHash(block); 
        blockHashes.push(BigInt(blockHash));
    }

    let groupHashes = [];
    for (let g = 0; g < 4; g++) {
        const group = blockHashes.slice(g * 16, (g + 1) * 16).map(h => h.toString());
        const groupHash = poseidonHash(group);
        groupHashes.push(BigInt(groupHash));
    }

    const inputs = [...groupHashes.map(h => h.toString()), BigInt(r2).toString()];
    const imgCommitment = poseidonHash(inputs);
    return BigInt(imgCommitment);
}

function generateSampleData(dbPhashSize, imageName) {
    try {
        const dbPhashsPath = path.resolve(__dirname, `../../workdir/dbphashs_${dbPhashSize}.json`);
        const dbPhashsData = fs.readFileSync(dbPhashsPath, 'utf8');
        const parsedDbFileContent = JSON.parse(dbPhashsData);

        // 从解析的对象中提取 "dbPhashs" 键对应的数组
        const actualDbPhashsArray = parsedDbFileContent.dbPhashs;

        // 可选：添加一个检查以确保 actualDbPhashsArray 真的是一个数组
        if (!Array.isArray(actualDbPhashsArray)) {
            console.error(`错误: 文件 ${dbPhashsPath} 中的 'dbPhashs' 字段不是一个数组。`);
            console.error(`找到的内容:`, actualDbPhashsArray);
            throw new TypeError(`期望 dbphashs_${dbPhashSize}.json 文件中的 'dbPhashs' 键包含一个数组。`);
        }

        const imagePath = path.resolve(__dirname, `../../workdir/${imageName}.json`);
        const imageData = fs.readFileSync(imagePath, 'utf8');
        const parsedImageFileContent = JSON.parse(imageData); // 解析整个图像文件内容

        let actualImageArray;
        // 检查解析后的内容是否是一个对象并且包含 "image" 键
        if (parsedImageFileContent && typeof parsedImageFileContent === 'object' && parsedImageFileContent.image !== undefined) {
            actualImageArray = parsedImageFileContent.image;
        } else if (Array.isArray(parsedImageFileContent)) {
            // 如果JSON文件的根直接就是数组，则使用它
            actualImageArray = parsedImageFileContent;
        } else {
            console.error(`错误: 文件 ${imagePath} 的内容不是预期的图像数据格式。`);
            console.error(`找到的内容:`, parsedImageFileContent);
            throw new TypeError(`期望 ${imageName}.json 文件包含一个图像数组，或者一个在其 "image" 键下包含图像数组的对象。`);
        }

        // 确保提取的图像数据确实是一个二维数组
        if (!Array.isArray(actualImageArray) || (actualImageArray.length > 0 && !Array.isArray(actualImageArray[0]))) {
            console.error(`错误: 从 ${imagePath} 提取的图像数据不是一个有效的二维数组。`);
            console.error(`提取的数据结构:`, actualImageArray);
            throw new TypeError(`从 ${imageName}.json 提取的图像数据必须是一个二维数组。`);
        }

        // 返回提取出的数组
        return { dbPhashs: actualDbPhashsArray, image: actualImageArray };
    } catch (error) {
        console.error("Error in generateSampleData:", error);
        if (error.code === 'ENOENT') {
            console.error(`File not found. Please ensure dbphashs_${dbPhashSize}.json and ${imageName}.json exist in the workdir directory.`);
        }
        throw error;
    }
}
async function main() {
    try {
        // 从命令行参数获取 dbPhash_size 和 imageName
        // 示例: node src/scripts/commit.js 128 your_image_name
        const dbPhashSize = process.argv[2];
        const imageName = process.argv[3];

        if (!dbPhashSize || !imageName) {
            console.error("请提供 dbPhash_size 和 imageName作为命令行参数。");
            console.log("用法: node src/scripts/commit.js <dbPhash_size> <imageName>");
            process.exit(1); // 参数不足，退出脚本
        }

        console.log(`使用的 dbPhash_size: ${dbPhashSize}`);
        console.log(`使用的 imageName: ${imageName}`);

        const { dbPhashs, image } = generateSampleData(dbPhashSize, imageName);

        // 计算数据库 Merkle 根哈希
        const dbHash = commitDbPhashs(dbPhashs);
        console.log("dbHash type:", typeof dbHash, "value:", dbHash);
        console.log("dbHash (Merkle Root):", dbHash.toString());

        // 计算图像承诺,实际应该选择随机数
        const r2 = 123456789;
        const imgCommitment = commitImage(image, r2);
        console.log("Image commitment:", imgCommitment.toString());

        const threshold = 10; // 设置相似性阈值

        // 准备要保存的数据
        const commitData = {
            imgCommitment: imgCommitment.toString(),
            dbHash: dbHash.toString(),
            threshold,
            r2,
            image,
            dbPhashs: dbPhashs
        };

        // 保存到commit.json文件
        const commitJsonPath = path.resolve(__dirname, `../../workdir/${dbPhashSize}_circom_input.json`);
        fs.writeFileSync(commitJsonPath, JSON.stringify(commitData, null, 2));
        console.log(`Results saved to: ${commitJsonPath}`);

    } catch (error) {
        console.error("Error in main:", error);
    }

}

(async () => {
    try {
        await main();
        console.log("Script completed successfully");
    } catch (error) {
        console.error("Script failed:", error);
    }
})();