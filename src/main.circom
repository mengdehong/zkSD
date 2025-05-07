pragma circom 2.1.5;
// 引入需要的电路库
include "../circomlib/comparators.circom";  
include "../circomlib/switcher.circom";     
include "../circomlib/poseidon.circom";                      
include "phash.circom";

// Compute the next power of 2 greater than or equal to n
function nextPowerOf2(n) {
    var m = n - 1;
    m = m | (m >> 1);
    m = m | (m >> 2);
    m = m | (m >> 4);
    m = m | (m >> 8);
    m = m | (m >> 16);
    return m + 1;
}

// 添加 LessThanOrEqual 组件实现
template LessThanOrEqual(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;
    
    component gt = GreaterThan(n);
    gt.in[0] <== in[0];
    gt.in[1] <== in[1];
    
    out <== 1 - gt.out;
}

// Template to pack an 8x8 binary array into a single field element
template PackPhash() {
    signal input phash[8][8];
    signal output packed;
    signal accum[65];
    accum[0] <== 0;
    var idx = 0;
    for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
            accum[idx + 1] <== accum[idx] + phash[i][j] * (1 << idx);
            idx++;
        }
    }
    packed <== accum[64];
}

// Merkle树模板，用于构建具有N个叶子节点的Merkle树
template MerkleTree(N) {
    signal input leaves[N];      // 输入叶子节点数组
    signal output root;          // 输出Merkle树根
    
    // 计算下一个2的幂作为叶子节点数量
    var numLeaves = nextPowerOf2(N);
    var depth = 0;
    var temp = numLeaves;
    // 计算Merkle树深度
    while (temp > 1) {
        temp = temp >> 1;
        depth++;
    }
    
    // 计算树中的总节点数
    var totalNodes = numLeaves * 2 - 1;
    // 存储树中所有节点的二维数组
    signal nodes[depth + 1][numLeaves];
    
    // 初始化叶子节点层
    for (var i = 0; i < numLeaves; i++) {
        if (i < N) {
            nodes[0][i] <== leaves[i];  // 使用提供的叶子节点
        } else {
            nodes[0][i] <== 0;          // 不足的位置用0填充
        }
    }
    
    // 构建Merkle树的哈希组件
    component hash[totalNodes - numLeaves];
    var nodeIdx = 0;
    // 逐层构建树
    for (var level = 0; level < depth; level++) {
        var nodesInLevel = numLeaves >> level;
        var nodesInNextLevel = nodesInLevel >> 1;
        // 每两个节点组合生成上一层的一个节点
        for (var i = 0; i < nodesInNextLevel; i++) {
            hash[nodeIdx] = Poseidon(2);  // 使用Poseidon哈希函数
            hash[nodeIdx].inputs[0] <== nodes[level][2 * i];
            hash[nodeIdx].inputs[1] <== nodes[level][2 * i + 1];
            nodes[level + 1][i] <== hash[nodeIdx].out;
            nodeIdx++;
        }
    }
    
    // 输出Merkle树的根
    root <== nodes[depth][0];
}

// 验证数据库完整性的模板
template VerifyDatabaseIntegrity(N) {
    signal input dbPhashs[N][8][8];  // 数据库中的所有pHash
    signal input dbHash;             // 数据库的Merkle根哈希
    // signal output rootHash;          // 添加输出信号，输出Merkle树根

    // 将每个pHash打包成一个整数
    component dbPhashPacker[N];
    signal dbPhashPacked[N];
    for (var k = 0; k < N; k++) {
        dbPhashPacker[k] = PackPhash();
        for (var i = 0; i < 8; i++) {
            for (var j = 0; j < 8; j++) {
                dbPhashPacker[k].phash[i][j] <== dbPhashs[k][i][j];
            }
        }
        dbPhashPacked[k] <== dbPhashPacker[k].packed;
    }

    // 构建数据库的Merkle树
    component merkleTree = MerkleTree(N);
    for (var i = 0; i < N; i++) {
        merkleTree.leaves[i] <== dbPhashPacked[i];
    }

    // 验证Merkle根是否匹配
     merkleTree.root === dbHash;
}

// 检查用户的pHash是否与数据库中的任何pHash相似
template CheckSimilarity(N) {
    signal input userPhash[8][8];      // 用户图像的pHash
    signal input dbPhashs[N][8][8];    // 数据库中的所有pHash
    signal input threshold;            // 相似度阈值
    signal output isSimilar;           // 输出是否有相似图像
    
    // 计算用户pHash与数据库中每个pHash的汉明距离
    component hammingDistances[N];
    signal distances[N];
    
    component lte[N];  // 小于等于比较器
    for (var i = 0; i < N; i++) {
        lte[i] = LessThanOrEqual(32);
    }
    
    for (var i = 0; i < N; i++) {
        hammingDistances[i] = HammingDistance(8);
        
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                hammingDistances[i].hashA[r][c] <== userPhash[r][c];
                hammingDistances[i].hashB[r][c] <== dbPhashs[i][r][c];
            }
        }
        
        distances[i] <== hammingDistances[i].distance;
    }
    
    // 检查是否有任何距离小于等于阈值
    signal belowThreshold[N];
    var anyBelowThreshold = 0;
    
    for (var i = 0; i < N; i++) {
        lte[i].in[0] <== distances[i];
        lte[i].in[1] <== threshold;
        
        belowThreshold[i] <== lte[i].out;
        anyBelowThreshold = anyBelowThreshold + belowThreshold[i];
    }
    
    // 如果有任何一个相似，则输出相似
    component isAnyMatched = IsZero();
    isAnyMatched.in <== anyBelowThreshold;
    isSimilar <== 1 - isAnyMatched.out;
}

// 计算图像承诺的模板
template ImageCommitment() {
    signal input image[32][32];  // 输入图像数据
    signal input r2;             // 随机数
    signal output out;           // 输出承诺值
    
    // 将图像分成64个4x4块，计算每个块的哈希
    component blockHash[64];
    for (var b = 0; b < 64; b++) {
        blockHash[b] = Poseidon(16);
        var x = (b \ 8) * 4;  // 整除计算块的起始行
        var y = (b % 8) * 4;  // 求余计算块的起始列
        for (var i = 0; i < 4; i++) {
            for (var j = 0; j < 4; j++) {
                blockHash[b].inputs[i * 4 + j] <== image[x + i][y + j];
            }
        }
    }
    
    // 将64个块哈希组合成4个组哈希
    component groupHash[4];
    for (var g = 0; g < 4; g++) {
        groupHash[g] = Poseidon(16);
        for (var i = 0; i < 16; i++) {
            groupHash[g].inputs[i] <== blockHash[g * 16 + i].out;
        }
    }
    
    // 最终合并4个组哈希和随机数，计算图像承诺
    component imgCommitmentCalc = Poseidon(5);
    for (var i = 0; i < 4; i++) {
        imgCommitmentCalc.inputs[i] <== groupHash[i].out;
    }
    imgCommitmentCalc.inputs[4] <== r2;
    
    // 输出最终的承诺值
    out <== imgCommitmentCalc.out;
}

// 主电路模板 
template PHashChecker(N) {
    signal input threshold;            // 相似度阈值
    signal input dbPhashs[N][8][8];    // 数据库中的所有pHash
    signal input imgCommitment;        // 输入图像承诺
    signal input dbHash;               // 输入数据库哈希

    signal input image[32][32];        // 输入图像承诺
    signal input r2;                   // 随机数

    signal output isUnique;              // 输出图像是否唯一

    // 1计算图像的哈希承诺
    component imgCommitmentComponent = ImageCommitment();
    for (var i = 0; i < 32; i++) {
        for (var j = 0; j < 32; j++) {
            imgCommitmentComponent.image[i][j] <== image[i][j];
        }
    }
    imgCommitmentComponent.r2 <== r2;
    
    imgCommitmentComponent.out === imgCommitment;
    

    // 2从输入图像计算pHash
    component phashCalculator = PHash(32, 8, 1 << 64);  // 使用导入的PHash组件
    for (var i = 0; i < 32; i++) {
        for (var j = 0; j < 32; j++) {
            phashCalculator.image[i][j] <== image[i][j];
        }
    }

    // 3验证数据库完整性
    component dbVerifier = VerifyDatabaseIntegrity(N);
    // 将输入的 dbPhashs 传递给验证器组件
    for (var i = 0; i < N; i++) {
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                dbVerifier.dbPhashs[i][r][c] <== dbPhashs[i][r][c];
            }
        }
    }
    dbVerifier.dbHash <== dbHash;
    
    // 4检查用户图像phash是否与数据库中的任何图像相似
    component similarityChecker = CheckSimilarity(N);
    for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
            similarityChecker.userPhash[r][c] <== phashCalculator.hash[r][c];
        }
    }
    
    for (var i = 0; i < N; i++) {
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                similarityChecker.dbPhashs[i][r][c] <== dbPhashs[i][r][c];
            }
        }
    }

    similarityChecker.threshold <== threshold;

    // 1表示和数据库不相似，0表示抄袭
    isUnique <== 1 - similarityChecker.isSimilar;
}
// component main{public[threshold,imgCommitment,dbHash,dbPhashs]} = PHashChecker(128);

// 将dbPhashs作为私有输入来优化
component main{public[threshold,imgCommitment,dbHash]} = PHashChecker(128);

// component main{public[threshold,imgCommitment,dbHash]} = PHashChecker(256);
// component main{public[threshold,imgCommitment,dbHash]} = PHashChecker(512);

// component main{public[threshold,imgCommitment,dbHash]} = PHashChecker(1024);
