// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 验证器接口，用于验证零知识证明
interface IVerifier {
    function verifyProof(
        uint[2] calldata _pA,      // 椭圆曲线上的点 A
        uint[2][2] calldata _pB,   // 椭圆曲线上的点 B（包含两个二维坐标）
        uint[2] calldata _pC,      // 椭圆曲线上的点 C
        uint[4] calldata _pubSignals  // 公共输入信号
    ) external view returns (bool);
}

// 证明验证合约
contract Attest{
    address public verifierAddress;
    uint256 public threshold;
    address public owner;
    uint256 public latestC_S;     // 新增 latestC_S 变量
    
    struct AuthData {
        uint[2] pA;             // 证明的椭圆曲线点 A
        uint[2][2] pB;          // 证明的椭圆曲线点 B
        uint[2] pC;             // 证明的椭圆曲线点 C
        uint[4] pubSignals;     // 公共输入信号
        address owner;          // 认证所有者
        uint256 timestamp;      // 认证时间戳
        uint256 nft_id;         // 新增 NFT ID
    }
    mapping(uint256 => AuthData) public authData;
    uint256 private nftId = 1;
    event VerificationResult(bool success, uint256 result);
    event AuthenticationSuccessful(uint256 authId, address owner, uint256 timestamp);
    event VerifierUpdated(address oldVerifier, address newVerifier);
    event LatestCSUpdated(uint256 oldValue, uint256 newValue);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
    
    constructor(address _verifierAddress, uint256 _threshold) {
        require(_verifierAddress != address(0), "Invalid verifier address");
        verifierAddress = _verifierAddress;
        owner = msg.sender;
        threshold = _threshold;
        latestC_S = 0;  
    }
    
    // 更新验证器地址，仅部署者可调用
    function updateVerifier(address _newVerifierAddress) external onlyOwner {
        require(_newVerifierAddress != address(0), "Invalid verifier address");
        address oldVerifier = verifierAddress;
        verifierAddress = _newVerifierAddress;
        emit VerifierUpdated(oldVerifier, _newVerifierAddress);
    }
    
    // 更新 latestC_S 值，仅部署者可调用
    function updateLatestCS(uint256 _newLatestCS) external onlyOwner {
        uint256 oldValue = latestC_S;
        latestC_S = _newLatestCS;
        emit LatestCSUpdated(oldValue, _newLatestCS);
    }
    
    // 存储认证数据并生成唯一ID
    function storeAuthData(
        uint[2] calldata _pA, 
        uint[2][2] calldata _pB, 
        uint[2] calldata _pC, 
        uint[4] calldata _pubSignals
    ) internal returns (uint256) {
        // 生成唯一的NFT认证ID
        uint256 nft_auth_id = nftId;
        nftId++;
        
        // 存储认证数据
        authData[nft_auth_id] = AuthData({
            pA: _pA,
            pB: _pB,
            pC: _pC,
            pubSignals: _pubSignals,
            owner: msg.sender,
            timestamp: block.timestamp,
            nft_id: nft_auth_id    // 存储 NFT ID
        });
        
        // 触发认证成功事件
        emit AuthenticationSuccessful(nft_auth_id, msg.sender, block.timestamp);
        
        return nft_auth_id;
    }
    
    // 验证证明
    function verify(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[4] calldata _pubSignals  
    ) external returns (uint256) {
        require(verifierAddress != address(0), "Verifier not set");
        
        if(_pubSignals[0] != 1){ revert(); }
        if(_pubSignals[1] < threshold){ revert();}
        if(_pubSignals[3] != latestC_S){ revert("Invalid C_S value");}
        
        // 调用验证器合约进行验证
        IVerifier verifier = IVerifier(verifierAddress);
        bool success = verifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        
        uint256 result;

        // 如果验证成功且公共输入信号第一个为1，生成唯一标识符
        if (success) {
            result = storeAuthData(_pA, _pB, _pC, _pubSignals);
        } else {
            result = 0; // 验证失败，返回0
        }
        
        // 触发验证结果事件
        emit VerificationResult(success, result);
        
        return result;
    }
    
    // 获取验证器地址
    function getVerifier() external view returns (address) {
        return verifierAddress;
    }
    
    // 根据认证ID获取认证信息
    function getAuthData(uint256 authId) external view returns (
        uint[2] memory pA,
        uint[2][2] memory pB,
        uint[2] memory pC,
        uint[4] memory pubSignals,
        address authOwner,
        uint256 timestamp,
        uint256 nft_id
    ) {
        AuthData storage data = authData[authId];
        require(data.owner != address(0), "Auth data does not exist");
        
        return (
            data.pA,
            data.pB,
            data.pC,
            data.pubSignals,
            data.owner,
            data.timestamp,
            data.nft_id
        );
    }
}